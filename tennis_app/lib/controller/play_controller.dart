import 'dart:async';
import 'dart:typed_data';

import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/payout_account_model.dart';
import 'package:tennis_app/services/play_service.dart';

// ตัวกลางระหว่างหน้าจอ Workflow ใช้สนามกับที่เก็บข้อมูล (แบบเดียวกับ PaymentController)
// onSync บอกหน้าจอว่ากำลังทำงานอยู่ (true) หรือเสร็จแล้ว (false)
// ใช้ finally ให้ปิดวงโหลดเสมอ แม้เกิด error หน้าจอจะได้ไม่ค้าง
class PlayController {
  List<PaymentItem> disputes = List.empty();
  final PlayService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  PlayController(this.service);

  // ---------- ฝั่งผู้ซื้อ ----------

  Future<void> confirmPlay(Order order) async {
    onSyncController.add(true);
    try {
      await service.confirmPlay(order);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<void> reportProblem(
    Order order,
    String reason,
    Uint8List? photoBytes,
    String photoName,
  ) async {
    onSyncController.add(true);
    try {
      await service.reportProblem(order, reason, photoBytes, photoName);
    } finally {
      onSyncController.add(false);
    }
  }

  // ---------- ฝั่งแอดมิน ----------

  Future<List<PaymentItem>> fetchDisputes() async {
    onSyncController.add(true);
    try {
      disputes = await service.getDisputes();
    } finally {
      onSyncController.add(false);
    }
    return disputes;
  }

  Future<String?> getFileUrl(String? path) async {
    return await service.getFileUrl(path);
  }

  Future<void> resolveDispute(Order order, bool favorBuyer, String note) async {
    onSyncController.add(true);
    try {
      await service.resolveDispute(order, favorBuyer, note);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<void> banOrderParty(Order order, bool banBuyer, String reason) async {
    onSyncController.add(true);
    try {
      await service.banOrderParty(order, banBuyer, reason);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<PayoutAccount?> getSellerPayoutAccount(Order order) async {
    return await service.getSellerPayoutAccount(order);
  }

  // ปิดท่อส่งสถานะเมื่อเลิกใช้หน้าจอ
  void dispose() {
    onSyncController.close();
  }
}
