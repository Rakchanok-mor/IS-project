import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/tab_switch.dart';
import 'package:tennis_app/controller/play_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/pages/29_adminDisputeDetailPage.dart';
import 'package:tennis_app/services/play_service.dart';

// หน้าข้อพิพาทของแอดมิน (U6): รอผู้ขายชี้แจง / รอตัดสิน / ปิดแล้ว
// เข้าได้จากแท็บบัญชี (เห็นปุ่มเฉพาะคนที่เป็นแอดมิน)
class AdminDisputeListPage extends StatefulWidget {
  const AdminDisputeListPage({super.key});

  @override
  State<AdminDisputeListPage> createState() => _AdminDisputeListPageState();
}

class _AdminDisputeListPageState extends State<AdminDisputeListPage> {
  PlayController controller = PlayController(PlaySupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  List<PaymentItem> items = List.empty();
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
      await controller.fetchDisputes();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โหลดไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      items = controller.disputes;
    });
  }

  Future<void> _openItem(PaymentItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminDisputeDetailPage(item: item),
      ),
    );
    if (!mounted) return;
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final open = items.where((item) => item.order.resolution == null);
    final waitingSeller = open
        .where((item) => !item.order.hasEvidence)
        .toList();
    final toDecide = open.where((item) => item.order.hasEvidence).toList();
    final closed = items
        .where((item) => item.order.resolution != null)
        .toList();
    final List<List<PaymentItem>> tabs = [toDecide, waitingSeller, closed];
    final shown = tabs[selectedTab];

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'ข้อพิพาท (แอดมิน)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: TabSwitch(
              labels: [
                'รอตัดสิน (${toDecide.length})',
                'รอผู้ขาย (${waitingSeller.length})',
                'ปิดแล้ว',
              ],
              selectedIndex: selectedTab,
              color: kAdminColor,
              onChanged: (int index) {
                setState(() {
                  selectedTab = index;
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
                        if (shown.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48.0),
                            child: Center(
                              child: Text(
                                'ไม่มีข้อพิพาทในหมวดนี้',
                                style: TextStyle(color: kSubtextColor),
                              ),
                            ),
                          ),
                        ...List.generate(shown.length, (index) {
                          return _buildCard(shown[index]);
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PaymentItem item) {
    final order = item.order;
    final isOpen = order.resolution == null;

    // บรรทัดเวลา: รอผู้ขาย = เหลือเวลาเท่าไร, ที่เหลือ = เวลาแจ้งปัญหา
    String timeText;
    if (isOpen && !order.hasEvidence) {
      timeText = 'ผู้ขายชี้แจงภายใน ${thaiDateTime(order.evidenceDeadline!)}';
    } else if (order.resolvedAt != null) {
      timeText = 'ตัดสินเมื่อ ${thaiDateTime(order.resolvedAt!)}';
    } else {
      timeText = 'แจ้งเมื่อ ${thaiDateTime(order.disputedAt!)}';
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
            border: Border.all(
              color: isOpen ? kAlertColor : kCardBorderColor,
              width: isOpen ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 3.0,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen ? kAlertBackground : kNeutralSoftColor,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      item.disputeStatusLabel,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? kAlertColor : kNeutralTextColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.reference,
                    style: const TextStyle(fontSize: 12.0, color: kHintColor),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.listing.title,
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
              const SizedBox(height: 2.0),
              Text(
                '${order.problemSummary} · ผู้ซื้อ ${order.buyerName}',
                style: const TextStyle(color: kSubtextColor),
              ),
              const SizedBox(height: 2.0),
              Text(
                timeText,
                style: const TextStyle(fontSize: 13.0, color: kHintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
