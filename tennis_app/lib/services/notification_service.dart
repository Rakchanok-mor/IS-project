import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/notification_model.dart';

// สัญญาว่าที่เก็บแจ้งเตือนต้องทำอะไรได้บ้าง
abstract class NotificationService {
  // แจ้งเตือนของเรา ใหม่สุดก่อน ส่งมาใหม่ทุกครั้งที่มีการเปลี่ยนแปลง (Stream)
  Stream<List<AppNotification>> watchMyNotifications();

  Future<void> markRead(AppNotification notification);

  // อ่านทั้งหมด (ทุกรายการของเราที่ยังไม่อ่าน)
  Future<void> markAllRead();
}

// ฟังตาราง notifications แบบ Realtime ของ Supabase
// แจ้งเตือนถูกสร้างด้วย trigger ในฐานข้อมูล (supabase/schema.sql หัวข้อ 10)
class NotificationSupabaseService implements NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<List<AppNotification>> watchMyNotifications() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(List.empty());
    }

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        // ใหม่สุดก่อน แล้วเอา 50 รายการล่าสุด
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => AllNotifications.fromJson(rows).notifications);
  }

  // RLS ใน schema.sql (หัวข้อ 8) ให้แก้ได้เฉพาะแจ้งเตือนของตัวเอง และแก้ได้แค่ read_at
  @override
  Future<void> markRead(AppNotification notification) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', int.parse(notification.id))
        .isFilter('read_at', null);
  }

  @override
  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }
}
