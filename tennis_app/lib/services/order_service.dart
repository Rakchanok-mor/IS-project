import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/services/play_service.dart';

// สัญญาว่าที่เก็บข้อมูลออเดอร์ฝั่งผู้ขายต้องทำอะไรได้บ้าง
abstract class OrderService {
  // ประกาศทั้งหมดของเรา พร้อมออเดอร์ (ถ้ามีคนซื้อแล้ว) ใหม่สุดก่อน
  Future<List<SellerListing>> getMySellerListings();

  // ส่งคำชี้แจง + รูปหลักฐานโต้แย้งเมื่อผู้ซื้อแจ้งปัญหา (A13)
  // ต้องส่งภายใน 24 ชม. คืนค่าที่อยู่ไฟล์ที่เก็บไว้
  Future<String> submitEvidence(
    Order order,
    String note,
    Uint8List bytes,
    String fileName,
  );
}

// ดึงจากตาราง listings + orders ใน Supabase (สร้างตารางด้วย supabase/schema.sql)
class OrderSupabaseService implements OrderService {
  static const String _bucket = 'booking-proofs';

  @override
  Future<List<SellerListing>> getMySellerListings() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return List.empty();
    }

    await runPlayDeadlines();
    final data = await client
        .from('listings')
        .select('*, courts(name), orders(*)')
        .eq('seller_id', userId)
        .order('start_time', ascending: false);

    AllSellerListings all = AllSellerListings.fromJson(data);

    // จำนวนผู้ตั้งรับที่ตรงกับแต่ละประกาศ (ไว้ติดป้าย A5)
    final counts =
        await client.rpc('get_my_listing_request_counts') as List<dynamic>;
    for (final row in counts) {
      final listingId = row['listing_id'].toString();
      final count = (row['request_count'] as num).toInt();
      for (final item in all.items) {
        if (item.listing.id == listingId) {
          item.requestCount = count;
        }
      }
    }
    return all.items;
  }

  @override
  Future<String> submitEvidence(
    Order order,
    String note,
    Uint8List bytes,
    String fileName,
  ) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('ยังไม่ได้ล็อกอิน');
    }

    final dot = fileName.lastIndexOf('.');
    final extension = dot == -1
        ? 'jpg'
        : fileName.substring(dot + 1).toLowerCase();
    final path =
        '$userId/evidence_${order.id}_'
        '${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage.from(_bucket).uploadBinary(path, bytes);
    // ฐานข้อมูลเช็กเองว่าเป็นผู้ขายของออเดอร์นี้ และยังไม่เลย 24 ชม.
    await client.rpc(
      'submit_dispute_evidence',
      params: {
        'p_order_id': int.parse(order.id),
        'p_note': note,
        'p_evidence_path': path,
      },
    );
    return path;
  }
}
