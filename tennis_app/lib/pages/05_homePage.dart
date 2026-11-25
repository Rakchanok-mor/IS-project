import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/action_tile.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/my_request_card.dart';
import 'package:tennis_app/components/mode_switch.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/components/sport_switch.dart';
import 'package:tennis_app/controller/notification_controller.dart';
import 'package:tennis_app/controller/order_controller.dart';
import 'package:tennis_app/controller/profile_controller.dart';
import 'package:tennis_app/controller/request_controller.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/request_model.dart';
import 'package:tennis_app/pages/06_requestPage.dart';
import 'package:tennis_app/pages/07_accountPage.dart';
import 'package:tennis_app/pages/09_sellPage.dart';
import 'package:tennis_app/pages/12_myListingsPage.dart';
import 'package:tennis_app/pages/14_listingDetailPage.dart';
import 'package:tennis_app/pages/18_myPurchasesPage.dart';
import 'package:tennis_app/pages/32_listingRequestsPage.dart';
import 'package:tennis_app/pages/34_notificationsPage.dart';
import 'package:tennis_app/pages/37_searchPage.dart';
import 'package:tennis_app/services/notification_service.dart';
import 'package:tennis_app/services/order_service.dart';
import 'package:tennis_app/services/profile_service.dart';
import 'package:tennis_app/services/request_service.dart';

// หน้าหลักหน้าเดียว ใช้ได้ทั้งโหมดผู้ซื้อและผู้ขาย
// กดสลับโหมดหรือกีฬาแล้วเปลี่ยนแค่เนื้อหา ไม่ต้องเปิดหน้าใหม่
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ประกาศของเรา (ฝั่งขาย) พร้อมจำนวนผู้ตั้งรับที่ตรงกับแต่ละประกาศ
  OrderController orderController = OrderController(OrderSupabaseService());
  List<SellerListing> myListings = List.empty();
  // แยกสถานะโหลดฝั่งขายกับฝั่งซื้อ วงโหลดหมุนจนกว่าจะเสร็จครบทั้งสองฝั่ง
  bool isOrderLoading = false;
  bool isRequestLoading = false;
  StreamSubscription<bool>? _syncSubscription;
  StreamSubscription<bool>? _requestSyncSubscription;

  // แจ้งเตือน: อยู่ที่หน้าหลักตลอด ตัวเลขบนกระดิ่งกับหน้าแจ้งเตือนฟังจากตัวเดียวกัน
  NotificationController notificationController = NotificationController(
    NotificationSupabaseService(),
  );

  // การตั้งรับของเรา (หน้าหลักโหมดซื้อ)
  RequestController requestController = RequestController(
    RequestSupabaseService(),
  );

  // ประกาศตั้งรับของฉัน (ทุกกีฬา หน้าจอกรองตามกีฬาที่เลือก) พร้อมประกาศที่ตรง
  List<MyRequest> myRequests = List.empty();

  // ชื่อผู้ใช้สำหรับปุ่มบัญชีขวาบน
  ProfileController profileController = ProfileController(
    ProfileSupabaseService(),
  );

  // กลับมาหน้าหลักจากแท็บอื่น (เช่น แตะแจ้งเตือนสนามที่ตรงกัน) → โหลดใหม่
  late HomeModel _home;
  int _lastTab = kTabHome;

  @override
  void initState() {
    super.initState();
    notificationController.start();
    _syncSubscription = orderController.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isOrderLoading = syncState;
      });
    });
    _requestSyncSubscription = requestController.onSync.listen((
      bool syncState,
    ) {
      if (!mounted) return;
      setState(() {
        isRequestLoading = syncState;
      });
    });
    _home = context.read<HomeModel>();
    _home.addListener(_onHomeChanged);
    _loadFirstTime();
  }

  @override
  void dispose() {
    _home.removeListener(_onHomeChanged);
    _syncSubscription?.cancel();
    _requestSyncSubscription?.cancel();
    orderController.dispose();
    notificationController.dispose();
    requestController.dispose();
    profileController.dispose();
    super.dispose();
  }

  void _onHomeChanged() {
    if (_home.selectedTab == kTabHome && _lastTab != kTabHome) {
      _loadListings(_home.sport);
    }
    _lastTab = _home.selectedTab;
  }

  // เปิดแอปครั้งแรก: อ่านกีฬาที่เลือกไว้ครั้งก่อน แล้วค่อยโหลดประกาศ
  Future<void> _loadFirstTime() async {
    final home = context.read<HomeModel>();
    await home.loadSavedSport();
    await _loadListings(home.sport);
  }

  // โหลดประกาศของเรา (ฝั่งขาย) + ประกาศตั้งรับของเรา (ฝั่งซื้อ)
  Future<void> _loadListings(String sport) async {
    List<SellerListing> mine = List.empty();
    try {
      mine = await orderController.fetchMySellerListings();
    } catch (error) {
      // โหลดประกาศของเราไม่ได้ ฝั่งซื้อยังใช้ได้ตามปกติ
    }
    List<MyRequest> requests = myRequests;
    try {
      requests = await requestController.fetchMyRequests();
    } catch (error) {
      // โหลดไม่ได้ = ใช้ของเดิม ส่วนอื่นยังใช้ได้ตามปกติ
    }
    if (!mounted) return;
    setState(() {
      myListings = mine;
      myRequests = requests;
    });
  }

  // เปิดหน้าบัญชีจากปุ่มกลมขวาบน กลับมาแล้ววาดใหม่ (เผื่อแก้ชื่อ)
  Future<void> _openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountPage()),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeModel>();

    return Scaffold(
      backgroundColor: kPageColor,
      body: SafeArea(
        child: switch (home.selectedTab) {
          kTabHome => _buildHome(home),
          // แท็บ "ของฉัน" เปลี่ยนตามโหมด
          kTabMine =>
            home.isBuyerMode ? const MyPurchasesPage() : const MyListingsPage(),
          _ => NotificationsPage(controller: notificationController),
        },
      ),
      // เมนูด้านล่าง 3 แท็บ แท็บที่ 2 กับสีของแท็บที่เลือกเปลี่ยนตามโหมด
      // (บัญชีอยู่ที่ปุ่มกลมขวาบนของหน้าหลัก)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          // ฝั่งซื้อใช้เขียวแบบจาง ไอคอนสีดำบนแถบจะได้ยังมองเห็น
          indicatorColor: home.isBuyerMode
              ? kBuyerColor.withValues(alpha: 0.3)
              : kSellerColor,
          selectedIndex: home.selectedTab,
          onDestinationSelected: (index) {
            home.selectedTab = index;
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'หน้าหลัก',
            ),
            if (home.isBuyerMode)
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'คำสั่งซื้อ',
              )
            else
              const NavigationDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: 'ประกาศขาย',
              ),
            // กระดิ่งมีตัวเลขแจ้งเตือนที่ยังไม่อ่าน อัปเดตเองผ่าน StreamBuilder
            NavigationDestination(
              icon: _buildBell(Icons.notifications_outlined),
              selectedIcon: _buildBell(Icons.notifications),
              label: 'แจ้งเตือน',
            ),
          ],
        ),
      ),
    );
  }

  // ปุ่มบัญชีกลม ๆ ขวาบน: อักษรแรกของชื่อ (ยังไม่กรอกชื่อ = ไอคอนคน)
  Widget _buildAccountButton(HomeModel home) {
    // อ่านใหม่ทุกครั้งที่วาด เผื่อเพิ่งแก้ชื่อมาจากหน้าบัญชี
    final profile = profileController.reload();
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: _openAccount,
      child: Container(
        width: 40.0,
        height: 40.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: home.isBuyerMode ? kBuyerSoftColor : kSellerColor,
          shape: BoxShape.circle,
          border: Border.all(color: kBorderColor),
        ),
        child: profile.firstName.isEmpty
            ? const Icon(Icons.person, size: 22.0)
            : Text(
                profile.firstName.characters.first,
                style: const TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // ไอคอนกระดิ่ง + ป้ายตัวเลขที่ยังไม่อ่าน (ไม่มี = ไม่แสดงป้าย)
  Widget _buildBell(IconData icon) {
    return StreamBuilder<int>(
      stream: notificationController.onUnreadCount,
      initialData: notificationController.unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: kAlertColor,
          child: Icon(icon),
        );
      },
    );
  }

  // แท็บหน้าหลัก: ส่วนหัว (ชื่อแอป + สลับโหมด + สลับกีฬา) แล้วตามด้วยเนื้อหาตามโหมด
  Widget _buildHome(HomeModel home) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        _buildHeader(home),
        Expanded(
          child: isOrderLoading || isRequestLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  // เว้นที่ด้านล่างไว้ ไม่ให้ปุ่มลอยบังการ์ดใบสุดท้าย
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 96.0),
                  children: home.isBuyerMode
                      ? _buildBuyerContent(home)
                      : _buildSellerContent(home),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(HomeModel home) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          // ชื่อแอป + ปุ่มบัญชี (วงกลมอักษรแรกของชื่อ) ขวาบน
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Courtswap',
                  style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
                ),
              ),
              _buildAccountButton(home),
            ],
          ),
          const SizedBox(height: 16.0),
          ModeSwitch(
            isBuyerMode: home.isBuyerMode,
            onChanged: (bool value) {
              home.isBuyerMode = value;
            },
          ),
          const SizedBox(height: 12.0),
          SportSwitch(
            sport: home.sport,
            onChanged: (String value) {
              home.sport = value;
              _loadListings(value);
            },
          ),
        ],
      ),
    );
  }

  // โหมดผู้ซื้อ: 2 กล่องตามจุดเริ่มต้นของ Workflow ขอซื้อสนาม
  //   ค้นหาสนาม = หาประกาศขายเอง (หน้าค้นหาสนาม)
  //   ตั้งรับสนาม = ไม่เจอสนามที่อยากได้ ตั้งรับไว้ให้ระบบจับคู่เมื่อมีผู้ขายปล่อย
  // ใต้กล่อง: ประกาศที่ตรงกับที่เราตั้งรับไว้ (personalize ตามที่ผู้ใช้บอกเอง)
  List<Widget> _buildBuyerContent(HomeModel home) {
    return [
      Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: ActionTile(
              icon: Icons.search,
              title: 'ค้นหาสนาม',
              onTap: () => _openAndReload(home, const SearchPage()),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: ActionTile(
              icon: Icons.push_pin_outlined,
              title: 'ตั้งรับสนาม',
              onTap: () => _openAndReload(home, const RequestPage()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24.0),
      ..._buildMyRequestsSection(home),
    ];
  }

  // เปิดหน้าอื่น กลับมาแล้วโหลดใหม่ (เช่น ตั้งรับเพิ่ม หรือซื้อไปแล้ว ประกาศที่ตรงจะเปลี่ยน)
  Future<void> _openAndReload(HomeModel home, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (!mounted) return;
    _loadListings(home.sport);
  }

  // ส่วน "ประกาศตั้งรับของฉัน" (กีฬาที่เลือก): การตั้งรับที่ยังรออยู่
  // แต่ละอันมีประกาศที่ตรง (แตะเพื่อดู/ซื้อ)
  List<Widget> _buildMyRequestsSection(HomeModel home) {
    final shown = myRequests
        .where((request) => request.sport == home.sport)
        .toList();

    return [
      const Text(
        'ประกาศตั้งรับของฉัน',
        style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12.0),
      if (shown.isEmpty)
        _buildEmpty(
          'ยังไม่ได้ตั้งรับสนาม${sportLabel(home.sport)}\n'
          'กด "ตั้งรับสนาม" แล้วระบบจะหาสนามที่ตรงให้',
        ),
      ...shown.map(
        (request) => MyRequestCard(
          request: request,
          onOpenListing: (listing) =>
              _openAndReload(home, ListingDetailPage(listing: listing)),
        ),
      ),
    ];
  }

  // โหมดผู้ขาย: หน้าตาแบบเดียวกับฝั่งซื้อ
  //   ลงประกาศขาย = เริ่มจากลงประกาศให้สำเร็จก่อน
  //   ประกาศของฉัน = ไปแท็บประกาศของฉัน
  // ใต้กล่อง: ประกาศของเราที่มีผู้ตั้งรับตรง → แตะเพื่อดูรายชื่อผู้ตั้งรับ
  List<Widget> _buildSellerContent(HomeModel home) {
    return [
      Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: ActionTile(
              icon: Icons.add_business_outlined,
              title: 'ลงประกาศขาย',
              isBuyerMode: false,
              onTap: () => _openAndReload(home, const SellPage()),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: ActionTile(
              icon: Icons.sell_outlined,
              title: 'ประกาศขาย',
              isBuyerMode: false,
              onTap: () => home.openMyListings(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24.0),
      ..._buildMatchedListingsSection(home),
    ];
  }

  // ส่วน "ผู้ตั้งรับตรงกับประกาศของคุณ": ประกาศของเรา (กีฬานี้) ที่มีผู้ตั้งรับตรง
  // แสดงสูงสุด 3 อัน เยอะกว่านั้นกด "ดูทั้งหมด" ไปแท็บประกาศของฉัน
  List<Widget> _buildMatchedListingsSection(HomeModel home) {
    const int maxShown = 3;
    final ofSport = myListings
        .where((item) => item.listing.sport == home.sport)
        .toList();
    final matched = ofSport.where((item) => item.hasMatchingRequests).toList();
    final hasOpenListing = ofSport.any(
      (item) => item.order == null && item.listing.isAvailable,
    );
    final shown = matched.take(maxShown).toList();

    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'ผู้ตั้งรับตรงกับประกาศของคุณ',
              style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
            ),
          ),
          if (matched.length > maxShown)
            TextButton(
              onPressed: () => home.openMyListings(),
              child: Text(
                'ดูทั้งหมด (${matched.length})',
                style: const TextStyle(
                  color: kSellerTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12.0),
      if (shown.isEmpty)
        _buildEmpty(
          hasOpenListing
              ? 'ยังไม่มีผู้ตั้งรับที่ตรงกับประกาศของคุณ\n'
                    'ระบบจะแจ้งเตือนเมื่อมีผู้ซื้อตั้งรับที่ตรง'
              : 'ยังไม่มีประกาศขายสนาม${sportLabel(home.sport)}\n'
                    'กด "ลงประกาศขาย" แล้วระบบจะหาผู้ตั้งรับที่ตรงให้',
        ),
      ...shown.map(
        (item) => SellerListingCard(
          item: item,
          onTap: () =>
              _openAndReload(home, ListingRequestsPage(listing: item.listing)),
        ),
      ),
    ];
  }

  Widget _buildEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        // ข้อความ 2 บรรทัดก็อยู่กึ่งกลางทั้งสองบรรทัด
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kSubtextColor, height: 1.5),
        ),
      ),
    );
  }
}
