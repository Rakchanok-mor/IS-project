import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/transfer_model.dart';
import 'package:tennis_app/services/play_service.dart';

// แปลง error จากฟังก์ชันในฐานข้อมูล (supabase/schema.sql) เป็นข้อความภาษาไทย
// ใช้ในหน้าจอตอน catch แล้วเอาไปแสดงใน SnackBar
String paymentErrorText(Object error) {
  final text = error.toString();
  if (text.contains('listing_not_available')) {
    return 'ประกาศนี้มีคนกำลังซื้ออยู่ หรือหมดเวลาขายแล้ว';
  }
  if (text.contains('own_listing')) {
    return 'ซื้อประกาศของตัวเองไม่ได้';
  }
  if (text.contains('order_expired')) {
    return 'หมดเวลาชำระเงินแล้ว';
  }
  if (text.contains('not_admin')) {
    return 'ต้องเป็นแอดมินเท่านั้น';
  }
  if (text.contains('not_played_yet')) {
    return 'ยังไม่ถึงเวลาเล่น';
  }
  if (text.contains('report_window_closed')) {
    return 'เลยเวลาแจ้งปัญหาแล้ว (ภายใน $kConfirmHours ชม. หลังเล่นจบ)';
  }
  if (text.contains('evidence_window_closed')) {
    return 'เลยเวลาส่งหลักฐานแล้ว (ภายใน $kEvidenceHours ชม.)';
  }
  if (text.contains('account_banned')) {
    return 'บัญชีของคุณถูกระงับ ทำรายการไม่ได้';
  }
  if (text.contains('cannot_ban_admin')) {
    return 'แบนบัญชีแอดมินไม่ได้';
  }
  if (text.contains('no_payout_account')) {
    return 'ผู้ขายยังไม่ได้กรอกบัญชีรับเงิน';
  }
  if (text.contains('gateway_failed')) {
    return 'ติดต่อระบบรับชำระเงินไม่ได้ ลองใหม่อีกครั้ง';
  }
  if (text.contains('order_not_')) {
    return 'สถานะคำสั่งซื้อเปลี่ยนไปแล้ว ลองโหลดใหม่';
  }
  return 'ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง';
}

// สัญญาว่าที่เก็บข้อมูลการชำระเงินต้องทำอะไรได้บ้าง (ตาม Workflow การชำระเงิน)
abstract class PaymentService {
  // ---------- ฝั่งผู้ซื้อ ----------

  // กดซื้อ: ล็อกประกาศไว้ 15 นาที แล้วสร้างคำสั่งซื้อ + เลขที่คำสั่งซื้อ
  Future<Order> createOrder(Listing listing);

  // ขอ QR รับเงินจาก Payment Gateway (supabase/functions/charges)
  // เงินเข้าแล้ว gateway แจ้งฐานข้อมูลเอง → สถานะ held
  Future<Order> createCharge(Order order);

  // ยกเลิกก่อนชำระ → ปลดล็อกประกาศ
  Future<void> cancelOrder(Order order);

  // หมดเวลาแล้วยังไม่ได้ชำระ → ปลดล็อกประกาศ
  Future<void> expireOrder(Order order);

  Future<PaymentItem> getOrder(String orderId);

  // คำสั่งซื้อทั้งหมดของเรา ใหม่สุดก่อน
  Future<List<PaymentItem>> getMyPurchases();

  // ลิงก์ดูหลักฐานการจองของผู้ขาย (ผู้ซื้อดูได้หลังชำระเงินสำเร็จ) ไม่มีรูป = null
  Future<String?> getProofUrl(Listing listing);

  // ชื่อ-นามสกุลเต็มของผู้ขาย (เฉพาะผู้ซื้อของคำสั่งซื้อนี้) ไม่มี = null
  Future<String?> getSellerFullName(Order order);

  // เหตุผลที่บัญชีเราถูกแบน (ไม่ถูกแบน = null)
  Future<String?> getMyBanReason();

  // ---------- ฝั่งแอดมิน ----------

  Future<bool> isAdmin();

  // หน้าการเงินของแอดมิน: รายการที่ต้องจัดการ (โอนผู้ขายไม่สำเร็จ / รอคืนเงิน)
  // + ประวัติ (ชำระแล้ว / โอนผู้ขายแล้ว / คืนเงินแล้ว)
  Future<List<PaymentItem>> getAdminQueue();

  // ---------- โอนเงินผ่าน Payment Gateway (supabase/functions/transfers) ----------

  // สั่งโอน: kTransferRefund (แอดมิน) / kTransferPayout (แอดมิน หรือผู้ซื้อหลังกดได้เล่นแล้ว)
  Future<Transfer> requestTransfer(Order order, String kind);

  // รายการโอนล่าสุดของคำสั่งซื้อนี้ (ยังไม่เคยโอน = null)
  Future<Transfer?> getLatestTransfer(Order order, String kind);

  Future<Transfer> getTransfer(String transferId);
}

// ---------------------------------------------------------------
// ตัวจริง: เรียกฟังก์ชันใน Supabase (สร้างด้วย supabase/schema.sql)
// การเปลี่ยนสถานะทำที่ฐานข้อมูลทั้งหมด แอปแก้สถานะเองไม่ได้ จึงปลอดภัย
// ---------------------------------------------------------------
class PaymentSupabaseService implements PaymentService {
  static const String _columns = '*, listings(*, courts(name))';
  static const String _bucket = 'booking-proofs';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Order> createOrder(Listing listing) async {
    final data = await _client.rpc(
      'create_order',
      params: {'p_listing_id': int.parse(listing.id)},
    );
    return Order.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Order> createCharge(Order order) async {
    final response = await _client.functions.invoke(
      'charges',
      body: {'order_id': int.parse(order.id)},
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['order'] is Map<String, dynamic>) {
      return Order.fromJson(data['order'] as Map<String, dynamic>);
    }
    throw Exception('gateway_failed');
  }

  @override
  Future<void> cancelOrder(Order order) async {
    await _client.rpc(
      'cancel_order',
      params: {'p_order_id': int.parse(order.id)},
    );
  }

  @override
  Future<void> expireOrder(Order order) async {
    // ฐานข้อมูลเช็กเวลาเอง ปลดล็อกเฉพาะออเดอร์ที่หมดเวลาจริง
    await _client.rpc('release_expired_orders');
  }

  @override
  Future<PaymentItem> getOrder(String orderId) async {
    final data = await _client
        .from('orders')
        .select(_columns)
        .eq('id', orderId)
        .single();
    return PaymentItem.fromJson(data);
  }

  @override
  Future<List<PaymentItem>> getMyPurchases() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return List.empty();
    }
    await runPlayDeadlines();
    final data = await _client
        .from('orders')
        .select(_columns)
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);

    AllPaymentItems all = AllPaymentItems.fromJson(data);
    return all.items;
  }

  @override
  Future<String?> getProofUrl(Listing listing) async {
    final path = listing.proofPath;
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(_bucket).createSignedUrl(path, 60 * 60);
  }

  @override
  Future<String?> getSellerFullName(Order order) async {
    final result = await _client.rpc(
      'get_order_seller_name',
      params: {'p_order_id': int.parse(order.id)},
    );
    if (result is String && result.trim().isNotEmpty) return result.trim();
    return null;
  }

  @override
  Future<String?> getMyBanReason() async {
    final result = await _client.rpc('get_my_ban_reason');
    if (result is String && result.trim().isNotEmpty) return result.trim();
    return null;
  }

  @override
  Future<bool> isAdmin() async {
    if (_client.auth.currentUser == null) return false;
    final result = await _client.rpc('is_admin');
    return result == true;
  }

  @override
  Future<List<PaymentItem>> getAdminQueue() async {
    await runPlayDeadlines();
    final data = await _client
        .from('orders')
        .select(_columns)
        .inFilter('status', [
          kOrderConfirmed,
          kOrderRejected,
          // ประวัติ
          kOrderHeld,
          kOrderReleased,
          kOrderRefunded,
        ])
        .order('created_at');

    AllPaymentItems all = AllPaymentItems.fromJson(data);
    return all.items;
  }

  @override
  Future<Transfer> requestTransfer(Order order, String kind) async {
    final response = await _client.functions.invoke(
      'transfers',
      body: {'order_id': int.parse(order.id), 'kind': kind},
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['transfer'] is Map<String, dynamic>) {
      return Transfer.fromJson(data['transfer'] as Map<String, dynamic>);
    }
    throw Exception('transfer_failed');
  }

  @override
  Future<Transfer?> getLatestTransfer(Order order, String kind) async {
    final data = await _client
        .from('payment_transfers')
        .select()
        .eq('order_id', order.id)
        .eq('kind', kind)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data == null ? null : Transfer.fromJson(data);
  }

  @override
  Future<Transfer> getTransfer(String transferId) async {
    final data = await _client
        .from('payment_transfers')
        .select()
        .eq('id', transferId)
        .single();
    return Transfer.fromJson(data);
  }
}
