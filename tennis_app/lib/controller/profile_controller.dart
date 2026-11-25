import 'dart:async';

import 'package:tennis_app/models/profile_model.dart';
import 'package:tennis_app/services/profile_service.dart';

// ตัวกลางระหว่างหน้าโปรไฟล์กับที่เก็บข้อมูล (แบบเดียวกับ PostController)
// onSync บอกหน้าจอว่ากำลังบันทึกอยู่ (true) หรือเสร็จแล้ว (false)
class ProfileController {
  final ProfileService service;
  late Profile profile;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  ProfileController(this.service) {
    profile = service.getMyProfile();
  }

  // อ่านใหม่ (เช่น กลับมาจากหน้าแก้ไข)
  Profile reload() {
    profile = service.getMyProfile();
    return profile;
  }

  Future<void> saveMyProfile(Profile newProfile) async {
    onSyncController.add(true);
    try {
      await service.saveMyProfile(newProfile);
      profile = newProfile;
    } finally {
      onSyncController.add(false);
    }
  }

  void dispose() {
    onSyncController.close();
  }
}
