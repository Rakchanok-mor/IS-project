// สนาม 1 แห่ง จากตาราง courts ใน Supabase
class Court {
  int id;
  String name;
  List<String> sports;
  double latitude;
  double longitude;
  String nameEn;

  Court(
    this.id,
    this.name,
    this.sports,
    this.latitude,
    this.longitude, {
    this.nameEn = '',
  });

  factory Court.fromJson(Map<String, dynamic> json) {
    return Court(
      (json['id'] as num).toInt(),
      json['name'] as String? ?? '',
      (json['sports'] as List<dynamic>? ?? []).cast<String>(),
      (json['latitude'] as num?)?.toDouble() ?? 0.0,
      (json['longitude'] as num?)?.toDouble() ?? 0.0,
      nameEn: json['name_en'] as String? ?? '',
    );
  }

  // ใช้ตอนค้นหา: พิมพ์ส่วนไหนของชื่อไทยหรืออังกฤษก็เจอ ไม่สนตัวพิมพ์เล็ก-ใหญ่
  bool matches(String keyword) {
    final key = keyword.trim().toLowerCase();
    return name.toLowerCase().contains(key) ||
        nameEn.toLowerCase().contains(key);
  }
}

// รวมสนามหลายแห่ง (แบบเดียวกับ AllListings)
class AllCourts {
  final List<Court> courts;
  AllCourts(this.courts);

  factory AllCourts.fromJson(List<dynamic> json) {
    List<Court> courts;
    courts = json
        .map((item) => Court.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllCourts(courts);
  }
}
