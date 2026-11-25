import 'package:tennis_app/models/order_model.dart';

// ข้อมูลรายงาน: service ดึงออเดอร์ดิบจากตาราง orders มา (ReportOrder)
// แล้วคลาสในไฟล์นี้วนลูปรวมยอดใน Dart

// ช่วงเวลาของรายงานยอดขาย
const String kReportDaily = 'day'; // 30 วันล่าสุด
const String kReportMonthly = 'month'; // 12 เดือนล่าสุด

// สถานะที่นับว่า "ขายได้จริง" = ชำระแล้วและไม่ถูกคืนเงิน
const List<String> kSoldStatuses = [
  kOrderHeld,
  kOrderConfirmed,
  kOrderReleased,
  kOrderDisputed,
];

// สถานะที่จ่ายแล้วแต่ยังไม่ได้โอนให้ผู้ขาย (รอโอน)
const List<String> kWaitingPayoutStatuses = [
  kOrderHeld,
  kOrderConfirmed,
  kOrderDisputed,
];

// ค่าธรรมเนียมที่แพลตฟอร์มได้จากออเดอร์ 1 รายการ (ไม่เกินราคาขาย)
int platformFeeOf(int amount) {
  return amount < kPlatformFee ? amount : kPlatformFee;
}

// ออเดอร์ 1 รายการ เอาเฉพาะคอลัมน์ที่รายงานใช้
class ReportOrder {
  int amount;
  String status;
  DateTime? paidAt;

  ReportOrder(this.amount, this.status, this.paidAt);

  bool get isSold => kSoldStatuses.contains(status);

  factory ReportOrder.fromJson(Map<String, dynamic> json) {
    final paidAt = json['paid_at'] as String?;
    return ReportOrder(
      json['amount'] as int? ?? 0,
      json['status'] as String,
      // เก็บใน DB เป็นเวลา UTC แปลงเป็นเวลาเครื่อง (ไทย) ก่อนแบ่งวัน
      paidAt == null ? null : DateTime.parse(paidAt).toLocal(),
    );
  }
}

class AllReportOrders {
  final List<ReportOrder> orders;
  AllReportOrders(this.orders);

  factory AllReportOrders.fromJson(List<dynamic> json) {
    List<ReportOrder> orders;
    orders = json.map((item) => ReportOrder.fromJson(item)).toList();
    return AllReportOrders(orders);
  }
}

// ---------- รายงานที่ 1 (แอดมิน): ยอดขายรายวัน / รายเดือน ----------

// ยอดขาย 1 ช่วง (1 วัน หรือ 1 เดือน)
class SalesReportRow {
  DateTime periodStart;
  int orderCount;
  int totalAmount;
  int feeTotal;

  SalesReportRow(
    this.periodStart,
    this.orderCount,
    this.totalAmount,
    this.feeTotal,
  );

  // รวมยอดจากออเดอร์ แยกตามวัน/เดือนที่ชำระ ใหม่สุดขึ้นก่อน
  // ค่าธรรมเนียมนับเฉพาะออเดอร์ที่โอนให้ผู้ขายแล้ว
  static List<SalesReportRow> fromOrders(
    List<ReportOrder> orders,
    String period,
  ) {
    final now = DateTime.now();
    final DateTime from = period == kReportDaily
        ? now.subtract(const Duration(days: 30))
        : DateTime(now.year, now.month - 11, 1);

    final Map<DateTime, SalesReportRow> rows = {};
    for (final order in orders) {
      final paidAt = order.paidAt;
      if (paidAt == null || !order.isSold || paidAt.isBefore(from)) {
        continue;
      }

      final DateTime key = period == kReportDaily
          ? DateTime(paidAt.year, paidAt.month, paidAt.day)
          : DateTime(paidAt.year, paidAt.month);
      final row = rows.putIfAbsent(key, () => SalesReportRow(key, 0, 0, 0));
      row.orderCount += 1;
      row.totalAmount += order.amount;
      if (order.status == kOrderReleased) {
        row.feeTotal += platformFeeOf(order.amount);
      }
    }

    final result = rows.values.toList();
    result.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return result;
  }
}

// ---------- รายงานที่ 2 (แอดมิน): คำสั่งซื้อแยกตามสถานะ ----------

// จำนวนคำสั่งซื้อ 1 สถานะ
class StatusReportRow {
  String status;
  int orderCount;
  int totalAmount;

  StatusReportRow(this.status, this.orderCount, this.totalAmount);

  // ชื่อสถานะภาษาไทยสำหรับแอดมิน (แยกละเอียดกว่าที่ผู้ซื้อเห็น)
  String get label {
    if (status == kOrderPendingPayment) return 'รอชำระเงิน';
    if (status == kOrderHeld) return 'ชำระแล้ว รอใช้สนาม';
    if (status == kOrderConfirmed) return 'ยืนยันแล้ว รอโอนผู้ขาย';
    if (status == kOrderReleased) return 'โอนผู้ขายแล้ว';
    if (status == kOrderDisputed) return 'มีข้อพิพาท';
    if (status == kOrderRejected) return 'รอคืนเงิน';
    if (status == kOrderRefunded) return 'คืนเงินแล้ว';
    if (status == kOrderExpired) return 'หมดเวลาชำระ';
    if (status == kOrderCancelled) return 'ยกเลิก';
    return status;
  }

  // นับออเดอร์ทุกรายการแยกตามสถานะ สถานะที่มีมากสุดขึ้นก่อน
  static List<StatusReportRow> fromOrders(List<ReportOrder> orders) {
    final Map<String, StatusReportRow> rows = {};
    for (final order in orders) {
      final row = rows.putIfAbsent(
        order.status,
        () => StatusReportRow(order.status, 0, 0),
      );
      row.orderCount += 1;
      row.totalAmount += order.amount;
    }

    final result = rows.values.toList();
    result.sort((a, b) => b.orderCount.compareTo(a.orderCount));
    return result;
  }
}

// ---------- รายงานที่ 3 (ผู้ขาย): สรุปรายได้ ----------

class IncomeReport {
  int soldCount; // ขายได้ (ชำระแล้ว ไม่ถูกคืนเงิน)
  int salesTotal; // ยอดขายรวม ก่อนหักค่าธรรมเนียม
  int receivedTotal; // โอนเข้าบัญชีแล้ว
  int pendingTotal; // รอโอน
  int feeTotal; // ค่าธรรมเนียมที่ถูกหักไปแล้ว
  int refundedCount; // ถูกคืนเงินผู้ซื้อ

  IncomeReport(
    this.soldCount,
    this.salesTotal,
    this.receivedTotal,
    this.pendingTotal,
    this.feeTotal,
    this.refundedCount,
  );

  // ยังไม่โหลด / ยังไม่เคยขาย
  factory IncomeReport.empty() {
    return IncomeReport(0, 0, 0, 0, 0, 0);
  }

  // รวมยอดจากออเดอร์ของประกาศเรา
  factory IncomeReport.fromOrders(List<ReportOrder> orders) {
    final report = IncomeReport.empty();
    for (final order in orders) {
      if (order.isSold) {
        report.soldCount += 1;
        report.salesTotal += order.amount;
      }
      if (order.status == kOrderReleased) {
        report.receivedTotal += sellerPayoutOf(order.amount);
        report.feeTotal += platformFeeOf(order.amount);
      }
      if (kWaitingPayoutStatuses.contains(order.status)) {
        report.pendingTotal += sellerPayoutOf(order.amount);
      }
      if (order.status == kOrderRejected || order.status == kOrderRefunded) {
        report.refundedCount += 1;
      }
    }
    return report;
  }
}
