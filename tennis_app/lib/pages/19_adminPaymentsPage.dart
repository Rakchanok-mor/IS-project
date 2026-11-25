import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/tab_switch.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/pages/20_adminOrderPage.dart';
import 'package:tennis_app/services/payment_service.dart';

// หน้าการเงินของแอดมิน (U1/U3): รอโอนผู้ขาย / รอคืนเงิน / ประวัติ
// เงินขาเข้าตรวจอัตโนมัติผ่าน Payment Gateway แล้ว แอดมินไม่ต้องตรวจ
// เข้าได้จากแท็บบัญชี (เห็นปุ่มเฉพาะคนที่เป็นแอดมิน)
class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  PaymentController controller = PaymentController(PaymentSupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  List<PaymentItem> items = List.empty();
  bool isLoading = false;
  // แท็บ (ใช้เลขคงที่ ไม่ใช่ลำดับบนจอ เพราะบางแท็บซ่อนได้)
  static const int _tabPayout = 0; // โอนผู้ขาย: เฉพาะที่โอนอัตโนมัติไม่สำเร็จ
  static const int _tabRefund = 1;
  static const int _tabHistory = 2;
  int selectedTab = _tabRefund;

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
      await controller.fetchAdminQueue();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โหลดไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      items = controller.items;
    });
  }

  Future<void> _openItem(PaymentItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminOrderPage(item: item)),
    );
    if (!mounted) return;
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    // รอโอนผู้ขาย: ใกล้ครบ 48 ชม. ขึ้นก่อน
    final toPay = items
        .where((item) => item.order.status == kOrderConfirmed)
        .toList();
    toPay.sort((a, b) {
      final aTime = a.order.confirmedAt ?? DateTime.now();
      final bTime = b.order.confirmedAt ?? DateTime.now();
      return aTime.compareTo(bTime);
    });
    final toRefund = items
        .where((item) => item.order.status == kOrderRejected)
        .toList();
    // ประวัติ: ชำระแล้ว · โอนผู้ขายแล้ว · คืนเงินแล้ว ใหม่สุดก่อน
    final history = items.where((item) => _isHistory(item.order)).toList();
    history.sort((a, b) {
      final aTime = _historyTime(a.order) ?? DateTime(2000);
      final bTime = _historyTime(b.order) ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    final List<List<PaymentItem>> tabs = [toPay, toRefund, history];

    // โอนผู้ขาย ระบบทำอัตโนมัติแล้ว: แสดงแท็บเฉพาะตอนมีรายการค้าง
    final visibleTabs = [
      if (toPay.isNotEmpty) _tabPayout,
      _tabRefund,
      _tabHistory,
    ];
    final current = visibleTabs.contains(selectedTab)
        ? selectedTab
        : _tabRefund;
    final shown = tabs[current];
    const labels = ['โอนผู้ขาย', 'คืนเงิน', 'ประวัติ'];

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'การเงิน (แอดมิน)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: TabSwitch(
              labels: visibleTabs
                  .map(
                    (tab) => tab == _tabHistory
                        ? labels[tab]
                        : '${labels[tab]} (${tabs[tab].length})',
                  )
                  .toList(),
              selectedIndex: visibleTabs.indexOf(current),
              color: kAdminColor,
              fontSize: 16.0,
              onChanged: (int index) {
                setState(() {
                  selectedTab = visibleTabs[index];
                });
              },
            ),
          ),
          Expanded(
            child: isLoading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                      children: [
                        _buildHint(current),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48.0),
                            child: Center(
                              child: Text(
                                [
                                  'ไม่มีรายการที่ต้องโอนให้ผู้ขาย',
                                  'ไม่มีรายการที่ต้องคืนเงิน',
                                  'ยังไม่มีประวัติ',
                                ][current],
                                style: const TextStyle(color: kSubtextColor),
                              ),
                            ),
                          ),
                        ...List.generate(shown.length, (index) {
                          return current == _tabHistory
                              ? _buildHistoryCard(shown[index])
                              : _buildCard(shown[index]);
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(int tab) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: kAdminColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        [
          'ระบบโอนให้ผู้ขายอัตโนมัติ รายการที่ค้างอยู่คือโอนไม่สำเร็จ '
              '(เช่น ผู้ขายยังไม่กรอกบัญชีรับเงิน) แก้แล้วกดโอนใหม่',
          'กดคืนเงิน ระบบจะโอนคืนเข้าช่องทางเดิมที่ผู้ซื้อโอนมา',
          'รายการที่ระบบและแอดมินจัดการเสร็จแล้ว ทั้งชำระเงิน โอนผู้ขาย และคืนเงิน',
        ][tab],
        style: const TextStyle(fontSize: 13.0, color: kNeutralTextColor),
      ),
    );
  }

  bool _isHistory(Order order) {
    return order.status == kOrderHeld ||
        order.status == kOrderReleased ||
        order.status == kOrderRefunded;
  }

  // เวลาของเหตุการณ์ล่าสุด (ใช้เรียงประวัติ)
  DateTime? _historyTime(Order order) {
    if (order.status == kOrderReleased) return order.releasedAt;
    if (order.status == kOrderRefunded) return order.refundedAt;
    return order.paidAt;
  }

  // การ์ดประวัติ: ดูอย่างเดียว (ไม่มีอะไรให้จัดการแล้ว)
  Widget _buildHistoryCard(PaymentItem item) {
    final order = item.order;
    final time = _historyTime(order);

    String label;
    String amountText;
    Color chipColor;
    Color chipText;
    if (order.status == kOrderReleased) {
      label = 'โอนผู้ขายแล้ว';
      amountText = '฿${order.sellerPayout}';
      chipColor = kAdminColor.withValues(alpha: 0.3);
      chipText = kNeutralTextColor;
    } else if (order.status == kOrderRefunded) {
      label = 'คืนเงินแล้ว';
      amountText = '฿${order.amount}';
      chipColor = kAlertBackground;
      chipText = kAlertColor;
    } else {
      label = 'ชำระแล้ว';
      amountText = '฿${order.amount}';
      chipColor = kBuyerSoftColor;
      chipText = kBuyerColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.reference,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                amountText,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'ผู้ซื้อ: ${order.buyerName} · ${item.listing.title}',
            style: const TextStyle(color: kSubtextColor),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: chipText,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  time == null ? '' : thaiDateTime(time),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 13.0, color: kHintColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PaymentItem item) {
    final order = item.order;
    final paidAt = order.paidAt;
    final payoutDeadline = order.payoutDeadline;

    // บรรทัดเวลา: รอโอนผู้ขาย = กำหนดโอน, อื่น ๆ = เวลาชำระเงิน
    String timeText;
    if (order.status == kOrderConfirmed && payoutDeadline != null) {
      final how = order.autoConfirmed
          ? 'ระบบยืนยันให้'
          : order.resolution == kResolutionSeller
          ? 'ตัดสินให้ผู้ขาย'
          : 'ผู้ซื้อยืนยัน';
      timeText = '$how · โอนภายใน ${thaiDateTime(payoutDeadline)}';
    } else {
      timeText = paidAt == null ? '-' : 'ชำระ ${thaiDateTime(paidAt)}';
    }
    final isLate =
        payoutDeadline != null &&
        order.status == kOrderConfirmed &&
        DateTime.now().isAfter(payoutDeadline);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () => _openItem(item),
        child: Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kCardBorderColor),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.reference,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '฿${order.amount}',
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Text(
                'ผู้ซื้อ: ${order.buyerName} · ${item.listing.title}',
                style: const TextStyle(color: kSubtextColor),
              ),
              const SizedBox(height: 2.0),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 13.0,
                  color: isLate ? kAlertColor : kHintColor,
                  fontWeight: isLate ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (order.status == kOrderRejected &&
                  order.rejectReason.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Text(
                  order.rejectReason,
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: kAlertColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
