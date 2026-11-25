import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/request_model.dart';

// สัญญาว่าที่เก็บข้อมูลการตั้งรับต้องทำอะไรได้บ้าง
abstract class RequestService {
  Future<void> createRequest(CourtRequest request);

  // การตั้งรับของเราที่ยังรออยู่ (ยังไม่ถึงเวลา) พร้อมประกาศที่ตรงกัน
  Future<List<MyRequest>> getMyRequests();

  // ฝั่งผู้ขาย (A5): ผู้ตั้งรับที่ตรงกับประกาศของเรา
  Future<List<ListingRequest>> getListingRequests(Listing listing);
}

// เพิ่มแถวในตาราง requests ใน Supabase
// การจับคู่กับประกาศของผู้ขายดูได้จาก view request_matches (ใน supabase/schema.sql)
class RequestSupabaseService implements RequestService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> createRequest(CourtRequest request) async {
    await _client.from('requests').insert(request.toJson());
  }

  // 1. ดึงการตั้งรับของเราที่ยังรออยู่
  // 2. ดึงคู่ที่ตรงกันจาก view request_matches แล้วดึงประกาศของคู่เหล่านั้น
  @override
  Future<List<MyRequest>> getMyRequests() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return List.empty();
    }

    final data = await _client
        .from('requests')
        .select('*, courts(name)')
        .eq('buyer_id', userId)
        .eq('status', kRequestWaiting)
        .gte('end_time', DateTime.now().toUtc().toIso8601String())
        .order('start_time');
    final requests = AllMyRequests.fromJson(data).requests;
    if (requests.isEmpty) {
      return requests;
    }

    final matchRows = await _client
        .from('request_matches')
        .select('request_id, listing_id')
        .eq('buyer_id', userId);
    if (matchRows.isEmpty) {
      return requests;
    }

    final listingIds = matchRows
        .map((row) => row['listing_id'])
        .toSet()
        .toList();
    final listingRows = await _client
        .from('listings')
        .select('*, courts(name, name_en)')
        .inFilter('id', listingIds)
        // ไม่เอาประกาศที่ถึงเวลาเล่นแล้ว (ซื้อไม่ได้)
        .gte('start_time', DateTime.now().toUtc().toIso8601String())
        .order('start_time');
    final listings = AllListings.fromJson(listingRows).listings;

    for (final request in requests) {
      final ids = matchRows
          .where((row) => row['request_id'].toString() == request.id)
          .map((row) => row['listing_id'].toString())
          .toSet();
      request.matches = listings
          .where((listing) => ids.contains(listing.id))
          .toList();
    }
    return requests;
  }

  // ผู้ขายอ่านตาราง requests ของคนอื่นตรง ๆ ไม่ได้ จึงต้องผ่านฟังก์ชันที่ไม่ส่งข้อมูลผู้ซื้อ
  @override
  Future<List<ListingRequest>> getListingRequests(Listing listing) async {
    final data = await _client.rpc(
      'get_listing_requests',
      params: {'p_listing_id': int.parse(listing.id)},
    );
    AllListingRequests all = AllListingRequests.fromJson(data as List<dynamic>);
    return all.requests;
  }
}
