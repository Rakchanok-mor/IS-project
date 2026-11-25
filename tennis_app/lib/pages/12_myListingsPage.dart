import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/components/tab_switch.dart';
import 'package:tennis_app/controller/order_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/pages/13_orderStatusPage.dart';
import 'package:tennis_app/pages/32_listingRequestsPage.dart';
import 'package:tennis_app/services/order_service.dart';

// แท็บ "ประกาศของฉัน" (ฝั่งผู้ขาย): ประกาศทั้งหมดของเรา พร้อมสถานะเงินของแต่ละออเดอร์
// แบ่งเป็น กำลังดำเนินการ / ประวัติ
// อยู่ในหน้าหลัก (HomePage) จึงไม่มี Scaffold ของตัวเอง
class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  OrderController controller = OrderController(OrderSupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  List<SellerListing> items = List.empty();
  bool isLoading = false;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoading = syncState;
      });
    });
    _loadItems();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      await controller.fetchMySellerListings();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โหลดประกาศไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      items = controller.items;
    });
  }

  Future<void> _openItem(SellerListing item) async {
    // มีผู้ตั้งรับตรงกับประกาศ → หน้ารายชื่อผู้ตั้งรับ (A5)
    if (item.hasMatchingRequests) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ListingRequestsPage(listing: item.listing),
        ),
      );
      if (!mounted) return;
      _loadItems();
      return;
    }

    // ทุกประกาศกดดูสถานะได้ (ยังไม่มีผู้ซื้อก็เห็นขั้นตอน + เงินที่จะได้รับ)
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderStatusPage(item: item)),
    );
    // กลับมาแล้ววาดใหม่ เผื่อส่งหลักฐานไปแล้ว
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => !item.isFinished).toList();
    final history = items.where((item) => item.isFinished).toList();

    // เรื่องที่ต้องรีบจัดการ (ผู้ซื้อแจ้งปัญหา) ขึ้นก่อนเสมอ
    active.sort((a, b) {
      if (a.isDisputed != b.isDisputed) {
        return a.isDisputed ? -1 : 1;
      }
      return a.listing.startTime.compareTo(b.listing.startTime);
    });

    final shown = selectedTab == 0 ? active : history;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const Text(
                'ประกาศขาย',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              TabSwitch(
                labels: ['กำลังดำเนินการ (${active.length})', 'ประวัติ'],
                selectedIndex: selectedTab,
                onChanged: (int index) {
                  setState(() {
                    selectedTab = index;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading && items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView(
                    // ให้ดึงลงเพื่อโหลดใหม่ได้แม้รายการจะสั้น
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                    children: [
                      if (shown.isEmpty)
                        _buildEmpty(
                          selectedTab == 0
                              ? 'ยังไม่มีประกาศที่กำลังดำเนินการ'
                              : 'ยังไม่มีประวัติ',
                        ),
                      ...List.generate(shown.length, (index) {
                        return SellerListingCard(
                          item: shown[index],
                          onTap: () {
                            _openItem(shown[index]);
                          },
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
        child: Text(message, style: const TextStyle(color: kSubtextColor)),
      ),
    );
  }
}
