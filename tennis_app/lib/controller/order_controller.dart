import 'dart:async';
import 'dart:typed_data';

import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/services/order_service.dart';

// ตัวกลางระหว่างหน้าประกาศของฉันกับที่เก็บข้อมูล (แบบเดียวกับ PostController)
// onSync บอกหน้าจอว่ากำลังโหลด/ส่งข้อมูลอยู่ (true) หรือเสร็จแล้ว (false)
class OrderController {
  List<SellerListing> items = List.empty();
  final OrderService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  OrderController(this.service);

  Future<List<SellerListing>> fetchMySellerListings() async {
    onSyncController.add(true);
    try {
      items = await service.getMySellerListings();
    } finally {
      onSyncController.add(false);
    }
    return items;
  }

  // ส่งหลักฐานแล้วจำไว้ในออเดอร์ หน้าจอจะได้แสดงว่าส่งแล้ว
  Future<void> submitEvidence(
    Order order,
    String note,
    Uint8List bytes,
    String fileName,
  ) async {
    onSyncController.add(true);
    try {
      order.evidencePath = await service.submitEvidence(
        order,
        note,
        bytes,
        fileName,
      );
      order.sellerNote = note;
      order.evidenceAt = DateTime.now();
    } finally {
      onSyncController.add(false);
    }
  }

  void dispose() {
    onSyncController.close();
  }
}
