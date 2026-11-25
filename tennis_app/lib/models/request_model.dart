import 'package:tennis_app/models/listing_model.dart';

// สถานะของการตั้งรับ
const String kRequestWaiting = 'waiting';
const String kRequestMatched = 'matched';

// การตั้งรับสนาม 1 รายการ: ผู้ซื้อบอกว่าอยากได้สนามไหน วันไหน ช่วงเวลาไหน
// แล้วรอให้ระบบจับคู่กับประกาศของผู้ขายที่ตรงกัน
class CourtRequest {
  String sport;
  int courtId;
  String courtName;
  DateTime startTime;
  DateTime endTime;

  CourtRequest(
    this.sport,
    this.courtId,
    this.courtName,
    this.startTime,
    this.endTime,
  );

  // ข้อมูลที่ส่งไปเพิ่มแถวในตาราง requests (buyer_id กับ status ฐานข้อมูลใส่ให้เอง)
  Map<String, dynamic> toJson() {
    return {
      'sport': sport,
      'court_id': courtId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
    };
  }

  // วันเวลาที่แสดง เช่น "ส. 24 ก.ย. · 17:00–21:00"
  String get scheduleText {
    return '${thaiShortDate(startTime)} · '
        '${hourMinuteText(startTime)}–${hourMinuteText(endTime)}';
  }
}

// การตั้งรับของฉัน 1 รายการ (อ่านจากตาราง requests) พร้อมประกาศที่ตรงกัน
// ประกาศที่ตรงกันมาจาก view request_matches: สนาม + กีฬาเดียวกัน
// และเวลาของประกาศอยู่ในช่วงที่ผู้ซื้อเล่นได้
class MyRequest {
  String id;
  String sport;
  String courtName;
  DateTime startTime;
  DateTime endTime;
  String status;
  List<Listing> matches; // ประกาศที่ระบบจับคู่ให้ แตะเพื่อดู/ซื้อ

  MyRequest(
    this.id,
    this.sport,
    this.courtName,
    this.startTime,
    this.endTime,
    this.status,
    this.matches,
  );

  // แถวจากตาราง requests ที่ดึงชื่อสนามมาด้วย (select '*, courts(name)')
  // ประกาศที่ตรงกันใส่ทีหลังในชั้น service
  factory MyRequest.fromJson(Map<String, dynamic> json) {
    final court = json['courts'] as Map<String, dynamic>?;
    return MyRequest(
      json['id'].toString(),
      json['sport'] as String? ?? kSportTennis,
      court?['name'] as String? ?? '',
      DateTime.parse(json['start_time'] as String).toLocal(),
      DateTime.parse(json['end_time'] as String).toLocal(),
      json['status'] as String? ?? kRequestWaiting,
      List.empty(),
    );
  }

  bool get hasMatches => matches.isNotEmpty;

  String get scheduleText {
    return '${thaiShortDate(startTime)} · '
        '${hourMinuteText(startTime)}–${hourMinuteText(endTime)}';
  }
}

// รวมการตั้งรับหลายรายการ (แบบเดียวกับ AllListings)
class AllMyRequests {
  final List<MyRequest> requests;
  AllMyRequests(this.requests);

  factory AllMyRequests.fromJson(List<dynamic> json) {
    List<MyRequest> requests;
    requests = json
        .map((item) => MyRequest.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllMyRequests(requests);
  }
}

// ผู้ตั้งรับ 1 คนที่ตรงกับประกาศของเรา (ฝั่งผู้ขาย A5)
// เห็นชื่อผู้ซื้อแบบย่อ (เช่น "สมชาย ร.") + ช่วงเวลาที่อยากเล่น ไม่เห็นอีเมล
class ListingRequest {
  String requestId;
  DateTime startTime;
  DateTime endTime;
  String buyerName;

  ListingRequest(this.requestId, this.startTime, this.endTime, this.buyerName);

  // แถวจากฟังก์ชัน get_listing_requests ใน supabase/schema.sql
  factory ListingRequest.fromJson(Map<String, dynamic> json) {
    return ListingRequest(
      json['request_id'].toString(),
      DateTime.parse(json['start_time'] as String).toLocal(),
      DateTime.parse(json['end_time'] as String).toLocal(),
      json['buyer_name'] as String? ?? '',
    );
  }

  // ช่วงเวลาที่ผู้ซื้อเล่นได้ เช่น "อา. 8 พ.ย. · 17:00–21:00"
  String get scheduleText {
    return '${thaiShortDate(startTime)} · '
        '${hourMinuteText(startTime)}–${hourMinuteText(endTime)}';
  }
}

// รวมผู้ตั้งรับหลายคน
class AllListingRequests {
  final List<ListingRequest> requests;
  AllListingRequests(this.requests);

  factory AllListingRequests.fromJson(List<dynamic> json) {
    List<ListingRequest> requests;
    requests = json
        .map((item) => ListingRequest.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllListingRequests(requests);
  }
}
