// Payment Gateway จำลอง (สมมติว่าเป็นระบบภายนอก เช่น ธนาคาร / Omise)
// ไม่ได้ย้ายเงินจริง ทั้งขาออก (โอนให้ผู้ขาย / คืนเงิน) และขาเข้า (รับเงินผู้ซื้อด้วย PromptPay QR)
//
// ---------- ขาออก: สั่งโอน ----------
// POST /mock-gateway/v1/transfers
//   Header: Authorization: Bearer <MOCK_GATEWAY_SECRET>
//           Idempotency-Key: <คีย์ไม่ซ้ำต่อคำสั่งโอน>
//   Body:   { amount, currency, destination, reference, webhook_url, metadata }
//   ตอบทันที: { id, status: "processing" } แล้วอีก ~3 วินาทีส่ง webhook:
//   POST <webhook_url>  Header: X-Mock-Signature: hmac_sha256(body, MOCK_WEBHOOK_SECRET)
//   Body: { id, status: "succeeded" | "failed", failure_reason, amount, metadata }
//
// กติกาจำลองผล (ไว้ทดสอบกรณีโอนไม่สำเร็จ):
//   เลขบัญชีปลายทางลงท้าย 0000  → failed "ไม่พบบัญชีปลายทาง"
//   ยอดเกิน 50,000 บาท           → failed "เกินวงเงินโอนต่อครั้ง"
//   นอกนั้น                      → succeeded
//
// ---------- ขาเข้า: รับเงินด้วย PromptPay QR (charge) ----------
// POST /mock-gateway/v1/charges              ร้านค้า (Edge Function charges) สร้างรายการรับเงิน
//   Header: Authorization: Bearer <MOCK_GATEWAY_SECRET>, Idempotency-Key
//   Body:   { amount, currency, reference, description, expires_at, webhook_url, metadata }
//   ตอบ:    { id, status: "pending", qr, ... }   qr = ข้อความที่เอาไปทำเป็นรูป QR
//   คีย์เดิม = charge เดิม (กดสร้างซ้ำไม่ได้ QR ใหม่)
//
// GET  /mock-gateway/pay/<id>                เปิดลิงก์จาก QR ด้วยกล้องมือถือ
//   ตอบเป็นข้อความธรรมดา (Supabase ไม่ให้ Edge Function ตอบหน้าเว็บ HTML บนโดเมน supabase.co)
//   เห็นเลขที่คำสั่งซื้อ + ยอด + สถานะ แต่จ่ายจากลิงก์นี้ไม่ได้
//
// POST /mock-gateway/bank/lookup  { qr }     แอปธนาคารจำลอง (ในแอป Courtswap) อ่าน QR
// POST /mock-gateway/bank/pay     { charge_id }   กดยืนยันโอน
//   จ่ายสำเร็จ → อีก ~2 วินาทีส่ง webhook ไปที่ webhook_url ของ charge:
//   Body: { id, object: "charge", status: "succeeded", amount, reference, metadata }
//   (ไม่ต้องใช้รหัสลับ: เลข charge สุ่มยาว เดาไม่ได้ ใครถือ QR ก็จ่ายได้ เหมือน QR จริง)
//
// Deploy: supabase functions deploy mock-gateway --no-verify-jwt
// Secrets: MOCK_GATEWAY_SECRET, MOCK_WEBHOOK_SECRET
// ข้อมูล charge เก็บในตาราง mock_gateway_charges (schema.sql หัวข้อ 28) แทนฐานข้อมูลของ gateway

import { createClient } from "jsr:@supabase/supabase-js@2";
import { hmacHex } from "../_shared/hmac.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

const SETTLE_DELAY_MS = 3000;
const CHARGE_WEBHOOK_DELAY_MS = 2000;
const TRANSFER_LIMIT = 50000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

// ลิงก์ที่ฝังใน QR
function payUrl(chargeId: string): string {
  return `${supabaseUrl}/functions/v1/mock-gateway/pay/${chargeId}`;
}

// คีย์เดิม = เลขรายการเดิม (ส่งคำสั่งซ้ำไม่เกิดการโอนซ้ำ)
async function transferIdFor(key: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(key),
  );
  const hex = [...new Uint8Array(digest)]
    .slice(0, 6)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
  const date = new Date().toISOString().slice(0, 10).replaceAll("-", "");
  return `MOCK-TRF-${date}-${hex}`;
}

function decide(amount: number, destination: Record<string, unknown>) {
  const account = String(destination?.account_number ?? "").replace(/\D/g, "");
  if (account.endsWith("0000")) {
    return { status: "failed", failure_reason: "ไม่พบบัญชีปลายทาง" };
  }
  if (amount > TRANSFER_LIMIT) {
    return { status: "failed", failure_reason: "เกินวงเงินโอนต่อครั้ง" };
  }
  return { status: "succeeded", failure_reason: null };
}

// ส่งผลให้ร้านค้าทาง webhook พร้อมลายเซ็น (ทำเบื้องหลังหลังตอบไปแล้ว)
function sendWebhookLater(
  webhookUrl: string,
  webhookSecret: string,
  delayMs: number,
  event: Record<string, unknown>,
) {
  EdgeRuntime.waitUntil((async () => {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    const payload = JSON.stringify(event);
    try {
      const res = await fetch(webhookUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Mock-Signature": await hmacHex(webhookSecret, payload),
        },
        body: payload,
      });
      console.log("webhook sent", event.id, event.status, res.status);
    } catch (e) {
      console.error("webhook failed", event.id, e);
    }
  })());
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const secret = Deno.env.get("MOCK_GATEWAY_SECRET");
  const webhookSecret = Deno.env.get("MOCK_WEBHOOK_SECRET");
  if (!secret || !webhookSecret) {
    return json({ error: "not_configured" }, 500);
  }

  const path = new URL(req.url).pathname;

  // ลิงก์จาก QR (เปิดด้วยกล้องมือถือ)
  const payMatch = path.match(/\/pay\/([A-Za-z0-9_]+)$/);
  if (req.method === "GET" && payMatch) {
    return payLinkText(payMatch[1]);
  }

  if (req.method !== "POST") {
    return json({ error: "not_found" }, 404);
  }

  // แอปธนาคารจำลอง
  if (path.endsWith("/bank/lookup")) return bankLookup(req);
  if (path.endsWith("/bank/pay")) return bankPay(req, webhookSecret);

  // ที่เหลือเป็น API ของร้านค้า ต้องมีรหัสลับ
  if (req.headers.get("Authorization") !== `Bearer ${secret}`) {
    return json({ error: "unauthorized" }, 401);
  }
  const idempotencyKey = req.headers.get("Idempotency-Key");
  if (!idempotencyKey) {
    return json({ error: "idempotency_key_required" }, 400);
  }

  if (path.endsWith("/v1/transfers")) {
    return createTransfer(req, idempotencyKey, webhookSecret);
  }
  if (path.endsWith("/v1/charges")) {
    return createCharge(req, idempotencyKey);
  }
  return json({ error: "not_found" }, 404);
});

// ---------- ขาออก: สั่งโอน ----------
async function createTransfer(
  req: Request,
  idempotencyKey: string,
  webhookSecret: string,
): Promise<Response> {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount < 0 || typeof body.webhook_url !== "string") {
    return json({ error: "bad_request" }, 400);
  }

  const id = await transferIdFor(idempotencyKey);
  const outcome = decide(amount, body.destination ?? {});

  sendWebhookLater(body.webhook_url, webhookSecret, SETTLE_DELAY_MS, {
    id,
    status: outcome.status,
    failure_reason: outcome.failure_reason,
    amount,
    reference: body.reference ?? null,
    metadata: body.metadata ?? {},
  });

  return json({
    id,
    status: "processing",
    amount,
    currency: body.currency ?? "THB",
    created_at: new Date().toISOString(),
  });
}

// ---------- ขาเข้า: สร้างรายการรับเงิน ----------
async function createCharge(req: Request, idempotencyKey: string): Promise<Response> {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const amount = Number(body.amount);
  if (!Number.isInteger(amount) || amount < 0 || typeof body.webhook_url !== "string") {
    return json({ error: "bad_request" }, 400);
  }

  // คีย์เดิม = charge เดิม
  const { data: existing } = await admin
    .from("mock_gateway_charges")
    .select()
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle();
  if (existing) return json(chargeResponse(existing));

  const id = `chrg_mock_${crypto.randomUUID().replaceAll("-", "")}`;
  const { data: charge, error } = await admin
    .from("mock_gateway_charges")
    .insert({
      id,
      idempotency_key: idempotencyKey,
      amount,
      currency: body.currency ?? "THB",
      reference: body.reference ?? null,
      description: body.description ?? null,
      expires_at: body.expires_at ?? null,
      webhook_url: body.webhook_url,
      metadata: body.metadata ?? {},
    })
    .select()
    .single();
  if (error || !charge) {
    // ชนกับคำขอที่ใช้คีย์เดียวกันพร้อมกัน → ใช้รายการนั้น
    const { data: raced } = await admin
      .from("mock_gateway_charges")
      .select()
      .eq("idempotency_key", idempotencyKey)
      .maybeSingle();
    if (raced) return json(chargeResponse(raced));
    console.error("insert charge", error);
    return json({ error: "charge_failed" }, 500);
  }
  return json(chargeResponse(charge));
}

function isExpired(charge: any): boolean {
  return charge.expires_at != null && new Date(charge.expires_at).getTime() <= Date.now();
}

// ข้อมูลที่ gateway ตอบ (ไม่รวม webhook_url / idempotency_key ที่เป็นข้อมูลภายใน)
function chargeResponse(charge: any) {
  return {
    id: charge.id,
    object: "charge",
    amount: charge.amount,
    currency: charge.currency,
    reference: charge.reference,
    description: charge.description,
    status: charge.status === "pending" && isExpired(charge) ? "expired" : charge.status,
    expires_at: charge.expires_at,
    paid_at: charge.paid_at,
    qr: payUrl(charge.id),
  };
}

async function findCharge(id: string) {
  const { data } = await admin
    .from("mock_gateway_charges")
    .select()
    .eq("id", id)
    .maybeSingle();
  return data;
}

// ---------- ลิงก์จาก QR: ข้อความสรุป ----------
async function payLinkText(chargeId: string): Promise<Response> {
  const charge = await findCharge(chargeId);
  let text: string;
  if (!charge) {
    text = "Mock Payment Gateway\n\nไม่พบรายการชำระเงินนี้";
  } else {
    const info = chargeResponse(charge);
    const statusText: Record<string, string> = {
      pending: "รอชำระ",
      succeeded: "ชำระแล้ว",
      expired: "หมดเวลาชำระ",
    };
    text = [
      "Mock Payment Gateway (จำลอง)",
      "",
      `ร้านค้า: ${info.description ?? "-"}`,
      `เลขที่คำสั่งซื้อ: ${info.reference ?? "-"}`,
      `ยอดชำระ: ฿${Number(info.amount).toFixed(2)}`,
      `สถานะ: ${statusText[info.status] ?? info.status}`,
      "",
      "ระบบจำลอง: กดจ่ายได้ที่ปุ่ม \"ชำระเงิน\" ในแอป Courtswap",
    ].join("\n");
  }
  return new Response(text, {
    headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
  });
}

// ---------- แอปธนาคารจำลอง ----------

// อ่าน QR: ดึงเลข charge จากลิงก์ แล้วคืนรายละเอียดให้ผู้จ่ายดูก่อนกดยืนยัน
async function bankLookup(req: Request): Promise<Response> {
  let qr = "";
  try {
    const body = await req.json();
    qr = String(body.qr ?? "");
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const match = qr.match(/\/pay\/([A-Za-z0-9_]+)$/);
  if (!match) return json({ error: "invalid_qr" }, 400);

  const charge = await findCharge(match[1]);
  if (!charge) return json({ error: "charge_not_found" }, 404);
  return json({ charge: chargeResponse(charge) });
}

// กดยืนยันโอน: เปลี่ยนเป็นจ่ายแล้ว (ครั้งเดียว) แล้วแจ้งร้านค้าทาง webhook
async function bankPay(req: Request, webhookSecret: string): Promise<Response> {
  let chargeId = "";
  try {
    const body = await req.json();
    chargeId = String(body.charge_id ?? "");
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const charge = await findCharge(chargeId);
  if (!charge) return json({ error: "charge_not_found" }, 404);
  if (charge.status === "succeeded") return json({ error: "charge_already_paid" }, 409);
  if (isExpired(charge)) return json({ error: "charge_expired" }, 409);

  // เปลี่ยนเฉพาะรายการที่ยังรอชำระ กันกดจ่ายซ้ำพร้อมกัน
  const { data: paid } = await admin
    .from("mock_gateway_charges")
    .update({ status: "succeeded", paid_at: new Date().toISOString() })
    .eq("id", chargeId)
    .eq("status", "pending")
    .select()
    .maybeSingle();
  if (!paid) return json({ error: "charge_already_paid" }, 409);

  sendWebhookLater(paid.webhook_url, webhookSecret, CHARGE_WEBHOOK_DELAY_MS, {
    id: paid.id,
    object: "charge",
    status: "succeeded",
    amount: paid.amount,
    reference: paid.reference,
    metadata: paid.metadata ?? {},
  });

  return json({ charge: chargeResponse(paid) });
}
