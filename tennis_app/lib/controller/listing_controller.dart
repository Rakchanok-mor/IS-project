import 'dart:async';

import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/new_listing_model.dart';
import 'package:tennis_app/services/listing_service.dart';

// ตัวกลางระหว่างหน้าจอกับที่เก็บข้อมูล (แบบเดียวกับ PostController ในงานวิชา)
// onSync จะบอกหน้าจอว่ากำลังโหลดอยู่ (true) หรือโหลดเสร็จแล้ว (false)
class ListingController {
  List<Listing> myListings = List.empty();
  final ListingService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  ListingController(this.service);

  Future<List<Listing>> fetchMyListings(String sport) async {
    onSyncController.add(true);
    try {
      myListings = await service.getMyListings(sport);
    } finally {
      onSyncController.add(false);
    }
    return myListings;
  }

  // ค้นหาประกาศ (ไม่ส่ง onSync เพราะหน้าค้นหาจะขึ้นวงโหลดเต็มจอ
  // ช่องค้นหาจะหายไประหว่างพิมพ์ หน้าจอจัดการสถานะกำลังค้นหาเอง)
  Future<List<Listing>> searchListings(
    String sport, {
    String keyword = '',
    int? courtId,
  }) async {
    return await service.searchListings(
      sport,
      keyword: keyword,
      courtId: courtId,
    );
  }

  // ลงประกาศขายใหม่ (แบบเดียวกับ markAsRead ใน PostController)
  // ใช้ finally ให้ปิดวงโหลดเสมอ แม้ส่งไม่สำเร็จ หน้าจอจะได้ไม่ค้าง
  // คืนค่า id ของประกาศใหม่
  Future<String> createListing(NewListing listing) async {
    onSyncController.add(true);
    try {
      return await service.createListing(listing);
    } finally {
      onSyncController.add(false);
    }
  }

  // ปิดท่อส่งสถานะเมื่อเลิกใช้หน้าจอ
  void dispose() {
    onSyncController.close();
  }
}
