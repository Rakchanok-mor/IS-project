import 'package:tennis_app/models/listing_model.dart';

// สถานะของออเดอร์ (เงินที่ผู้ซื้อจ่ายเข้ามา) เรียงตามลำดับใน workflow การชำระเงิน
const String kOrderPendingPayment =
    'pending_payment'; // กดซื้อแล้ว รอสแกนจ่าย (15 นาที)
const String kOrderRejected =
    'rejected'; // ต้องคืนเงินผู้ซื้อ (ผลตัดสินข้อพิพาท) รอแอดมินคืนเงิน
const String kOrderExpired = 'expired'; // ไม่ชำระภายในเวลา ปลดล็อกประกาศแล้ว
const String kOrderCancelled = 'cancelled'; // ผู้ซื้อยกเลิกเองก่อนชำระ
const String kOrderHeld = 'held'; // ผู้ซื้อจ่ายแล้ว เงินถูก Hold ไว้ในระบบ
const String kOrderConfirmed = 'confirmed'; // ผู้ซื้อยืนยันว่าได้เล่นแล้ว รอโอน
const String kOrderReleased = 'released'; // โอนเงินให้ผู้ขายแล้ว
const String kOrderDisputed = 'disputed'; // ผู้ซื้อแจ้งปัญหา
const String kOrderRefunded = 'refunded'; // คืนเงินให้ผู้ซื้อแล้ว

// ช่วงเวลาใน Workflow ใช้สนาม (ต้องตรงกับฟังก์ชันใน supabase/schema.sql)
const int kConfirmHours =
    24; // ผู้ซื้อยืนยัน/แจ้งปัญหาได้ถึงกี่ชม.หลังเล่นจบ เลยแล้วระบบยืนยันให้
const int kEvidenceHours =
    24; // ผู้ขายส่งหลักฐานโต้แย้งได้ภายในกี่ชม.หลังผู้ซื้อแจ้งปัญหา
const int kPayoutHours =
    48; // แอดมินต้องโอนให้ผู้ขายภายในกี่ชม.หลังผู้ซื้อยืนยัน

// ค่าธรรมเนียมแพลตฟอร์ม หักจากเงินที่โอนให้ผู้ขาย ต่อ 1 ธุรกรรม
// (ต้องตรงกับ add_notification ตอนโอนเงินใน supabase/schema.sql)
const int kPlatformFee = 50;

// เงินที่ผู้ขายได้รับจริง = ราคาขาย - ค่าธรรมเนียม (ไม่ติดลบ)
int sellerPayoutOf(int amount) {
  final payout = amount - kPlatformFee;
  return payout < 0 ? 0 : payout;
}

// จำนวนขั้นตอนฝั่งผู้ขายกว่าจะได้เงิน
const int kSellerSteps = 4;

// ผลตัดสินข้อพิพาท
const String kResolutionBuyer = 'buyer'; // คืนเงินผู้ซื้อ
const String kResolutionSeller = 'seller'; // โอนให้ผู้ขาย

// เวลาที่เหลือแบบ ชม:นาที:วินาที เช่น "47:42:10" (หมดแล้ว = "00:00:00")
String countdownText(Duration left) {
  if (left.isNegative) return '00:00:00';
  final hours = left.inHours.toString().padLeft(2, '0');
  final minutes = (left.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

// วันที่พร้อมเวลา เช่น "ส. 26 ก.ค. 2568 16:05"
String thaiDateTime(DateTime time) {
  return '${thaiShortDate(time, withYear: true)} ${hourMinuteText(time)}';
}

// ออเดอร์ 1 รายการจากตาราง orders
class Order {
  String id;
  String reference;
  String buyerName;
  int amount;
  DateTime? releasedAt;
  String status;
  String disputeReason;
  String? evidencePath;

  // ข้อมูลช่วงชำระเงิน (ไม่ใส่ก็ได้)
  String listingId;
  DateTime? createdAt;
  DateTime? expiresAt; // ต้องชำระก่อนเวลานี้
  String rejectReason;
  DateTime? refundedAt;

  // รับเงินผ่าน Payment Gateway (supabase/functions/charges) ยังไม่สร้าง = null
  String? chargeId;
  String? chargeQr; // ข้อความใน QR ที่ gateway ออกให้
  String chargeStatus; // pending / succeeded (ยังไม่สร้าง = '')

  // paidAt = เวลาที่ gateway แจ้งว่าเงินเข้าแล้ว (ยังไม่จ่าย = null)
  DateTime? paidAt;

  // ข้อมูลช่วงใช้สนาม (Workflow ใช้สนาม)
  DateTime? confirmedAt; // ผู้ซื้อยืนยันว่าได้เล่น (หรือระบบยืนยันให้)
  bool autoConfirmed; // true = ระบบยืนยันให้เพราะผู้ซื้อไม่กดภายในเวลา
  String
  disputeCategory; // หัวข้อปัญหา (ข้อพิพาทเก่า ตอนนี้แจ้งแค่รายละเอียด จึงว่าง)
  String? disputePhotoPath; // รูปที่ผู้ซื้อแนบตอนแจ้งปัญหา
  DateTime? disputedAt;
  String sellerNote; // คำชี้แจงของผู้ขาย
  DateTime? evidenceAt; // เวลาที่ผู้ขายส่งหลักฐาน
  String?
  resolution; // ผลตัดสิน: kResolutionBuyer / kResolutionSeller (ยังไม่ตัดสิน = null)
  String resolutionNote; // บันทึกของแอดมินตอนตัดสิน
  DateTime? resolvedAt;

  Order(
    this.id,
    this.reference,
    this.buyerName,
    this.amount,
    this.paidAt,
    this.releasedAt,
    this.status,
    this.disputeReason,
    this.evidencePath, {
    this.listingId = '',
    this.createdAt,
    this.expiresAt,
    this.rejectReason = '',
    this.refundedAt,
    this.chargeId,
    this.chargeQr,
    this.chargeStatus = '',
    this.confirmedAt,
    this.autoConfirmed = false,
    this.disputeCategory = '',
    this.disputePhotoPath,
    this.disputedAt,
    this.sellerNote = '',
    this.evidenceAt,
    this.resolution,
    this.resolutionNote = '',
    this.resolvedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      json['id'].toString(),
      json['reference'] as String? ?? '',
      json['buyer_name'] as String? ?? '',
      (json['amount'] as num?)?.toInt() ?? 0,
      _readTime(json['paid_at']),
      _readTime(json['released_at']),
      json['status'] as String? ?? kOrderPendingPayment,
      json['dispute_reason'] as String? ?? '',
      json['evidence_path'] as String?,
      listingId: json['listing_id']?.toString() ?? '',
      createdAt: _readTime(json['created_at']),
      expiresAt: _readTime(json['expires_at']),
      rejectReason: json['reject_reason'] as String? ?? '',
      refundedAt: _readTime(json['refunded_at']),
      chargeId: json['charge_id'] as String?,
      chargeQr: json['charge_qr'] as String?,
      chargeStatus: json['charge_status'] as String? ?? '',
      confirmedAt: _readTime(json['confirmed_at']),
      autoConfirmed: json['auto_confirmed'] as bool? ?? false,
      disputeCategory: json['dispute_category'] as String? ?? '',
      disputePhotoPath: json['dispute_photo_path'] as String?,
      disputedAt: _readTime(json['disputed_at']),
      sellerNote: json['seller_note'] as String? ?? '',
      evidenceAt: _readTime(json['evidence_at']),
      resolution: json['resolution'] as String?,
      resolutionNote: json['resolution_note'] as String? ?? '',
      resolvedAt: _readTime(json['resolved_at']),
    );
  }

  static DateTime? _readTime(dynamic value) {
    if (value is! String) return null;
    return DateTime.parse(value).toLocal();
  }

  // เงินเข้าระบบแล้ว (gateway ยืนยันแล้ว)
  bool get isPaid {
    return status == kOrderHeld ||
        status == kOrderConfirmed ||
        status == kOrderReleased ||
        status == kOrderDisputed;
  }

  // ออเดอร์ที่ยังล็อกประกาศอยู่ (ที่เหลือคือ หมดเวลา/ยกเลิก/คืนเงินแล้ว ประกาศกลับมาขายได้)
  bool get isActive {
    return status != kOrderExpired &&
        status != kOrderCancelled &&
        status != kOrderRefunded;
  }

  // เวลาที่เหลือให้ชำระ (ติดลบ = หมดเวลาแล้ว)
  Duration get timeLeft {
    final expires = expiresAt;
    if (expires == null) return Duration.zero;
    return expires.difference(DateTime.now());
  }

  // เงินที่โอนให้ผู้ขาย หลังหักค่าธรรมเนียมแพลตฟอร์ม
  int get sellerPayout => sellerPayoutOf(amount);

  // เคยมีข้อพิพาท (ใช้แยกว่าคืนเงินเพราะการชำระไม่ผ่าน หรือเพราะผลตัดสินข้อพิพาท)
  bool get wasDisputed => disputedAt != null;

  // สรุปปัญหาแบบสั้น ใช้ในที่ที่พื้นที่น้อย (การ์ด / ขั้นตอน)
  // ข้อพิพาทเก่าที่มีหัวข้อ = หัวข้อ, ใหม่ = 40 ตัวอักษรแรกของรายละเอียด
  String get problemSummary {
    if (disputeCategory.isNotEmpty) return disputeCategory;
    final text = disputeReason.trim().replaceAll('\n', ' ');
    if (text.length <= 40) return text;
    return '${text.substring(0, 40)}…';
  }

  bool get hasEvidence => evidencePath != null;

  // ผู้ขายต้องส่งหลักฐานก่อนเวลานี้
  DateTime? get evidenceDeadline {
    return disputedAt?.add(const Duration(hours: kEvidenceHours));
  }

  // เวลาที่เหลือให้ผู้ขายส่งหลักฐาน (ติดลบ = หมดเวลาแล้ว)
  Duration get evidenceTimeLeft {
    final deadline = evidenceDeadline;
    if (deadline == null) return Duration.zero;
    return deadline.difference(DateTime.now());
  }

  // แอดมินต้องโอนให้ผู้ขายก่อนเวลานี้
  DateTime? get payoutDeadline {
    return confirmedAt?.add(const Duration(hours: kPayoutHours));
  }
}

// ประกาศของผู้ขาย 1 รายการ คู่กับออเดอร์ (ถ้ามีคนซื้อแล้ว)
class SellerListing {
  Listing listing;
  Order? order;

  // จำนวนผู้ซื้อที่ตั้งรับตรงกับประกาศนี้ (A5) ใส่ทีหลังในชั้น service
  int requestCount = 0;

  SellerListing(this.listing, this.order);

  // มีผู้ตั้งรับตรง และประกาศยังขายได้ (แตะการ์ดแล้วไปดูรายชื่อผู้ตั้งรับ)
  bool get hasMatchingRequests =>
      requestCount > 0 && order == null && listing.isAvailable;

  // แถวจากตาราง listings ที่ดึง orders มาด้วย (select '*, courts(name), orders(*)')
  factory SellerListing.fromJson(Map<String, dynamic> json) {
    // ประกาศ 1 รายการมีได้หลายออเดอร์ (เช่น คนแรกหมดเวลา คนที่สองซื้อต่อ)
    // ใช้ออเดอร์ที่ยังล็อกประกาศอยู่ ถ้าไม่มีถือว่ายังไม่มีผู้ซื้อ
    final orders = json['orders'];
    List<dynamic> list = List.empty();
    if (orders is Map<String, dynamic>) {
      list = [orders];
    } else if (orders is List) {
      list = orders;
    }

    Order? active;
    Order? latest;
    for (final item in list) {
      final order = Order.fromJson(item as Map<String, dynamic>);
      if (order.isActive) {
        active = order;
      }
      if (latest == null || int.parse(order.id) > int.parse(latest.id)) {
        latest = order;
      }
    }

    // ประกาศถูกปิด (ขายแล้ว) แต่คำสั่งซื้อจบไปแล้ว เช่น คืนเงินผู้ซื้อจากข้อพิพาท
    // → แสดงคำสั่งซื้อล่าสุด (คืนเงินแล้ว) ไม่ใช่ "รอผู้ซื้อ"
    final listing = Listing.fromJson(json);
    if (active == null && listing.status == kStatusSold) {
      active = latest;
    }

    return SellerListing(listing, active);
  }

  bool get hasBuyer => order != null;

  // ผู้ซื้อจ่ายเงินแล้วและแอดมินยืนยันแล้ว (ดูหน้าสถานะการชำระเงินได้)
  bool get isPaid => order?.isPaid ?? false;
  bool get isDisputed => order?.status == kOrderDisputed;

  // เวลาเล่นจบไปแล้วหรือยัง
  bool get isPlayed => DateTime.now().isAfter(listing.endTime);

  // ประกาศหมดเวลาโดยไม่มีคนซื้อ: ระบบเปลี่ยนเป็น expired แล้ว
  // หรือเลยเวลาเล่นไปแล้ว (เผื่อ pg_cron ยังไม่ได้รันรอบล่าสุด)
  bool get isExpired => listing.status == kStatusExpired || isPlayed;

  // จบแล้ว = อยู่แท็บประวัติ: โอนเงิน/คืนเงินแล้ว หรือหมดเวลาโดยไม่มีคนซื้อ
  bool get isFinished {
    final status = order?.status;
    if (status == kOrderReleased || status == kOrderRefunded) {
      return true;
    }
    return order == null && isExpired;
  }

  // ระบบจะยืนยันแทนผู้ซื้อเมื่อไร (ถ้าผู้ซื้อไม่กดยืนยันหรือแจ้งปัญหา)
  DateTime get autoConfirmAt {
    return listing.endTime.add(const Duration(hours: kConfirmHours));
  }

  // ผู้ขายยังส่งหลักฐานโต้แย้งได้ไหม
  // ส่งคำชี้แจงได้ครั้งเดียว: ส่งแล้วแก้ไขไม่ได้
  bool get canSendEvidence {
    final current = order;
    return current != null &&
        current.status == kOrderDisputed &&
        !current.hasEvidence &&
        !current.evidenceTimeLeft.isNegative;
  }

  // ขั้นตอนฝั่งผู้ขายกว่าจะได้เงิน (หน้าสถานะประกาศ 13)
  // 0 มีผู้ซื้อกดซื้อ  1 ผู้ซื้อชำระเงิน  2 ผู้ซื้อยืนยันการเล่น  3 Courtswap โอนเงินให้คุณ
  // คืนค่า = ขั้นที่กำลังรออยู่ (4 = ครบทุกขั้น ได้เงินแล้ว)
  int get sellerStep {
    final status = order?.status;
    if (status == null) return 0;
    if (status == kOrderReleased) return 4;
    if (status == kOrderConfirmed) return 3;
    if (status == kOrderHeld || status == kOrderDisputed) return 2;
    return 1; // รอผู้ซื้อชำระ
  }

  // เหลืออีกกี่ขั้นจะได้เงิน
  int get stepsLeft => kSellerSteps - sellerStep;

  // ออเดอร์นี้ปิดไปแล้วโดยผู้ขายไม่ได้เงิน (คืนเงินผู้ซื้อ)
  bool get isRefundedToBuyer {
    final status = order?.status;
    return status == kOrderRejected || status == kOrderRefunded;
  }

  // ราคาที่ผู้ซื้อจ่าย (มีออเดอร์ = ยอดในออเดอร์, ยังไม่มี = ราคาในประกาศ)
  int get saleAmount => order?.amount ?? listing.price;

  // เงินที่ผู้ขายจะได้รับ หลังหักค่าธรรมเนียมแพลตฟอร์ม
  int get payoutAmount => sellerPayoutOf(saleAmount);

  // ข้อความบนป้ายสถานะ
  String get statusLabel {
    final status = order?.status;
    if (status == null) {
      if (isExpired) return 'หมดเวลา';
      return 'รอผู้ซื้อ';
    }
    if (status == kOrderPendingPayment) return 'รอผู้ซื้อชำระ';
    if (status == kOrderRejected) {
      return order!.wasDisputed ? 'คืนเงินผู้ซื้อ' : 'ชำระไม่ผ่าน';
    }
    if (status == kOrderDisputed) {
      return order!.hasEvidence ? 'รอแอดมินตัดสิน' : 'มีข้อพิพาท';
    }
    if (status == kOrderRefunded) return 'คืนเงินแล้ว';
    if (status == kOrderReleased) return 'โอนแล้ว';
    if (status == kOrderConfirmed) return 'รอโอนเงิน';
    if (isPlayed) return 'รอผู้ซื้อยืนยัน';
    return 'ผู้ซื้อชำระแล้ว';
  }
}

// รวมประกาศของผู้ขายหลายรายการ (แบบเดียวกับ AllListings)
class AllSellerListings {
  final List<SellerListing> items;
  AllSellerListings(this.items);

  factory AllSellerListings.fromJson(List<dynamic> json) {
    List<SellerListing> items;
    items = json
        .map((item) => SellerListing.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllSellerListings(items);
  }
}
