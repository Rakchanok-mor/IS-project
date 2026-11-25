import 'package:supabase_flutter/supabase_flutter.dart';

// สัญญาว่าระบบล็อกอินต้องทำอะไรได้บ้าง (lecture 13 ใช้ FirebaseAuth ในโปรเจคใช้ Supabase Auth)
// หน้าจอเรียกผ่าน AuthController เท่านั้น ไม่เรียก Supabase.instance.client.auth เอง
abstract class AuthService {
  // แจ้งทุกครั้งที่สถานะล็อกอินเปลี่ยน (AuthGate ฟังอันนี้)
  Stream<AuthState> get onAuthStateChange;

  Session? get currentSession;

  String? get currentUserId;

  String get currentEmail;

  Future<void> signIn(String email, String password);

  Future<String?> signUp(
    String email,
    String password,
    Map<String, dynamic> data,
  );

  Future<void> signOut();
}

class AuthSupabaseService implements AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  @override
  Session? get currentSession => _auth.currentSession;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String get currentEmail => _auth.currentUser?.email ?? '';

  // ผิดพลาด → โยน AuthException ต่อให้หน้าจอแปลงเป็นข้อความ
  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  // data = ข้อมูลโปรไฟล์ที่เก็บใน user metadata, คืน id ของผู้ใช้ใหม่
  @override
  Future<String?> signUp(
    String email,
    String password,
    Map<String, dynamic> data,
  ) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: data,
    );
    return response.user?.id;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
