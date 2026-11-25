import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/new_listing_model.dart';

// ผลค้นหาแสดงได้มากสุดกี่อัน
const int kSearchLimit = 20;

// สัญญาว่าที่เก็บข้อมูลประกาศต้องทำอะไรได้บ้าง
// (แบบเดียวกับ PostService ในงานวิชา: หน้าจอเรียกผ่าน abstract class เปลี่ยนที่เก็บข้อมูลได้)
abstract class ListingService {
  // ค้นหาประกาศที่ยังเปิดขาย: เลือกสนามจากแผนที่ (courtId) หรือพิมพ์ชื่อสนาม (keyword)
  // และ/หรือ วันที่อยากเล่น (date) — ไม่มีเงื่อนไขเลย = ไม่ค้น คืนค่าว่าง
  Future<List<Listing>> searchListings(
    String sport, {
    String keyword = '',
    int? courtId,
  });

  // ประกาศของเราเอง สำหรับโหมดผู้ขาย
  Future<List<Listing>> getMyListings(String sport);

  // ลงประกาศขายใหม่ (อัปโหลดหลักฐานการจองด้วย) คืนค่า id ของประกาศ
  Future<String> createListing(NewListing listing);
}

// ดึงจากตาราง listings ใน Supabase พร้อมชื่อสนามจากตาราง courts
// (สร้างตารางด้วยไฟล์ supabase/schema.sql)
class ListingSupabaseService implements ListingService {
  // ชื่อสนามภาษาอังกฤษใช้ค้นหาในหน้าหลักฝั่งซื้อ
  static const String _columns = '*, courts(name, name_en)';

  // ประกาศที่ผู้ซื้อซื้อได้ (เงื่อนไขพื้นฐานของการค้นหา)
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _buyableListings(
    String sport,
  ) {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id ?? '';
    return client
        .from('listings')
        .select(_columns)
        .eq('sport', sport)
        // ไม่แสดงประกาศของตัวเอง (ดูได้ที่แท็บประกาศของฉัน)
        .neq('seller_id', userId)
        // ไม่แสดงประกาศที่ขายแล้ว หรือมีคนกดซื้อและล็อกไว้รอชำระเงิน
        .inFilter('status', [kStatusOpen, kStatusInterested])
        .gte('start_time', DateTime.now().toUtc().toIso8601String());
  }

  // ค้นหาที่ฐานข้อมูล ดึงมาเฉพาะที่ตรงเงื่อนไข (ไม่โหลดประกาศทั้งหมดมากรองในเครื่อง)
  // ผลค้นหาเรียงตามเวลาเล่นที่ใกล้ที่สุด
  // พิมพ์ชื่อ = หาสนามที่ชื่อไทย/อังกฤษตรงก่อน แล้วเอาประกาศของสนามเหล่านั้น
  @override
  Future<List<Listing>> searchListings(
    String sport, {
    String keyword = '',
    int? courtId,
  }) async {
    final client = Supabase.instance.client;
    final key = _cleanKeyword(keyword);
    if (courtId == null && key.isEmpty) {
      return List.empty();
    }

    var query = _buyableListings(sport);

    if (courtId != null) {
      query = query.eq('court_id', courtId);
    } else if (key.isNotEmpty) {
      final courtRows = await client
          .from('courts')
          .select('id')
          .or('name.ilike.%$key%,name_en.ilike.%$key%');
      // ไม่มีสนามไหนชื่อตรงกับคำค้น = ไม่มีประกาศที่ตรง
      if (courtRows.isEmpty) {
        return List.empty();
      }
      final courtIds = courtRows.map((row) => row['id']).toList();
      query = query.inFilter('court_id', courtIds);
    }

    final data = await query.order('start_time').limit(kSearchLimit);
    AllListings all = AllListings.fromJson(data);
    return all.listings;
  }

  // ตัดตัวอักษรที่มีความหมายพิเศษในเงื่อนไขค้นหาของ Supabase ออก
  // (เช่น , กับ ( ) ใช้แบ่งเงื่อนไข, % ใช้แทนข้อความอะไรก็ได้)
  String _cleanKeyword(String keyword) {
    return keyword.replaceAll(RegExp(r'[,()%*\\"]'), ' ').trim();
  }

  @override
  Future<List<Listing>> getMyListings(String sport) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return List.empty();
    }

    final data = await Supabase.instance.client
        .from('listings')
        .select(_columns)
        .eq('seller_id', userId)
        .eq('sport', sport)
        .order('start_time');

    AllListings all = AllListings.fromJson(data);
    return all.listings;
  }

  // 1. อัปโหลดรูปหลักฐานไปที่ Storage (bucket booking-proofs แยกโฟลเดอร์ตาม user)
  // 2. เพิ่มแถวในตาราง listings พร้อมที่อยู่ของรูป
  @override
  Future<String> createListing(NewListing listing) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('ยังไม่ได้ล็อกอิน');
    }

    final data = listing.toJson();
    data['seller_id'] = userId;
    data['seller_name'] = sellerDisplayName(client.auth.currentUser);

    final bytes = listing.proofBytes;
    if (bytes != null) {
      // ตั้งชื่อไฟล์ใหม่จากเวลา กันชื่อซ้ำและชื่อภาษาไทยที่ Storage ไม่รับ
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}'
          '.${_extensionOf(listing.proofFileName)}';
      await client.storage.from(_proofBucket).uploadBinary(path, bytes);
      data['proof_path'] = path;
    }

    final row = await client
        .from('listings')
        .insert(data)
        .select('id')
        .single();
    return row['id'].toString();
  }

  static const String _proofBucket = 'booking-proofs';

  // ชื่อผู้ขายที่ผู้ซื้อเห็น: ใช้ชื่อในโปรไฟล์ถ้ามี ไม่งั้นใช้อีเมลแบบปิดบางส่วน เช่น "rmo***"
  static String sellerDisplayName(User? user) {
    // สมัครแบบใหม่มีชื่อ-นามสกุล: แสดงชื่อ + อักษรแรกของนามสกุล เช่น "สมชาย ก."
    // (ไม่โชว์นามสกุลเต็มให้คนทั้งแอปเห็น)
    final firstName =
        (user?.userMetadata?['first_name'] as String?)?.trim() ?? '';
    final lastName =
        (user?.userMetadata?['last_name'] as String?)?.trim() ?? '';
    if (firstName.isNotEmpty) {
      return lastName.isEmpty
          ? firstName
          : '$firstName ${lastName.characters.first}.';
    }

    final name = user?.userMetadata?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    final prefix = (user?.email ?? '').split('@').first;
    if (prefix.isEmpty) return 'ผู้ขาย';
    final shown = prefix.length <= 3
        ? prefix.substring(0, 1)
        : prefix.substring(0, 3);
    return '$shown***';
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) {
      return 'jpg';
    }
    return fileName.substring(dot + 1).toLowerCase();
  }
}
