import 'dart:async';

import 'package:tennis_app/models/notification_model.dart';
import 'package:tennis_app/services/notification_service.dart';

// ตัวกลางระหว่างหน้าจอกับแจ้งเตือน (แบบเดียวกับ PostController + บท Async Dart)
// - รับ Stream จาก service แล้วส่งต่อผ่าน StreamController แบบ broadcast
//   เพราะมีผู้ฟังหลายที่พร้อมกัน: ตัวเลขบนกระดิ่ง (เมนูล่าง) และหน้าแจ้งเตือน
// - onUnreadCount = stream ที่แปลงจาก stream หลักด้วย map (นับเฉพาะที่ยังไม่อ่าน)
class NotificationController {
  List<AppNotification> notifications = List.empty();
  final NotificationService service;

  // sink ของรายการแจ้งเตือน (broadcast = ฟังได้หลายที่)
  final StreamController<List<AppNotification>> _notificationsController =
      StreamController.broadcast();
  Stream<List<AppNotification>> get onNotifications =>
      _notificationsController.stream;

  Stream<int> get onUnreadCount => onNotifications.map(_countUnread);
  int get unreadCount => _countUnread(notifications);

  StreamSubscription<List<AppNotification>>? _serviceSubscription;

  NotificationController(this.service);

  // เริ่มฟังแจ้งเตือนจากฐานข้อมูล (เรียกครั้งเดียวตอนเปิดหน้าหลัก)
  void start() {
    _serviceSubscription = service.watchMyNotifications().listen(
      (List<AppNotification> items) {
        // เรียงเองทุกครั้ง: ใหม่สุดอยู่บน เก่าสุดอยู่ล่าง
        // (แจ้งเตือนใหม่ที่เข้ามาแบบ Realtime อาจไม่ได้อยู่ในลำดับที่ถูก)
        notifications = List.of(items)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _notificationsController.add(notifications);
      },
      onError: (Object error) {
        _notificationsController.addError(error);
      },
    );
  }

  // กดอ่านแล้ว: เปลี่ยนในเครื่องทันที (หน้าจอไม่ต้องรอ) แล้วค่อยบันทึก
  Future<void> markRead(AppNotification notification) async {
    if (!notification.isUnread) return;
    notification.readAt = DateTime.now();
    _notificationsController.add(notifications);
    await service.markRead(notification);
  }

  // อ่านทั้งหมด: เปลี่ยนในเครื่องทันที แล้วค่อยบันทึก
  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    final now = DateTime.now();
    for (final item in notifications) {
      if (item.isUnread) item.readAt = now;
    }
    _notificationsController.add(notifications);
    await service.markAllRead();
  }

  int _countUnread(List<AppNotification> items) {
    return items.where((item) => item.isUnread).length;
  }

  void dispose() {
    _serviceSubscription?.cancel();
    _notificationsController.close();
  }
}
