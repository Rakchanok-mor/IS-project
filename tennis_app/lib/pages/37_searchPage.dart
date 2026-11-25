import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/court_search_bar.dart';
import 'package:tennis_app/components/listing_card.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/controller/court_controller.dart';
import 'package:tennis_app/controller/listing_controller.dart';
import 'package:tennis_app/models/court_model.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/pages/11_courtMapPage.dart';
import 'package:tennis_app/pages/14_listingDetailPage.dart';
import 'package:tennis_app/services/auth_service.dart';
import 'package:tennis_app/services/court_service.dart';
import 'package:tennis_app/services/listing_service.dart';

// หน้าค้นหาสนาม (ฝั่งซื้อ) เปิดจากกล่อง "ค้นหาสนาม" บนหน้าหลัก
// แสดงเฉพาะผลค้นหา ไม่โหลดประกาศทั้งหมดตอนเปิดหน้า (ไม่ต้อง query ทุกครั้งที่เข้ามา)
// ค้นได้จาก สนาม (พิมพ์ชื่อ / เลือกจากแผนที่)
// ใช้กีฬาที่เลือกไว้บนหน้าหลัก
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  ListingController controller = ListingController(ListingSupabaseService());
  CourtController courtController = CourtController(CourtSupabaseService());
  // ไว้เช็กว่าประกาศไหนเป็นของเราเอง
  AuthController authController = AuthController(AuthSupabaseService());
  TextEditingController searchController = TextEditingController();

  List<Listing> searchResults = List.empty();
  bool isSearching = false;
  String searchText = '';
  Court? mapCourt; // สนามที่เลือกจากแผนที่ (ยังไม่เลือก = null)
  Timer? _searchTimer; // รอให้หยุดพิมพ์ก่อนค่อยค้น จะได้ไม่ยิงทุกตัวอักษร

  String get sport => context.read<HomeModel>().sport;

  // พิมพ์ชื่อหรือเลือกสนามจากแผนที่แล้ว ถึงจะค้นที่ฐานข้อมูล
  bool get isSearchMode => searchText.trim().isNotEmpty || mapCourt != null;

  @override
  void dispose() {
    _searchTimer?.cancel();
    controller.dispose();
    courtController.dispose();
    authController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ค้นหา: เลือกจากแผนที่ = ค้นด้วย id สนาม, พิมพ์เอง = ค้นด้วยชื่อสนาม
  // wait = true รอให้หยุดพิมพ์ 0.4 วินาทีก่อน (ใช้ตอนพิมพ์)
  void _search({bool wait = true}) {
    _searchTimer?.cancel();
    final keyword = searchText.trim();
    final court = mapCourt;

    if (!isSearchMode) {
      setState(() {
        searchResults = List.empty();
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });
    _searchTimer = Timer(Duration(milliseconds: wait ? 400 : 0), () async {
      List<Listing> results = List.empty();
      try {
        results = await controller.searchListings(
          sport,
          keyword: keyword,
          courtId: court?.id,
        );
      } catch (error) {
        _showMessage('ค้นหาไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
      // ระหว่างรอผล ผู้ใช้เปลี่ยนเงื่อนไขแล้ว = ทิ้งผลเก่า รอผลของเงื่อนไขใหม่แทน
      if (!mounted || keyword != searchText.trim() || court != mapCourt) {
        return;
      }
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    });
  }

  // เปิดแผนที่ เลือกสนามแล้วค้นหาเฉพาะสนามนั้น
  Future<void> _openMap() async {
    List<Court> courts;
    try {
      courts = await courtController.fetchCourts(sport);
    } catch (error) {
      _showMessage('โหลดสนามไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;

    final Court? picked = await Navigator.push<Court>(
      context,
      MaterialPageRoute(
        builder: (context) => CourtMapPage(
          courts: courts,
          selectedCourt: mapCourt,
          isBuyerMode: true,
          buttonLabel: 'ดูประกาศของสนามนี้',
        ),
      ),
    );
    if (picked == null || !mounted) return;

    // ใส่ชื่อสนามในช่องค้นหาให้เห็นว่ากรองอยู่ ลบข้อความ = เลิกกรอง
    setState(() {
      mapCourt = picked;
      searchController.text = picked.name;
      searchText = picked.name;
    });
    _search(wait: false);
  }

  Future<void> _openListing(Listing listing) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailPage(listing: listing),
      ),
    );
    // กลับมาแล้วค้นใหม่ ประกาศที่ถูกล็อก/ปลดล็อก/ขายแล้วจะได้อัปเดต
    if (!mounted) return;
    _search(wait: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: Text(
          'ค้นหาสนาม${sportLabel(sport)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
        children: [
          CourtSearchBar(
            controller: searchController,
            hintText: 'ค้นหาชื่อสนาม',
            onChanged: (String value) {
              setState(() {
                searchText = value;
                // แก้ข้อความเอง = เลิกกรองตามสนามที่เลือกจากแผนที่
                mapCourt = null;
              });
              _search();
            },
            onOpenMap: _openMap,
          ),
          if (isSearchMode) ...[
            const SizedBox(height: 20.0),
            const Text(
              'ผลการค้นหา',
              style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12.0),
          ],
          ..._buildResults(),
        ],
      ),
    );
  }

  List<Widget> _buildResults() {
    // ยังไม่ได้ใส่เงื่อนไข = ยังไม่ค้น แค่บอกวิธีค้นหา
    if (!isSearchMode) {
      return [
        _buildEmpty('พิมพ์ชื่อสนาม หรือเลือกจากแผนที่\nเพื่อค้นหาประกาศขาย'),
      ];
    }

    if (isSearching) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (searchResults.isEmpty) {
      return [_buildEmpty('ไม่พบประกาศที่ตรงกับการค้นหา\n')];
    }

    return [
      ...searchResults.map(
        (listing) => ListingCard(
          listing: listing,
          isMine: listing.isOwnedBy(authController.currentUserId),
          onTap: () => _openListing(listing),
        ),
      ),
      // ผลค้นหาเต็มจำนวนแล้ว = อาจมีมากกว่านี้ แนะนำให้ค้นให้แคบลง
      if (searchResults.length >= kSearchLimit)
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'แสดง $kSearchLimit รายการที่เล่นได้เร็วที่สุด '
            'ระบุสนามหรือวันที่ให้เจาะจงขึ้นเพื่อดูประกาศอื่น',
            style: TextStyle(fontSize: 13.0, color: kHintColor),
          ),
        ),
    ];
  }

  Widget _buildEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kSubtextColor, height: 1.5),
        ),
      ),
    );
  }
}
