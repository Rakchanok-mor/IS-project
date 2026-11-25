// ข้อมูลโปรไฟล์ของผู้ใช้ เก็บใน user metadata ของ Supabase Auth
// (กรอกตอนสมัคร หรือแก้ทีหลังที่หน้าแก้ไขโปรไฟล์)
class Profile {
  String email;
  String firstName;
  String lastName;
  String phone;

  Profile(this.email, this.firstName, this.lastName, this.phone);

  // json = metadata ของผู้ใช้ + email (service รวมมาให้)
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      json['email'] as String? ?? '',
      json['first_name'] as String? ?? '',
      json['last_name'] as String? ?? '',
      json['phone'] as String? ?? '',
    );
  }

  // ข้อมูลที่บันทึกลง metadata
  // name = ชื่อเต็ม ใช้เป็นชื่อผู้ซื้อในคำสั่งซื้อ (create_order ใน supabase/schema.sql)
  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'name': fullName,
      'phone': phone,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  // บัญชีเก่าที่สมัครก่อนมีช่องชื่อ/เบอร์ ยังไม่ได้กรอก
  bool get isComplete => firstName.isNotEmpty && phone.isNotEmpty;

  // เบอร์แบบอ่านง่าย เช่น "081-234-5678"
  String get phoneText {
    if (phone.length != 10) return phone;
    return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
  }
}
