import 'package:tennis_app/models/order_model.dart';

// ฝั่งของแจ้งเตือน (แจ้งในฐานะผู้ซื้อหรือผู้ขาย)
const String kSideBuyer = 'buyer';
const String kSideSeller = 'seller';

// ประเภทแจ้งเตือนที่เร่งด่วน (การ์ดเป็นสีแดง)
const String kNoticeDisputeOpened = 'dispute_opened';

// แจ้งเตือน 1 รายการ (ตาราง notifications ใน supabase/schema.sql หัวข้อ 10)
// ตั้งชื่อ AppNotification เพราะ Flutter มีคลาส Notification อยู่แล้ว
class AppNotification {
  String id;
  String side;
  String type;
  String title;
  String body;
  String? orderId;
  String? listingId;
  String? requestId;
  DateTime? readAt;
  DateTime createdAt;
  String?
  sport; // กีฬาของประกาศ/การตั้งรับที่แจ้งเตือนนี้พูดถึง (ไม่มี = ไม่แสดงป้าย)

  AppNotification(
    this.id,
    this.side,
    this.type,
    this.title,
    this.body,
    this.orderId,
    this.listingId,
    this.requestId,
    this.readAt,
    this.createdAt,
    this.sport,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final readAt = json['read_at'] as String?;
    return AppNotification(
      json['id'].toString(),
      json['side'] as String? ?? kSideBuyer,
      json['type'] as String? ?? '',
      json['title'] as String? ?? '',
      json['body'] as String? ?? '',
      json['order_id']?.toString(),
      json['listing_id']?.toString(),
      json['request_id']?.toString(),
      readAt == null ? null : DateTime.parse(readAt).toLocal(),
      DateTime.parse(json['created_at'] as String).toLocal(),
      json['sport'] as String?,
    );
  }

  bool get isUnread => readAt == null;
  bool get isBuyer => side == kSideBuyer;
  bool get isUrgent => type == kNoticeDisputeOpened;

  // วันที่พร้อมเวลาที่แจ้งเตือน เช่น "ส. 26 ก.ค. 2568 16:05"
  String get createdAtText => thaiDateTime(createdAt);
}

// รวมแจ้งเตือนหลายรายการ (แบบเดียวกับ AllListings)
class AllNotifications {
  final List<AppNotification> notifications;
  AllNotifications(this.notifications);

  factory AllNotifications.fromJson(List<dynamic> json) {
    List<AppNotification> notifications;
    notifications = json
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
    return AllNotifications(notifications);
  }
}
