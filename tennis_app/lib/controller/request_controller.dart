import 'dart:async';

import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/request_model.dart';
import 'package:tennis_app/services/request_service.dart';

// ตัวกลางระหว่างหน้าตั้งรับกับที่เก็บข้อมูล (แบบเดียวกับ PostController ในงานวิชา)
// onSync จะบอกหน้าจอว่ากำลังบันทึก/โหลดอยู่ (true) หรือเสร็จแล้ว (false)
class RequestController {
  List<MyRequest> myRequests = List.empty();
  List<ListingRequest> listingRequests = List.empty();
  final RequestService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  RequestController(this.service);

  // ใช้ finally ให้ปิดวงโหลดเสมอ แม้บันทึกไม่สำเร็จ หน้าจอจะได้ไม่ค้าง
  Future<void> createRequest(CourtRequest request) async {
    onSyncController.add(true);
    try {
      await service.createRequest(request);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<List<MyRequest>> fetchMyRequests() async {
    onSyncController.add(true);
    try {
      myRequests = await service.getMyRequests();
    } finally {
      onSyncController.add(false);
    }
    return myRequests;
  }

  // ฝั่งผู้ขาย (A5): ผู้ตั้งรับที่ตรงกับประกาศของเรา
  Future<List<ListingRequest>> fetchListingRequests(Listing listing) async {
    onSyncController.add(true);
    try {
      listingRequests = await service.getListingRequests(listing);
    } finally {
      onSyncController.add(false);
    }
    return listingRequests;
  }

  // ปิดท่อส่งสถานะเมื่อเลิกใช้หน้าจอ
  void dispose() {
    onSyncController.close();
  }
}
