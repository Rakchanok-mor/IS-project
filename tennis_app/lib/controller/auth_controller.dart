import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/services/auth_service.dart';

// ตัวกลางระหว่างหน้าจอกับระบบล็อกอิน (แบบเดียวกับ PostController)
// onSync บอกหน้าจอว่ากำลังล็อกอิน/สมัครอยู่ (true) หรือเสร็จแล้ว (false)
class AuthController {
  final AuthService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  AuthController(this.service);

  Stream<AuthState> get onAuthStateChange => service.onAuthStateChange;
  Session? get currentSession => service.currentSession;
  String? get currentUserId => service.currentUserId;
  String get currentEmail => service.currentEmail;

  Future<void> signIn(String email, String password) async {
    onSyncController.add(true);
    try {
      await service.signIn(email, password);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<String?> signUp(
    String email,
    String password,
    Map<String, dynamic> data,
  ) async {
    onSyncController.add(true);
    try {
      return await service.signUp(email, password, data);
    } finally {
      onSyncController.add(false);
    }
  }

  Future<void> signOut() async {
    await service.signOut();
  }

  void dispose() {
    onSyncController.close();
  }
}
