import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/profile_model.dart';

// สัญญาว่าที่เก็บโปรไฟล์ผู้ใช้ต้องทำอะไรได้บ้าง
abstract class ProfileService {
  Profile getMyProfile();

  Future<void> saveMyProfile(Profile profile);
}

// เก็บใน user metadata ของ Supabase Auth (ไม่ต้องมีตารางเพิ่ม)
class ProfileSupabaseService implements ProfileService {
  @override
  Profile getMyProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    // email ไม่ได้อยู่ใน metadata ใส่รวมไปใน Map เดียวกันให้ model แปลง
    final Map<String, dynamic> data = {
      ...?user?.userMetadata,
      'email': user?.email ?? '',
    };
    return Profile.fromJson(data);
  }

  // updateUser เขียนทับเฉพาะ key ที่ส่งไป key อื่นใน metadata ยังอยู่
  @override
  Future<void> saveMyProfile(Profile profile) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: profile.toJson()),
    );
  }
}
