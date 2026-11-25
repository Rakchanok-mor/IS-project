import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';

// คำสั่งซื้อ 1 รายการพร้อมประกาศที่ซื้อ ใช้ในหน้าฝั่งผู้ซื้อและหน้าแอดมิน
class PaymentItem {
  Listing listing;
  Order order;

  PaymentItem(this.listing, this.order);

  // แถวจากตาราง orders ที่ดึงประกาศมาด้วย (select '*, listings(*, courts(name))')
  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      Listing.fromJson(json['listings'] as Map<String, dynamic>),
      Order.fromJson(json),
    );
  }

  // ผู้ซื้อยืนยัน/แจ้งปัญหาได้ถึงเวลานี้ เลยแล้วระบบยืนยันให้
  DateTime get confirmDeadline {
    return listing.endTime.add(const Duration(hours: kConfirmHours));
  }

  // ผู้ซื้อกดยืนยันการเล่นหรือแจ้งปัญหาได้ไหม (B9)
  // ได้ทันทีหลังชำระเงินสำเร็จ จนถึง 24 ชม. หลังเล่นจบ (เลยแล้วระบบยืนยันให้)
  bool get canConfirmPlay {
    return order.status == kOrderHeld &&
        DateTime.now().isBefore(confirmDeadline);
  }

  // ถึงเวลาเล่นแล้วหรือยัง (ใช้เปลี่ยนข้อความในกล่องสถานะ)
  bool get hasStarted => DateTime.now().isAfter(listing.startTime);

  // ข้อความสถานะสำหรับผู้ซื้อ
  String get buyerStatusLabel {
    final status = order.status;
    if (status == kOrderPendingPayment) return 'รอชำระเงิน';
    if (status == kOrderRejected) return 'กำลังคืนเงิน';
    if (status == kOrderRefunded) return 'คืนเงินแล้ว';
    if (status == kOrderExpired) return 'หมดเวลาชำระ';
    if (status == kOrderCancelled) return 'ยกเลิกแล้ว';
    if (status == kOrderDisputed) return 'แจ้งปัญหาแล้ว';
    if (status == kOrderReleased || status == kOrderConfirmed) {
      return 'เสร็จสิ้น';
    }
    if (canConfirmPlay) return 'รอยืนยันการเล่น';
    return 'ชำระเงินสำเร็จ';
  }

  // ข้อความสถานะของข้อพิพาทสำหรับแอดมิน (U6)
  String get disputeStatusLabel {
    if (order.resolution == kResolutionBuyer) return 'คืนเงินผู้ซื้อ';
    if (order.resolution == kResolutionSeller) return 'โอนให้ผู้ขาย';
    if (order.hasEvidence) return 'รอตัดสิน';
    return 'รอผู้ขายชี้แจง';
  }
}

// รวมคำสั่งซื้อหลายรายการ (แบบเดียวกับ AllListings)
class AllPaymentItems {
  final List<PaymentItem> items;
  AllPaymentItems(this.items);

  factory AllPaymentItems.fromJson(List<dynamic> json) {
    List<PaymentItem> items;
    items = json
        .map((item) => PaymentItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllPaymentItems(items);
  }
}
