// ธนาคารที่ผู้ขายเลือกรับเงินได้
const List<String> kBanks = [
  'พร้อมเพย์',
  'กสิกรไทย (KBANK)',
  'ไทยพาณิชย์ (SCB)',
  'กรุงเทพ (BBL)',
  'กรุงไทย (KTB)',
  'กรุงศรีอยุธยา (BAY)',
  'ทหารไทยธนชาต (ttb)',
  'ออมสิน (GSB)',
];

// บัญชีรับเงินของผู้ขาย 1 บัญชี (ตาราง payout_accounts)
// แอดมินใช้โอนเงินให้ผู้ขายหลังผู้ซื้อยืนยันว่าได้เล่นแล้ว (U1/U2)
class PayoutAccount {
  String bankName;
  String accountNumber;
  String accountName;

  PayoutAccount(this.bankName, this.accountNumber, this.accountName);

  factory PayoutAccount.fromJson(Map<String, dynamic> json) {
    return PayoutAccount(
      json['bank_name'] as String? ?? '',
      json['account_number'] as String? ?? '',
      json['account_name'] as String? ?? '',
    );
  }

  // ข้อมูลที่บันทึกลงตาราง (user_id ใส่ในชั้น service)
  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // เลขบัญชีแบบปิดบางส่วน เช่น "••• 4729"
  String get maskedNumber {
    final digits = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return digits;
    return '••• ${digits.substring(digits.length - 4)}';
  }
}
