// ชื่อกีฬาที่ใช้เก็บในฐานข้อมูล (ใช้ค่าเดียวกันทุกที่ จะได้ไม่พิมพ์ผิด)
const String kSportTennis = 'tennis';
const String kSportBadminton = 'badminton';

// แปลงชื่อกีฬาเป็นคำที่แสดงในแอป
String sportLabel(String sport) {
  if (sport == kSportBadminton) {
    return 'แบดมินตัน';
  }
  return 'เทนนิส';
}

// สถานะของประกาศ
const String kStatusOpen = 'open';
const String kStatusInterested = 'interested';
const String kStatusReserved =
    'reserved'; // มีผู้ซื้อกดซื้อแล้ว ล็อกไว้รอชำระเงิน
const String kStatusSold = 'sold';
const String kStatusExpired =
    'expired'; // ถึงเวลาเล่นแล้วไม่มีคนซื้อ (pg_cron เปลี่ยนให้ทุก 10 นาที)

const List<String> _thaiWeekdays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
const List<String> _thaiMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

// วันที่แบบย่อ เช่น "ส. 7 พ.ย." หรือ "ส. 7 พ.ย. 2569" ถ้าขอปี (พ.ศ.) ด้วย
String thaiShortDate(DateTime date, {bool withYear = false}) {
  final text =
      '${_thaiWeekdays[date.weekday - 1]} ${date.day} ${_thaiMonths[date.month - 1]}';
  if (!withYear) {
    return text;
  }
  return '$text ${date.year + 543}';
}

// เดือนกับปี พ.ศ. เช่น "พ.ย. 2569" (ใช้ในรายงานรายเดือน)
String thaiMonthYear(DateTime date) {
  return '${_thaiMonths[date.month - 1]} ${date.year + 543}';
}

// เวลาแบบ 24 ชั่วโมง เช่น "07:00"
String hourMinuteText(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

// ประกาศปล่อยคอร์ท 1 รายการ
class Listing {
  String id;
  String courtName; // ชื่อสนาม (จากตาราง courts)
  String sport;
  DateTime startTime;
  DateTime endTime;
  int price;
  double? distanceKm;
  String status;

  // ข้อมูลเพิ่มเติมสำหรับหน้ารายละเอียดประกาศ (ไม่ใส่ก็ได้)
  String details; // รายละเอียดที่ผู้ขายกรอกตอนลงประกาศ
  int? originalPrice; // ราคาที่ผู้ขายจองมา
  String sellerName;

  // ใช้ตอนค้นหา: id สนาม (กรองจากแผนที่) + ชื่อสนามภาษาอังกฤษ
  String courtId;
  String courtNameEn;

  // ใช้เช็กว่าเป็นประกาศของเราเองไหม (ฝั่งซื้อจะติดป้าย + ซ่อนปุ่มซื้อ)
  String sellerId;

  // ที่อยู่รูปหลักฐานการจองที่ผู้ขายแนบ (ประกาศเก่าบางอันอาจไม่มี = null)
  String? proofPath;

  Listing(
    this.id,
    this.courtName,
    this.sport,
    this.startTime,
    this.endTime,
    this.price,
    this.distanceKm,
    this.status, {
    this.details = '',
    this.originalPrice,
    this.sellerName = '',
    this.courtId = '',
    this.courtNameEn = '',
    this.sellerId = '',
    this.proofPath,
  });

  // แปลงข้อมูล 1 แถวจากตาราง listings ใน Supabase เป็น Listing
  // ชื่อสนามมาจากตาราง courts ที่ดึงมาพร้อมกัน (select '*, courts(name, name_en)')
  factory Listing.fromJson(Map<String, dynamic> json) {
    final court = json['courts'] as Map<String, dynamic>?;
    return Listing(
      json['id'].toString(),
      court?['name'] as String? ?? '',
      json['sport'] as String? ?? kSportTennis,
      DateTime.parse(json['start_time'] as String).toLocal(),
      DateTime.parse(json['end_time'] as String).toLocal(),
      (json['price'] as num?)?.toInt() ?? 0,
      (json['distance_km'] as num?)?.toDouble(),
      json['status'] as String? ?? kStatusOpen,
      details: json['details'] as String? ?? '',
      originalPrice: (json['original_price'] as num?)?.toInt(),
      sellerName: json['seller_name'] as String? ?? '',
      courtId: json['court_id']?.toString() ?? '',
      courtNameEn: court?['name_en'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      proofPath: json['proof_path'] as String?,
    );
  }

  bool get hasProof => proofPath != null && proofPath!.isNotEmpty;

  // เป็นประกาศของผู้ใช้คนนี้ไหม (หน้าจอส่ง id คนที่ล็อกอินอยู่มาจาก AuthController
  // model ไม่คุยกับ Supabase เอง)
  bool isOwnedBy(String? userId) {
    return userId != null && userId == sellerId;
  }

  // ใช้ตอนค้นหา: พิมพ์ส่วนไหนของชื่อสนาม (ไทยหรืออังกฤษ) ก็เจอ
  // ไม่สนตัวพิมพ์เล็ก-ใหญ่ (แบบเดียวกับ Court.matches)
  bool matches(String keyword) {
    final key = keyword.trim().toLowerCase();
    return courtName.toLowerCase().contains(key) ||
        courtNameEn.toLowerCase().contains(key);
  }

  // ซื้อได้ไหม: ยังไม่มีคนล็อก/ซื้อ และยังไม่ถึงเวลาเล่น
  bool get isAvailable {
    return (status == kStatusOpen || status == kStatusInterested) &&
        startTime.isAfter(DateTime.now());
  }

  // ระยะเวลาเล่น เช่น "2 ชั่วโมง" หรือ "1 ชั่วโมง 30 นาที"
  String get durationText {
    final minutes = endTime.difference(startTime).inMinutes;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest นาที';
    if (rest == 0) return '$hours ชั่วโมง';
    return '$hours ชั่วโมง $rest นาที';
  }

  // ชื่อที่แสดงบนการ์ด เช่น "Lumpini Tennis Club"
  String get title => courtName;

  // วันเวลาที่แสดงบนการ์ด เช่น "ส. 7 พ.ย. · 18:00–20:00" หรือ "วันนี้ · 20:00–22:00"
  String get scheduleText {
    final now = DateTime.now();
    final isToday =
        startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;

    final day = isToday ? 'วันนี้' : thaiShortDate(startTime);

    return '$day · ${hourMinuteText(startTime)}–${hourMinuteText(endTime)}';
  }
}

// รวมประกาศหลายรายการ (แบบเดียวกับ AllPosts ในงานวิชา)
class AllListings {
  final List<Listing> listings;
  AllListings(this.listings);

  factory AllListings.fromJson(List<dynamic> json) {
    List<Listing> listings;
    listings = json
        .map((item) => Listing.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllListings(listings);
  }
}
