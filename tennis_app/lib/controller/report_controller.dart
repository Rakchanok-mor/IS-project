import 'dart:async';

import 'package:tennis_app/models/report_model.dart';
import 'package:tennis_app/services/report_service.dart';

// ตัวกลางระหว่างหน้ารายงานกับที่เก็บข้อมูล
// onSync บอกหน้าจอว่ากำลังโหลดอยู่ (true) หรือเสร็จแล้ว (false)
class ReportController {
  List<ReportOrder> orders = List.empty();
  List<SalesReportRow> salesRows = List.empty();
  List<StatusReportRow> statusRows = List.empty();
  IncomeReport income = IncomeReport.empty();
  final ReportService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  ReportController(this.service);

  // แอดมิน: ดึงออเดอร์ทั้งหมดครั้งเดียว แล้วรวมเป็น 2 รายงาน
  Future<void> fetchAdminReports(String period) async {
    onSyncController.add(true);
    try {
      orders = await service.getAllOrders();
    } finally {
      onSyncController.add(false);
    }
    salesRows = SalesReportRow.fromOrders(orders, period);
    statusRows = StatusReportRow.fromOrders(orders);
  }

  // แอดมิน: เปลี่ยนรายวัน/รายเดือน ใช้ออเดอร์ที่โหลดไว้แล้ว ไม่ต้องดึงใหม่
  List<SalesReportRow> changePeriod(String period) {
    salesRows = SalesReportRow.fromOrders(orders, period);
    return salesRows;
  }

  // ผู้ขาย: สรุปรายได้จากออเดอร์ของประกาศเรา
  Future<IncomeReport> fetchMyIncome() async {
    onSyncController.add(true);
    try {
      final myOrders = await service.getMySellerOrders();
      income = IncomeReport.fromOrders(myOrders);
    } finally {
      onSyncController.add(false);
    }
    return income;
  }

  void dispose() {
    onSyncController.close();
  }
}
