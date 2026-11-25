// สถานะรายการรับเงินของ Payment Gateway (supabase/functions/mock-gateway)
const String kChargePending = 'pending'; // รอชำระ
const String kChargeSucceeded = 'succeeded'; // ชำระแล้ว
const String kChargeExpired = 'expired'; // หมดเวลาชำระ

// รายการรับเงิน 1 รายการ ที่แอปธนาคาร (จำลอง) อ่านได้จาก QR
class GatewayCharge {
  String id;
  int amount;
  String reference; // เลขที่คำสั่งซื้อของร้านค้า เช่น CS-00015
  String merchantName;
  String status;
  DateTime? expiresAt;
  DateTime? paidAt;

  GatewayCharge(
    this.id,
    this.amount,
    this.reference,
    this.merchantName,
    this.status,
    this.expiresAt,
    this.paidAt,
  );

  factory GatewayCharge.fromJson(Map<String, dynamic> json) {
    return GatewayCharge(
      json['id'] as String,
      (json['amount'] as num?)?.toInt() ?? 0,
      json['reference'] as String? ?? '',
      json['description'] as String? ?? '',
      json['status'] as String? ?? kChargePending,
      _readTime(json['expires_at']),
      _readTime(json['paid_at']),
    );
  }

  static DateTime? _readTime(dynamic value) {
    if (value is! String) return null;
    return DateTime.parse(value).toLocal();
  }

  bool get isPending => status == kChargePending;
  bool get isPaid => status == kChargeSucceeded;
}
