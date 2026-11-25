// รับเงินผู้ซื้อผ่าน Payment Gateway (ตอนนี้ใช้ mock-gateway) แบบเดียวกับ transfers แต่เป็นขาเข้า
//
// POST /charges              สร้างรายการรับเงิน (PromptPay QR) ให้คำสั่งซื้อ
//   Body: { order_id }   ใครเรียกได้: ผู้ซื้อเจ้าของคำสั่งซื้อ (แอปส่ง token)
//   ตอบ: { order: แถวใน orders พร้อม charge_id / charge_qr }
//   เรียกซ้ำได้ ได้ QR เดิม (Idempotency-Key = charge-<order_id>)
//
// POST /charges/webhook      gateway แจ้งว่าเงินเข้าแล้ว (ตรวจลายเซ็น X-Mock-Signature)
//   → complete_charge → held (schema.sql หัวข้อ 28)
//
// Deploy: supabase functions deploy charges --no-verify-jwt
//   (webhook ไม่มี token ของ Supabase จึงปิดการเช็กอัตโนมัติ แล้วเช็กเองในโค้ดแทน)
// Secrets: ใช้ชุดเดียวกับ transfers: MOCK_GATEWAY_URL, MOCK_GATEWAY_SECRET, MOCK_WEBHOOK_SECRET

import { createClient } from "jsr:@supabase/supabase-js@2";
import { hmacHex, safeEqual } from "../_shared/hmac.ts";

const MERCHANT_NAME = "Courtswap";

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
  return createCharge(req);
});

// ---------- สร้างรายการรับเงิน ----------
async function createCharge(req: Request): Promise<Response> {
  const gatewayUrl = Deno.env.get("MOCK_GATEWAY_URL");
  const gatewaySecret = Deno.env.get("MOCK_GATEWAY_SECRET");
  if (!gatewayUrl || !gatewaySecret) {
    return json({ error: "not_configured" }, 500);
  }

  // 1. ต้องล็อกอิน และเป็นผู้ซื้อของคำสั่งซื้อนี้
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: "not_logged_in" }, 401);

  let orderId: number;
  try {
    const body = await req.json();
    orderId = Number(body.order_id);
    if (!Number.isInteger(orderId)) throw new Error();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const { data: order } = await admin
    .from("orders")
    .select("*")
    .eq("id", orderId)
    .single();
  if (!order || order.buyer_id !== user.id) {
    return json({ error: "order_not_found" }, 404);
  }

  // 2. ต้องยังรอชำระ และยังไม่หมดเวลา
  if (order.status !== "pending_payment") {
    return json({ error: "order_not_pending" }, 409);
  }
  if (order.expires_at && new Date(order.expires_at).getTime() <= Date.now()) {
    return json({ error: "order_expired" }, 409);
  }

  // สร้างไปแล้ว = ใช้ QR เดิม
  if (order.charge_id && order.charge_qr) {
    return json({ order });
  }

  // 3. ขอ charge จาก gateway: ยอดและเวลาหมดอายุมาจากคำสั่งซื้อ (แอปกำหนดเองไม่ได้)
  let charge: any;
  try {
    const res = await fetch(`${gatewayUrl}/v1/charges`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${gatewaySecret}`,
        "Idempotency-Key": `charge-${orderId}`,
      },
      body: JSON.stringify({
        amount: order.amount,
        currency: "THB",
        source: "promptpay",
        reference: order.reference,
        description: MERCHANT_NAME,
        expires_at: order.expires_at,
        webhook_url: `${supabaseUrl}/functions/v1/charges/webhook`,
        metadata: { order_id: orderId },
      }),
    });
    charge = await res.json();
    if (!res.ok || !charge?.id || !charge?.qr) throw new Error(JSON.stringify(charge));
  } catch (e) {
    console.error("gateway", e);
    return json({ error: "gateway_failed" }, 502);
  }

  // 4. บันทึก charge ลงคำสั่งซื้อ
  const { data: updated, error } = await admin.rpc("attach_charge", {
    p_order_id: orderId,
    p_charge_id: charge.id,
    p_charge_qr: charge.qr,
  });
  if (error) {
    console.error("attach_charge", error);
    return json({ error: "order_not_pending" }, 409);
  }
  return json({ order: updated });
}

// ---------- gateway แจ้งว่าเงินเข้าแล้ว ----------
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
  const orderId = Number(event?.metadata?.order_id);
  const amount = Number(event?.amount);
  if (
    event?.object !== "charge" ||
    !Number.isInteger(orderId) ||
    !Number.isInteger(amount) ||
    typeof event.id !== "string"
  ) {
    return json({ error: "bad_request" }, 400);
  }
  if (event.status !== "succeeded") {
    return json({ received: true });
  }

  const { error } = await admin.rpc("complete_charge", {
    p_order_id: orderId,
    p_charge_id: event.id,
    p_amount: amount,
  });
  if (error) {
    console.error("complete_charge", error);
    return json({ error: "complete_failed" }, 500);
  }
  return json({ received: true });
}
