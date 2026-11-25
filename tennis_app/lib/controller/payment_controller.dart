import 'dart:async';

import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/transfer_model.dart';
import 'package:tennis_app/services/payment_service.dart';

// ตัวกลางระหว่างหน้าจอการชำระเงินกับที่เก็บข้อมูล (แบบเดียวกับ PostController)
// onSync บอกหน้าจอว่ากำลังทำงานอยู่ (true) หรือเสร็จแล้ว (false)
// ใช้ finally ให้ปิดวงโหลดเสมอ แม้เกิด error หน้าจอจะได้ไม่ค้าง
class PaymentController {
  List<PaymentItem> items = List.empty();
  final PaymentService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  PaymentController(this.service);

  // ---------- ฝั่งผู้ซื้อ ----------

  Future<Order> createOrder(Listing listing) async {
    onSyncController.add(true);
    try {
      return await service.createOrder(listing);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<Order> createCharge(Order order) async {
    onSyncController.add(true);
    try {
      return await service.createCharge(order);
    } finally {
      onSyncController.add(false);
    }
  }

  // เช็กสถานะล่าสุดเงียบ ๆ (ไม่ส่ง onSync) ใช้ถามซ้ำทุกไม่กี่วินาทีตอนรอเงินเข้า
  Future<Order> refreshOrder(Order order) async {
    final item = await service.getOrder(order.id);
    return item.order;
  }

  Future<void> cancelOrder(Order order) async {
    onSyncController.add(true);
    try {
      await service.cancelOrder(order);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<void> expireOrder(Order order) async {
    onSyncController.add(true);
    try {
      await service.expireOrder(order);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<PaymentItem> fetchOrder(String orderId) async {
    onSyncController.add(true);
    try {
      return await service.getOrder(orderId);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<List<PaymentItem>> fetchMyPurchases() async {
    onSyncController.add(true);
    try {
      items = await service.getMyPurchases();
    } finally {
      onSyncController.add(false);
    }
    return items;
  }

  Future<String?> getProofUrl(Listing listing) async {
    return await service.getProofUrl(listing);
  }

  Future<String?> getSellerFullName(Order order) async {
    return await service.getSellerFullName(order);
  }

  // ---------- ฝั่งแอดมิน ----------

  Future<bool> isAdmin() async {
    return await service.isAdmin();
  }

  // เหตุผลที่โดนแบน (ไม่โดนแบน = null) ใช้ใน AuthGate
  Future<String?> getMyBanReason() async {
    return await service.getMyBanReason();
  }

  Future<List<PaymentItem>> fetchAdminQueue() async {
    onSyncController.add(true);
    try {
      items = await service.getAdminQueue();
    } finally {
      onSyncController.add(false);
    }
    return items;
  }

  // ---------- โอนเงินผ่าน Payment Gateway ----------

  // สั่งโอนแล้วรอผล (gateway แจ้งผลผ่าน webhook ภายในไม่กี่วินาที)
  // เกินเวลารอ = คืนรายการที่ยังเป็น processing ให้หน้าจอบอกว่ากำลังโอน
  Future<Transfer> transferAndWait(
    Order order,
    String kind, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    onSyncController.add(true);
    try {
      var transfer = await service.requestTransfer(order, kind);
      final deadline = DateTime.now().add(timeout);
      while (transfer.isProcessing && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 1500));
        transfer = await service.getTransfer(transfer.id);
      }
      return transfer;
    } finally {
      onSyncController.add(false);
    }
  }

  // สั่งโอนอย่างเดียว ไม่รอผล (ผู้ซื้อกดได้เล่นแล้ว → โอนให้ผู้ขาย)
  Future<Transfer> requestTransfer(Order order, String kind) async {
    return await service.requestTransfer(order, kind);
  }

  Future<Transfer?> getLatestTransfer(Order order, String kind) async {
    return await service.getLatestTransfer(order, kind);
  }

  // ปิดท่อส่งสถานะเมื่อเลิกใช้หน้าจอ
  void dispose() {
    onSyncController.close();
  }
}
