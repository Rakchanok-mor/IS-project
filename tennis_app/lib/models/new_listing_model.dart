import 'dart:typed_data';

import 'package:tennis_app/models/listing_model.dart';

// ประกาศขายที่ผู้ขายกำลังกรอก (ยังไม่ได้บันทึกลงฐานข้อมูล)
// แบบเดียวกับ CourtRequest: เก็บค่าจากฟอร์ม แล้วแปลงเป็น json ตอนส่ง
class NewListing {
  String sport;
  int courtId;
  String courtName;
  // รายละเอียดที่ผู้ขายกรอกเอง เช่น หมายเลขคอร์ท พื้นคอร์ท ในร่ม/กลางแจ้ง
  String details;
  DateTime startTime;
  DateTime endTime;
  int bookedPrice;
  int price;
  Uint8List? proofBytes;
  String proofFileName;
  // ราคาที่ระบบอ่านได้จากรูปหลักฐาน (ราคาที่จองมาต้องไม่เกินค่านี้)
  int? scannedPrice;

  NewListing(
    this.sport,
    this.courtId,
    this.courtName,
    this.details,
    this.startTime,
    this.endTime,
    this.bookedPrice,
    this.price,
    this.proofBytes,
    this.proofFileName, {
    this.scannedPrice,
  });

  // ข้อมูลที่ส่งไปเพิ่มแถวในตาราง listings
  // (seller_id กับ proof_path ใส่เพิ่มใน service, status ฐานข้อมูลใส่ให้เอง)
  Map<String, dynamic> toJson() {
    return {
      'sport': sport,
      'court_id': courtId,
      'details': details,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'price': price,
      'original_price': bookedPrice,
      'scanned_price': scannedPrice,
    };
  }

  // วันเวลาที่แสดง เช่น "ส. 24 ก.ย. · 18:00–20:00"
  String get scheduleText {
    return '${thaiShortDate(startTime)} · '
        '${hourMinuteText(startTime)}–${hourMinuteText(endTime)}';
  }

  // เวลาที่ประกาศจะถูกลบอัตโนมัติ (ตอนเริ่มเล่น) เช่น "ส. 24 ก.ย. 18:00"
  String get expireText {
    return '${thaiShortDate(startTime)} ${hourMinuteText(startTime)}';
  }
}
