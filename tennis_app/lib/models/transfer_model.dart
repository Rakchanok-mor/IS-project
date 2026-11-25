// รายการโอนเงินผ่าน Payment Gateway (ตาราง payment_transfers)
// refund = คืนเงินผู้ซื้อ, payout = โอนเงินให้ผู้ขาย
const String kTransferRefund = 'refund';
const String kTransferPayout = 'payout';

const String kTransferProcessing =
    'processing'; // ส่งคำสั่งแล้ว รอ gateway แจ้งผล
const String kTransferSucceeded = 'succeeded';
const String kTransferFailed = 'failed';

class Transfer {
  String id;
  String orderId;
  String kind;
  int amount;
  String status;
  String
  gatewayRef; // เลขอ้างอิงจาก gateway เช่น MOCK-TRF-20261114-1A2B3C4D5E6F
  String failureReason;
  Map<String, dynamic> destination;
  DateTime? createdAt;
  DateTime? completedAt;

  Transfer({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.amount,
    required this.status,
    this.gatewayRef = '',
    this.failureReason = '',
    this.destination = const {},
    this.createdAt,
    this.completedAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      kind: json['kind'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? kTransferProcessing,
      gatewayRef: json['gateway_ref'] as String? ?? '',
      failureReason: json['failure_reason'] as String? ?? '',
      destination: json['destination'] is Map<String, dynamic>
          ? json['destination'] as Map<String, dynamic>
          : const {},
      createdAt: _readTime(json['created_at']),
      completedAt: _readTime(json['completed_at']),
    );
  }

  static DateTime? _readTime(dynamic value) {
    if (value is! String) return null;
    return DateTime.parse(value).toLocal();
  }

  bool get isProcessing => status == kTransferProcessing;
  bool get isSucceeded => status == kTransferSucceeded;
  bool get isFailed => status == kTransferFailed;

  // ปลายทางแบบอ่านง่าย เช่น "KBANK xxx-x-x2125-x" หรือ "ช่องทางเดิมที่ผู้ซื้อโอนมา"
  String get destinationText {
    final bank = destination['bank_name'] as String? ?? '';
    final account = destination['account_number'] as String? ?? '';
    final text = '$bank $account'.trim();
    if (text.isNotEmpty) return text;
    return 'ช่องทางเดิมที่ผู้ซื้อโอนมา';
  }
}
