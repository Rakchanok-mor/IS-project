// ลายเซ็น webhook แบบ HMAC-SHA256 (hex) ใช้ร่วมกันระหว่าง mock-gateway กับ transfers

const encoder = new TextEncoder();

export async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  return [...new Uint8Array(signature)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// เทียบแบบใช้เวลาเท่ากันทุกตัวอักษร กันเดาลายเซ็นจากเวลาตอบ
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
