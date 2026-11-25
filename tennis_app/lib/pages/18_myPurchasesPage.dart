import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/components/tab_switch.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/pages/15_paymentPage.dart';
import 'package:tennis_app/pages/16_paymentStatusPage.dart';
import 'package:tennis_app/services/payment_service.dart';
import 'package:provider/provider.dart';

// แท็บ "การซื้อของฉัน" (ฝั่งผู้ซื้อ) มี 2 แท็บย่อย: กำลังดำเนินการ / ประวัติ
// แตะคำสั่งซื้อเพื่อดูสถานะ (การตั้งรับย้ายไปอยู่หน้าหลักโหมดซื้อแล้ว)
// อยู่ในหน้าหลัก (HomePage) จึงไม่มี Scaffold ของตัวเอง
class MyPurchasesPage extends StatefulWidget {
  const MyPurchasesPage({super.key});

  @override
  State<MyPurchasesPage> createState() => _MyPurchasesPageState();
}

class _MyPurchasesPageState extends State<MyPurchasesPage> {
  PaymentController controller = PaymentController(PaymentSupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  List<PaymentItem> items = List.empty();
  bool isLoading = false;
  int selectedTab = kPurchasesTabActive;

  @override
  void initState() {
    super.initState();
    // เปิดแท็บย่อยตามที่หน้าอื่นสั่งไว้
    final home = context.read<HomeModel>();
    selectedTab = home.purchasesTab;
    home.purchasesTab = kPurchasesTabActive;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadItems() async {
    try {
      await controller.fetchMyPurchases();
    } catch (error) {
      if (!mounted) return;
      _showMessage('โหลดไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;
    setState(() {
      items = controller.items;
    });
  }

  // ยังรอชำระ = กลับไปหน้าชำระเงิน, ที่เหลือ = หน้าสถานะ
  Future<void> _openItem(PaymentItem item) async {
    final Widget page;
    if (item.order.status == kOrderPendingPayment &&
        !item.order.timeLeft.isNegative) {
      page = PaymentPage(listing: item.listing, order: item.order);
    } else {
      page = PaymentStatusPage(orderId: item.order.id);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (!mounted) return;
    _loadItems();
  }

  // จบแล้ว = อยู่แท็บประวัติ (ยืนยันการเล่นแล้ว ฝั่งผู้ซื้อถือว่าเสร็จ)
  // ที่ยังไม่จบ: รอเล่น / รอยืนยันการเล่น / แจ้งปัญหาอยู่ / รอคืนเงิน
  bool _isFinished(PaymentItem item) {
    final status = item.order.status;
    return status == kOrderRefunded ||
        status == kOrderExpired ||
        status == kOrderCancelled ||
        status == kOrderReleased ||
        status == kOrderConfirmed ||
        (status == kOrderPendingPayment && item.order.timeLeft.isNegative);
  }

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => !_isFinished(item)).toList();
    final history = items.where(_isFinished).toList();
    final shown = selectedTab == kPurchasesTabHistory ? history : active;
    final showSpinner = isLoading && items.isEmpty;

    // ข้อความตอนไม่มีรายการ
    final emptyText = selectedTab == kPurchasesTabActive
        ? 'ยังไม่มีการซื้อที่กำลังดำเนินการ'
        : 'ยังไม่มีประวัติการซื้อ';
    final isEmpty = shown.isEmpty;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const Text(
                'การซื้อของฉัน',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              TabSwitch(
                labels: ['ดำเนินการ (${active.length})', 'ประวัติ'],
                selectedIndex: selectedTab,
                color: kBuyerColor,
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
          child: showSpinner
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                    children: [
                      if (isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: Center(
                            child: Text(
                              emptyText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kSubtextColor,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ...shown.map(_buildCard),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(PaymentItem item) {
    final status = item.order.status;
    final isProblem = status == kOrderRejected || status == kOrderDisputed;
    final needsPayment =
        status == kOrderPendingPayment && !item.order.timeLeft.isNegative;
    // ต้องกดอะไรสักอย่าง: ชำระเงินต่อ / ยืนยันการเล่น
    final needsAction = needsPayment || item.canConfirmPlay;

    Color chipBackground;
    Color chipText;
    if (isProblem) {
      chipBackground = kAlertBackground;
      chipText = kAlertColor;
    } else if (needsAction) {
      // ต้องทำอะไรต่อ = เขียวเข้มให้เด่น
      chipBackground = kBuyerColor;
      chipText = kOnBuyerColor;
    } else if (item.order.isPaid) {
      chipBackground = kBuyerSoftColor;
      chipText = kBuyerColor;
    } else {
      chipBackground = kNeutralSoftColor;
      chipText = kNeutralTextColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () => _openItem(item),
        child: Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            // ขอบเทาอ่อนเหมือนการ์ดฝั่งขาย (SellerListingCard)
            border: Border.all(
              color: kCardBorderColor,
              width: isProblem ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            children: [
              SportIconBox(sport: item.listing.sport, isBuyerMode: true),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      item.listing.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      item.listing.scheduleText,
                      style: const TextStyle(color: kSubtextColor),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      needsPayment
                          ? 'แตะเพื่อชำระเงินต่อ'
                          : '฿${item.order.amount} · ${item.order.reference}',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: needsPayment ? kBorderColor : kHintColor,
                        fontWeight: needsPayment
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  item.buyerStatusLabel,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: chipText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
