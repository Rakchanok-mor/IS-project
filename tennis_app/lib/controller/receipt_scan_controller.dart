import 'dart:async';

import 'package:tennis_app/services/receipt_scan_service.dart';

// ตัวกลางระหว่างหน้าลงประกาศขายกับตัวอ่านรูปหลักฐาน (แบบเดียวกับ PostController)
// onSync บอกหน้าจอว่ากำลังอ่านรูปอยู่ (true) หรืออ่านเสร็จแล้ว (false)
class ReceiptScanController {
  int? scannedPrice;
  final ReceiptScanService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  ReceiptScanController(this.service);

  // ใช้ finally ให้ปิดวงโหลดเสมอ แม้อ่านไม่สำเร็จ หน้าจอจะได้ไม่ค้าง
  Future<int?> scanPrice(String imagePath) async {
    onSyncController.add(true);
    scannedPrice = null;
    try {
      scannedPrice = await service.scanPrice(imagePath);
    } finally {
      onSyncController.add(false);
    }
    return scannedPrice;
  }

  // ปิดท่อส่งสถานะและตัวอ่านรูปเมื่อเลิกใช้หน้าจอ
  void dispose() {
    onSyncController.close();
    service.close();
  }
}
