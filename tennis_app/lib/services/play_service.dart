import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/payout_account_model.dart';

// ให้ฐานข้อมูลเช็กตัวจับเวลาของ Workflow ใช้สนาม (supabase/schema.sql)
// - ผู้ซื้อไม่ยืนยันภายใน 24 ชม. หลังเล่นจบ → ระบบยืนยันให้
// - ผู้ขายไม่ส่งหลักฐานภายใน 24 ชม. → คืนเงินผู้ซื้อ
// เรียกก่อนโหลดรายการทุกครั้ง (แบบเดียวกับ release_expired_orders ตอนกดซื้อ)
Future<void> runPlayDeadlines() async {
  await Supabase.instance.client.rpc('process_play_deadlines');
}

// ตั้งชื่อไฟล์ใหม่จากเวลา เก็บในโฟลเดอร์ของผู้ใช้เอง (ตามสิทธิ์ใน Storage)
String _uploadPath(String prefix, String orderId, String fileName) {
  final userId = Supabase.instance.client.auth.currentUser!.id;
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1
      ? 'jpg'
      : fileName.substring(dot + 1).toLowerCase();
  return '$userId/${prefix}_${orderId}_'
      '${DateTime.now().millisecondsSinceEpoch}.$extension';
}

// สัญญาว่าที่เก็บข้อมูล Workflow ใช้สนามต้องทำอะไรได้บ้าง
abstract class PlayService {
  // ---------- ฝั่งผู้ซื้อ ----------

  // ยืนยันว่าได้เล่นแล้ว (B9 → B10) → รอแอดมินโอนให้ผู้ขาย
  Future<void> confirmPlay(Order order);

  // แจ้งปัญหา (B17 → B18) เขียนรายละเอียด + รูป (ไม่แนบก็ได้) → เงินถูก Hold รอผู้ขายชี้แจง
  Future<void> reportProblem(
    Order order,
    String reason,
    Uint8List? photoBytes,
    String photoName,
  );

  // ---------- ฝั่งแอดมิน ----------

  // ข้อพิพาททั้งหมด (ยังเปิดอยู่ + ที่ตัดสินแล้ว) ใหม่สุดก่อน (U6)
  Future<List<PaymentItem>> getDisputes();

  // ลิงก์ดูรูป (ไฟล์ไม่เปิดสาธารณะ ต้องขอลิงก์ชั่วคราว) ไม่มีรูป = null
  Future<String?> getFileUrl(String? path);

  // ตัดสินข้อพิพาท (U7): favorBuyer = คืนเงินผู้ซื้อ, ไม่งั้น = โอนให้ผู้ขาย
  Future<void> resolveDispute(Order order, bool favorBuyer, String note);

  // แบนผู้ซื้อ (banBuyer = true) หรือผู้ขายของคำสั่งซื้อนี้ (schema.sql หัวข้อ 23)
  Future<void> banOrderParty(Order order, bool banBuyer, String reason);

  // บัญชีรับเงินของผู้ขายในออเดอร์นี้ ผู้ขายยังไม่กรอก = null
  Future<PayoutAccount?> getSellerPayoutAccount(Order order);
}

// ---------------------------------------------------------------
// ตัวจริง: เรียกฟังก์ชันใน Supabase การเปลี่ยนสถานะทำที่ฐานข้อมูลทั้งหมด
// ---------------------------------------------------------------
class PlaySupabaseService implements PlayService {
  static const String _columns = '*, listings(*, courts(name))';
  static const String _bucket = 'booking-proofs';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> confirmPlay(Order order) async {
    await _client.rpc(
      'confirm_play',
      params: {'p_order_id': int.parse(order.id)},
    );
  }

  @override
  Future<void> reportProblem(
    Order order,
    String reason,
    Uint8List? photoBytes,
    String photoName,
  ) async {
    String? path;
    if (photoBytes != null) {
      path = _uploadPath('problem', order.id, photoName);
      await _client.storage.from(_bucket).uploadBinary(path, photoBytes);
    }

    await _client.rpc(
      'report_problem',
      params: {
        'p_order_id': int.parse(order.id),
        'p_category': null, // ไม่มีหัวข้อแล้ว แจ้งแค่รายละเอียด
        'p_reason': reason,
        'p_photo_path': path,
      },
    );
  }

  @override
  Future<List<PaymentItem>> getDisputes() async {
    await runPlayDeadlines();
    final data = await _client
        .from('orders')
        .select(_columns)
        .not('disputed_at', 'is', null)
        .order('disputed_at', ascending: false);

    AllPaymentItems all = AllPaymentItems.fromJson(data);
    return all.items;
  }

  @override
  Future<String?> getFileUrl(String? path) async {
    if (path == null) return null;
    return _client.storage.from(_bucket).createSignedUrl(path, 60 * 10);
  }

  @override
  Future<void> resolveDispute(Order order, bool favorBuyer, String note) async {
    await _client.rpc(
      'resolve_dispute',
      params: {
        'p_order_id': int.parse(order.id),
        'p_favor_buyer': favorBuyer,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> banOrderParty(Order order, bool banBuyer, String reason) async {
    await _client.rpc(
      'ban_order_party',
      params: {
        'p_order_id': int.parse(order.id),
        'p_party': banBuyer ? 'buyer' : 'seller',
        'p_reason': reason,
      },
    );
  }

  @override
  Future<PayoutAccount?> getSellerPayoutAccount(Order order) async {
    final data = await _client.rpc(
      'get_seller_payout_account',
      params: {'p_order_id': int.parse(order.id)},
    );
    final rows = data as List<dynamic>;
    if (rows.isEmpty) return null;
    return PayoutAccount.fromJson(rows.first as Map<String, dynamic>);
  }
}
