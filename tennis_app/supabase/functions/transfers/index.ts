// คืนเงินผู้ซื้อ / โอนเงินให้ผู้ขาย ผ่าน Payment Gateway (ตอนนี้ใช้ mock-gateway)
//
// POST /transfers            สร้างคำสั่งโอน
//   Body: { order_id, kind: "refund" | "payout" }
//   ใครเรียกได้: แอดมิน (แอปส่ง token) หรือ ฐานข้อมูล (trigger โอนผู้ขายอัตโนมัติ
//   ตอนคำสั่งซื้อเป็น confirmed ส่ง header X-Internal-Secret ดู schema.sql หัวข้อ 20)
//   ตอบ: { transfer: แถวใน payment_transfers }
//
// POST /transfers/webhook    gateway แจ้งผล (ตรวจลายเซ็น X-Mock-Signature)
//
// Deploy: supabase functions deploy transfers --no-verify-jwt
//   (webhook ไม่มี token ของ Supabase จึงปิดการเช็กอัตโนมัติ แล้วเช็กเองในโค้ดแทน)
// Secrets: MOCK_GATEWAY_URL (เช่น https://<project>.supabase.co/functions/v1/mock-gateway)
//          MOCK_GATEWAY_SECRET, MOCK_WEBHOOK_SECRET
//          INTERNAL_TRANSFER_SECRET (ต้องตรงกับ vault secret 'internal_transfer_secret')

import { createClient } from "jsr:@supabase/supabase-js@2";
import { hmacHex, safeEqual } from "../_shared/hmac.ts";

// ต้องตรงกับ kPlatformFee ในแอป และ notify_order_change ใน schema.sql
const PLATFORM_FEE = 50;

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
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(supabaseUrl, serviceKey);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "not_found" }, 404);
  }

  const url = new URL(req.url);
  if (url.pathname.endsWith("/webhook")) {
    return handleWebhook(req);
  }
  return createTransfer(req);
});

// ---------- สร้างคำสั่งโอน ----------
async function createTransfer(req: Request): Promise<Response> {
  const gatewayUrl = Deno.env.get("MOCK_GATEWAY_URL");
  const gatewaySecret = Deno.env.get("MOCK_GATEWAY_SECRET");
  if (!gatewayUrl || !gatewaySecret) {
    return json({ error: "not_configured" }, 500);
  }

  // 1. ใครเรียก: ฐานข้อมูล (trigger โอนอัตโนมัติ ส่งรหัสภายใน) หรือผู้ใช้ที่ล็อกอิน
  const internalSecret = Deno.env.get("INTERNAL_TRANSFER_SECRET");
  const sentSecret = req.headers.get("X-Internal-Secret") ?? "";
  const isSystem = !!internalSecret && safeEqual(sentSecret, internalSecret);

  let userId: string | null = null;
  if (!isSystem) {
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: userData } = await userClient.auth.getUser();
    if (!userData?.user) return json({ error: "not_logged_in" }, 401);
    userId = userData.user.id;
  }

  let orderId: number;
  let kind: "refund" | "payout";
  try {
    const body = await req.json();
    orderId = Number(body.order_id);
    kind = body.kind;
    if (!Number.isInteger(orderId) || (kind !== "refund" && kind !== "payout")) {
      throw new Error();
    }
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const { data: order } = await admin
    .from("orders")
    .select("*, listings(seller_id)")
    .eq("id", orderId)
    .single();
  if (!order) return json({ error: "order_not_found" }, 404);

  if (!isSystem) {
    const { data: adminRow } = await admin
      .from("admins")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();
    if (adminRow == null) {
      return json({ error: "not_allowed" }, 403);
    }
  }

  // 2. สถานะต้องพร้อม: คืนเงิน = rejected, โอนผู้ขาย = confirmed
  const requiredStatus = kind === "refund" ? "rejected" : "confirmed";
  if (order.status !== requiredStatus) {
    return json({ error: "order_not_ready" }, 409);
  }

  // กดซ้ำ = คืนรายการเดิมที่กำลังโอน/โอนสำเร็จแล้ว
  const existing = await activeTransfer(orderId, kind);
  if (existing) return json({ transfer: existing });

  // 3. ปลายทาง + ยอดเงิน (คำนวณที่นี่เท่านั้น)
  let destination: Record<string, unknown>;
  let amount: number;
  if (kind === "payout") {
    const { data: account } = await admin
      .from("payout_accounts")
      .select("bank_name, account_number, account_name")
      .eq("user_id", order.listings.seller_id)
      .maybeSingle();
    if (!account) return json({ error: "no_payout_account" }, 409);
    destination = {
      channel: "bank_account",
      bank_name: account.bank_name,
      account_number: account.account_number,
      account_name: account.account_name,
    };
    amount = Math.max(order.amount - PLATFORM_FEE, 0);
  } else if (order.charge_id && order.charge_status === "succeeded") {
    // จ่ายผ่าน gateway (schema.sql หัวข้อ 28): คืนเข้า charge เดิม gateway รู้เองว่าโอนมาจากบัญชีไหน
    destination = {
      channel: "original_charge",
      charge_id: order.charge_id,
      account_name: order.buyer_name,
    };
    amount = order.amount;
  } else {
    // คำสั่งซื้อเก่าก่อนมี gateway (จ่ายด้วยสลิป): คืนตามข้อมูลผู้โอนที่เคยอ่านจากสลิป
    const sender = order.slip_sender ?? {};
    destination = {
      channel: "original_source",
      bank_name: sender.bank ?? null,
      account_number: sender.account ?? null,
      account_name: sender.name ?? order.buyer_name,
    };
    amount = order.amount;
  }

  const { count } = await admin
    .from("payment_transfers")
    .select("id", { count: "exact", head: true })
    .eq("order_id", orderId)
    .eq("kind", kind);
  const attempt = (count ?? 0) + 1;

  // 4. บันทึกรายการ แล้วส่งให้ gateway
  const { data: transfer, error: insertError } = await admin
    .from("payment_transfers")
    .insert({
      order_id: orderId,
      kind,
      amount,
      destination,
      requested_by: userId, // null = ระบบโอนอัตโนมัติ
    })
    .select()
    .single();
  if (insertError || !transfer) {
    // ชนกับอีกคำขอที่สร้างพร้อมกัน → ใช้รายการนั้น
    const raced = await activeTransfer(orderId, kind);
    if (raced) return json({ transfer: raced });
    console.error("insert transfer", insertError);
    return json({ error: "transfer_failed" }, 500);
  }

  try {
    const res = await fetch(`${gatewayUrl}/v1/transfers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${gatewaySecret}`,
        "Idempotency-Key": `${kind}-${orderId}-${attempt}`,
      },
      body: JSON.stringify({
        amount,
        currency: "THB",
        destination,
        reference: order.reference,
        webhook_url: `${supabaseUrl}/functions/v1/transfers/webhook`,
        metadata: { transfer_id: transfer.id, order_id: orderId, kind },
      }),
    });
    const result = await res.json();
    if (!res.ok || !result?.id) throw new Error(JSON.stringify(result));

    const { data: updated } = await admin
      .from("payment_transfers")
      .update({ gateway_ref: result.id })
      .eq("id", transfer.id)
      .select()
      .single();
    return json({ transfer: updated ?? transfer });
  } catch (e) {
    console.error("gateway", e);
    await admin.rpc("complete_transfer", {
      p_transfer_id: transfer.id,
      p_success: false,
      p_gateway_ref: null,
      p_reason: "ติดต่อ Payment Gateway ไม่สำเร็จ",
    });
    const { data: failed } = await admin
      .from("payment_transfers")
      .select()
      .eq("id", transfer.id)
      .single();
    return json({ transfer: failed ?? transfer });
  }
}

async function activeTransfer(orderId: number, kind: string) {
  const { data } = await admin
    .from("payment_transfers")
    .select()
    .eq("order_id", orderId)
    .eq("kind", kind)
    .in("status", ["processing", "succeeded"])
    .maybeSingle();
  return data;
}

// ---------- gateway แจ้งผล ----------
async function handleWebhook(req: Request): Promise<Response> {
  const webhookSecret = Deno.env.get("MOCK_WEBHOOK_SECRET");
  if (!webhookSecret) return json({ error: "not_configured" }, 500);

  const raw = await req.text();
  const signature = req.headers.get("X-Mock-Signature") ?? "";
  const expected = await hmacHex(webhookSecret, raw);
  if (!safeEqual(signature, expected)) {
    return json({ error: "bad_signature" }, 401);
  }

  let event: any;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const transferId = Number(event?.metadata?.transfer_id);
  if (!Number.isInteger(transferId)) {
    return json({ error: "bad_request" }, 400);
  }

  const { error } = await admin.rpc("complete_transfer", {
    p_transfer_id: transferId,
    p_success: event.status === "succeeded",
    p_gateway_ref: event.id ?? null,
    p_reason: event.failure_reason ?? null,
  });
  if (error) {
    console.error("complete_transfer", error);
    return json({ error: "complete_failed" }, 500);
  }
  return json({ received: true });
}
