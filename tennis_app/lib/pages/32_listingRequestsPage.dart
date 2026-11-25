import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/request_controller.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/request_model.dart';
import 'package:tennis_app/services/request_service.dart';

// หน้าผู้ตั้งรับที่ตรงกับประกาศ (A5) ฝั่งผู้ขาย
// แสดงรายชื่อผู้ตั้งรับ (ชื่อแบบย่อ + ช่วงเวลาที่อยากเล่น ไม่เห็นอีเมล)
// ไม่ต้องส่งข้อเสนอเอง เพราะระบบแจ้งเตือนผู้ซื้อที่ตรงกันตั้งแต่ลงประกาศแล้ว
class ListingRequestsPage extends StatefulWidget {
  const ListingRequestsPage({super.key, required this.listing});

  final Listing listing;

  @override
  State<ListingRequestsPage> createState() => _ListingRequestsPageState();
}

class _ListingRequestsPageState extends State<ListingRequestsPage> {
  RequestController controller = RequestController(RequestSupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  List<ListingRequest> requests = List.empty();
  bool isLoading = false;
  bool loaded = false;

  Listing get listing => widget.listing;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoading = syncState;
      });
    });
    _load();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    try {
      await controller.fetchListingRequests(listing);
    } catch (error) {
      if (!mounted) return;
      _showMessage('โหลดไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;
    setState(() {
      requests = controller.listingRequests;
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'ผู้ตั้งรับที่ตรงกัน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: !loaded && isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildListing(),
                  const SizedBox(height: 16.0),
                  const Text(
                    'ผู้ซื้อที่ตั้งรับสนามนี้ในช่วงเวลาที่ครอบคลุมประกาศของคุณ '
                    'ระบบแจ้งเตือนผู้ซื้อเหล่านี้ให้แล้ว',
                    style: TextStyle(color: kSubtextColor, height: 1.5),
                  ),
                  const SizedBox(height: 16.0),
                  if (loaded && requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Text(
                          'ตอนนี้ไม่มีผู้ตั้งรับที่ตรงกันแล้ว',
                          style: TextStyle(color: kSubtextColor),
                        ),
                      ),
                    ),
                  ...requests.map(_buildRequest),
                ],
              ),
            ),
    );
  }

  // สรุปประกาศที่จะเสนอ
  Widget _buildListing() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: kSellerColor.withValues(alpha: 0.2),
        border: Border.all(color: kBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2.0),
                Text(
                  listing.scheduleText,
                  style: const TextStyle(color: kSubtextColor),
                ),
              ],
            ),
          ),
          Text(
            '฿${listing.price}',
            style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ผู้ตั้งรับ 1 คน: ชื่อแบบย่อ + ช่วงเวลาที่อยากเล่น
  Widget _buildRequest(ListingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            request.buyerName.isEmpty ? 'ผู้ซื้อ' : request.buyerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2.0),
          Text(
            'อยากเล่น ${request.scheduleText}',
            style: const TextStyle(color: kSubtextColor),
          ),
        ],
      ),
    );
  }
}
