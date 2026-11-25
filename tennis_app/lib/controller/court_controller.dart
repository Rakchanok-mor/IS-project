import 'dart:async';

import 'package:tennis_app/models/court_model.dart';
import 'package:tennis_app/services/court_service.dart';

// ตัวกลางระหว่างหน้าจอกับที่เก็บข้อมูลสนาม (แบบเดียวกับ PostController ในงานวิชา)
// onSync จะบอกหน้าจอว่ากำลังโหลดอยู่ (true) หรือโหลดเสร็จแล้ว (false)
class CourtController {
  List<Court> courts = List.empty();
  final CourtService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  CourtController(this.service);

  // ใช้ finally ให้ปิดวงโหลดเสมอ แม้โหลดไม่สำเร็จ หน้าจอจะได้ไม่ค้าง
  Future<List<Court>> fetchCourts(String sport) async {
    onSyncController.add(true);
    try {
      courts = await service.getCourts(sport);
    } finally {
      onSyncController.add(false);
    }
    return courts;
  }

  // ปิดท่อส่งสถานะเมื่อเลิกใช้หน้าจอ
  void dispose() {
    onSyncController.close();
  }
}
