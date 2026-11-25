import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/home_button.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/components/step_indicator.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/controller/play_controller.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/pages/22_playConfirmedPage.dart';
import 'package:tennis_app/pages/23_reportProblemPage.dart';
import 'package:tennis_app/services/payment_service.dart';
import 'package:tennis_app/services/play_service.dart';

// หน้าสถานะคำสั่งซื้อ (B6) ฝั่งผู้ซื้อ หลังชำระเงินผ่าน Payment Gateway แล้ว
// สแกนจ่ายแล้ว → ตรวจสอบการชำระเงิน (gateway ยืนยัน) → ชำระเงินสำเร็จ (เงินพักที่ Courtswap) → ยืนยันการเล่น
// ชำระเงินสำเร็จแล้ว (B9): ปุ่ม ได้เล่นแล้ว (→ B10) / แจ้งปัญหา (→ B17) กดได้ทันที
// แจ้งปัญหาแล้ว: แจ้งปัญหา → ผู้ขายชี้แจง (24 ชม.) → แอดมินตัดสิน → คืนเงิน / โอนให้ผู้ขาย
// ระหว่างรอแอดมิน หน้านี้โหลดสถานะใหม่เองทุก 5 วินาที
class PaymentStatusPage extends StatefulWidget {
  const PaymentStatusPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  PaymentController controller = PaymentController(PaymentSupabaseService());
  PlayController playController = PlayController(PlaySupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  Timer? _pollTimer;

  PaymentItem? item;
  bool loadFailed = false;
  bool isSaving = false;
  String? proofUrl; // หลักฐานการจองของผู้ขาย (ดูได้หลังชำระเงินสำเร็จ)
  String?
  sellerFullName; // ชื่อ-นามสกุลเต็มของผู้ขาย (ยังไม่โหลด = ใช้ชื่อย่อในประกาศ)

  @override
  void initState() {
    super.initState();
    _syncSubscription = playController.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSaving = syncState;
      });
    });
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // โหลดใหม่เฉพาะตอนที่สถานะยังรอแอดมินหรือรอผู้ขายอยู่
      final status = item?.order.status;
      if (status == kOrderRejected || status == kOrderDisputed) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _syncSubscription?.cancel();
    controller.dispose();
    playController.dispose();
    super.dispose();
  }

  // ยืนยันว่าได้เล่นแล้ว (B9 → B10)
  Future<void> _confirmPlay(PaymentItem current) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('ยืนยันว่าได้เล่นแล้ว?'),
          content: const Text(
            'หลังยืนยัน Courtswap จะโอนเงินให้ผู้ขาย และแจ้งปัญหาไม่ได้อีก',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await playController.confirmPlay(current.order);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(paymentErrorText(error))));
      return;
    }
    // ยืนยันแล้ว ฐานข้อมูลสั่งโอนเงินให้ผู้ขายเอง (schema.sql หัวข้อ 20)
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayConfirmedPage(item: current)),
    );
    if (!mounted) return;
    _load();
  }

  // แจ้งปัญหา (B17) กลับมาแล้วโหลดสถานะใหม่
  Future<void> _reportProblem(PaymentItem current) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReportProblemPage(item: current)),
    );
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await controller.fetchOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        item = result;
        loadFailed = false;
      });
      _loadProof(result);
      _loadSellerName(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadFailed = true;
      });
    }
  }

  // ขอชื่อเต็มของผู้ขายครั้งเดียว
  Future<void> _loadSellerName(PaymentItem current) async {
    if (sellerFullName != null) return;
    try {
      final name = await controller.getSellerFullName(current.order);
      if (!mounted || name == null) return;
      setState(() {
        sellerFullName = name;
      });
    } catch (error) {
      // โหลดไม่ได้ก็ใช้ชื่อย่อในประกาศไปก่อน
    }
  }

  // ขอลิงก์รูปหลักฐานการจองครั้งเดียว เมื่อชำระเงินสำเร็จแล้ว
  Future<void> _loadProof(PaymentItem current) async {
    if (proofUrl != null ||
        !current.order.isPaid ||
        !current.listing.hasProof) {
      return;
    }
    try {
      final url = await controller.getProofUrl(current.listing);
      if (!mounted) return;
      setState(() {
        proofUrl = url;
      });
    } catch (error) {
      // โหลดไม่ได้ก็ไม่แสดงรูป หน้าอื่นยังใช้ได้ปกติ
    }
  }

  // กลับหน้าหลัก แท็บที่อยากให้เปิด (kTabHome = หน้าหลัก, kTabMine = การซื้อของฉัน)
  void _goHome(int tab) {
    final home = context.read<HomeModel>();
    if (tab == kTabMine) {
      home.openMyPurchases();
    } else {
      home.selectedTab = tab;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final current = item;

    // กดย้อนกลับ = กลับหน้าหลักเลย (ไม่ย้อนไปหน้ารายละเอียดประกาศที่ซื้อไปแล้ว)
    return PopScope(
      canPop: false,
      // ลูกศร/ปุ่ม back ของเครื่อง = ไปแท็บการซื้อของฉัน (ไม่ย้อนไปหน้าชำระเงินที่จบแล้ว)
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goHome(kTabMine);
        }
      },
      child: Scaffold(
        backgroundColor: kPageColor,
        appBar: AppBar(
          backgroundColor: kPageColor,
          surfaceTintColor: kPageColor,
          // ไม่มีลูกศร back ใช้ปุ่มกลับหน้าหลักด้านล่างแทน
          automaticallyImplyLeading: false,
          title: const Text(
            'สถานะคำสั่งซื้อ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1.0, color: kDividerColor),
          ),
        ),
        body: current == null
            ? Center(
                child: loadFailed
                    ? TextButton(
                        onPressed: _load,
                        child: const Text('โหลดไม่สำเร็จ แตะเพื่อลองใหม่'),
                      )
                    : const CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSummary(current),
                    const SizedBox(height: 16.0),
                    if (_buildResultBox(current) case final box?) ...[
                      box,
                      const SizedBox(height: 16.0),
                    ],
                    if (current.order.isPaid && proofUrl != null) ...[
                      _buildProof(proofUrl!),
                      const SizedBox(height: 16.0),
                    ],
                    _buildSteps(current),
                  ],
                ),
              ),
        // ปุ่มด้านล่าง: ปุ่มของขั้นนั้น (แจ้งปัญหา + ได้เล่นแล้ว)
        // + ปุ่มกลับหน้าหลักเสมอ (แทนลูกศร back ด้านบน)
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kDividerColor)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildBottomButtons(current),
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่มของขั้นปัจจุบัน (ไม่มี = null) ขนาดเล็กกว่าปุ่มกลับหน้าหลัก
  Widget? _buildStepAction(PaymentItem? current) {
    if (current == null) return null;
    if (current.canConfirmPlay) {
      return Row(
        children: [
          Expanded(
            child: SellerButton(
              label: 'แจ้งปัญหา',
              outlined: true,
              height: 44.0,
              fontSize: 15.0,
              onPressed: isSaving ? null : () => _reportProblem(current),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 2,
            child: BuyerButton(
              label: 'ได้เล่นแล้ว',
              height: 44.0,
              fontSize: 15.0,
              isLoading: isSaving,
              onPressed: () => _confirmPlay(current),
            ),
          ),
        ],
      );
    }
    return null;
  }

  // ปุ่มกลับหน้าหลัก (เต็มความกว้าง ขนาดเท่าปุ่มอื่น) อยู่บนสุด ปุ่มของขั้นนั้นย่อลงไว้ข้างใต้
  Widget _buildBottomButtons(PaymentItem? current) {
    final action = _buildStepAction(current);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HomeButton(onPressed: () => _goHome(kTabHome)),
        if (action != null) ...[const SizedBox(height: 12.0), action],
      ],
    );
  }

  // หลักฐานการจองที่ผู้ขายแนบไว้ ใช้แสดงกับสนามตอนไปเล่น กดแล้วดูเต็มจอ (ซูมได้)
  Widget _buildProof(String url) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(
            'หลักฐานการจอง',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'แสดงหลักฐานนี้กับสนามตอนไปเล่น แตะเพื่อดูเต็มจอ',
            style: TextStyle(fontSize: 13.0, color: kSubtextColor),
          ),
          const SizedBox(height: 12.0),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  insetPadding: const EdgeInsets.all(12.0),
                  child: InteractiveViewer(
                    maxScale: 5.0,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              );
            },
            child: Container(
              height: 240.0,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: kNeutralSoftColor,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'โหลดรูปไม่สำเร็จ ดึงลงเพื่อลองใหม่',
                      style: TextStyle(color: kHintColor),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(PaymentItem item) {
    final details = item.listing.details.trim();
    final sellerName = (sellerFullName ?? item.listing.sellerName).trim();
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
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
                      item.order.reference,
                      style: const TextStyle(fontSize: 12.0, color: kHintColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '฿${item.order.amount}',
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (sellerName.isNotEmpty || details.isNotEmpty)
            const Divider(height: 24.0, color: kSoftDividerColor),
          // ชื่อ-นามสกุลเต็มของผู้ขาย (ระหว่างโหลดแสดงชื่อย่อในประกาศ)
          if (sellerName.isNotEmpty)
            Row(
              children: [
                const Text(
                  'ผู้ขาย',
                  style: TextStyle(fontSize: 13.0, color: kHintColor),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    sellerName,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          if (sellerName.isNotEmpty && details.isNotEmpty)
            const SizedBox(height: 10.0),
          // รายละเอียดที่ผู้ขายกรอกตอนลงประกาศ (ไม่ได้กรอก = ไม่แสดง)
          if (details.isNotEmpty) ...[
            const Text(
              'รายละเอียด',
              style: TextStyle(fontSize: 13.0, color: kHintColor),
            ),
            const SizedBox(height: 4.0),
            Text(
              details,
              style: const TextStyle(color: kNeutralTextColor, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  // กล่องสรุปผลด้านบน เปลี่ยนตามสถานะ (null = ไม่ต้องแสดงกล่อง)
  Widget? _buildResultBox(PaymentItem item) {
    final order = item.order;
    final status = order.status;

    IconData icon;
    String title;
    String message;
    Color background;
    Color border;

    if (status == kOrderDisputed) {
      icon = Icons.report_problem_outlined;
      title = 'แจ้งปัญหาแล้ว';
      message = order.hasEvidence
          ? 'ผู้ขายส่งคำชี้แจงแล้ว แอดมินกำลังตรวจสอบและจะแจ้งผลตัดสิน '
                'เงินยังพักไว้ที่ Courtswap'
          : 'รอผู้ขายชี้แจงภายใน $kEvidenceHours ชม. ถ้าผู้ขายไม่ชี้แจง '
                'ระบบจะคืนเงินให้คุณ';
      background = kAlertBackground;
      border = kAlertColor;
    } else if (status == kOrderRejected && order.wasDisputed) {
      icon = Icons.gavel;
      title = 'ผลตัดสิน: คืนเงินให้คุณ';
      message = '${order.rejectReason}\nแอดมินกำลังคืนเงินเข้าบัญชีที่คุณโอนมา';
      background = kAlertBackground;
      border = kAlertColor;
    } else if (status == kOrderRejected) {
      icon = Icons.error_outline;
      title = 'การชำระเงินไม่ผ่าน';
      message =
          '${order.rejectReason.isEmpty ? 'ตรวจสอบยอดเงินไม่ผ่าน' : order.rejectReason}\n'
          'แอดมินกำลังคืนเงินเข้าบัญชีที่คุณโอนมา';
      background = kAlertBackground;
      border = kAlertColor;
    } else if (status == kOrderRefunded) {
      icon = Icons.replay;
      title = 'คืนเงินแล้ว';
      message =
          'คืนเงิน ฿${order.amount} เข้าบัญชีที่คุณโอนมา'
          '${order.refundedAt == null ? '' : ' เมื่อ ${thaiDateTime(order.refundedAt!)}'}';
      background = kMutedColor;
      border = kCardBorderColor;
    } else if (status == kOrderConfirmed || status == kOrderReleased) {
      icon = Icons.sports_tennis;
      if (order.resolution == kResolutionSeller) {
        title = 'ผลตัดสิน: โอนเงินให้ผู้ขาย';
        message = order.resolutionNote.isEmpty
            ? 'แอดมินตรวจสอบแล้ว ผู้ขายส่งมอบสนามถูกต้อง'
            : order.resolutionNote;
      } else {
        title = 'ยืนยันการเล่นแล้ว';
        message = order.autoConfirmed
            ? 'ระบบยืนยันให้อัตโนมัติ เพราะไม่มีการแจ้งปัญหาภายใน '
                  '$kConfirmHours ชม. หลังเล่นจบ'
            : 'ขอบคุณที่ใช้ Courtswap เงินจะโอนให้ผู้ขายต่อไป';
      }
      background = kBuyerColor.withValues(alpha: 0.2);
      border = kBorderColor;
    } else if (item.canConfirmPlay && item.hasStarted) {
      icon = Icons.timer_outlined;
      title = 'ได้เล่นแล้วหรือยัง?';
      message =
          'กดยืนยันถ้าได้เล่นตามนัด หรือแจ้งปัญหาถ้าเข้าใช้สนามไม่ได้ '
          'ภายใน ${thaiDateTime(item.confirmDeadline)} '
          '(ไม่กดอะไร ระบบจะยืนยันให้อัตโนมัติ)';
      background = kBuyerSoftColor;
      border = kBorderColor;
    } else if (order.isPaid) {
      // ชำระเงินสำเร็จ รอวันเล่น: ไม่ต้องมีกล่อง ขั้นตอนด้านล่างบอกอยู่แล้ว
      return null;
    } else {
      // หมดเวลา / ยกเลิก / ยังไม่ได้ชำระ
      icon = Icons.info_outline;
      title = item.buyerStatusLabel;
      message = 'คำสั่งซื้อนี้ปิดแล้ว ประกาศถูกปลดล็อกให้คนอื่นซื้อได้';
      background = kMutedColor;
      border = kCardBorderColor;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(icon, color: border == kBorderColor ? kBorderColor : null),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    message,
                    style: const TextStyle(color: kSubtextColor, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ขั้นตอนแนวตั้ง (วงกลมแบบเดียวกับหน้าลงประกาศ แต่เป็นสีฝั่งซื้อ)
  Widget _buildSteps(PaymentItem item) {
    final order = item.order;
    final status = order.status;
    final paidAt = order.paidAt;

    List<List<String>> steps;
    int current;
    // ขั้นปัจจุบันยังรอผู้ซื้อทำ (เช่น ยังไม่กดยืนยันการเล่น) = วงกลมเป็นสีเทา ยังไม่เป็นสีเขียว
    bool currentWaiting = false;

    if (order.wasDisputed) {
      // เส้นทางข้อพิพาท
      final favorBuyer = order.resolution == kResolutionBuyer;
      final evidenceAt = order.evidenceAt;
      steps = [
        ['ชำระเงินสำเร็จ', 'เงินพักไว้ที่ Courtswap'],
        [
          'แจ้งปัญหา',
          '${order.problemSummary} · ${thaiDateTime(order.disputedAt!)}',
        ],
        [
          'ผู้ขายชี้แจง',
          evidenceAt != null
              ? 'ส่งหลักฐานแล้ว ${thaiDateTime(evidenceAt)}'
              : 'ภายใน ${thaiDateTime(order.evidenceDeadline!)}',
        ],
        [
          'แอดมินตัดสิน',
          order.resolution == null
              ? 'รอผลตัดสิน'
              : (favorBuyer ? 'คืนเงินให้คุณ' : 'โอนเงินให้ผู้ขาย'),
        ],
        [
          favorBuyer ? 'คืนเงิน' : 'ปิดเรื่อง',
          status == kOrderRefunded ? 'คืนเงินเรียบร้อย' : '',
        ],
      ];
      if (status == kOrderRefunded ||
          status == kOrderConfirmed ||
          status == kOrderReleased) {
        current = 5;
      } else if (status == kOrderRejected) {
        current = 4;
      } else if (order.hasEvidence) {
        current = 3;
      } else {
        // ผู้ขายยังไม่ชี้แจง = วงกลมขั้นที่ 3 ยังเป็นสีเทา (แต่ยังเห็นกำหนดเวลาชี้แจง)
        current = 2;
        currentWaiting = true;
      }
    } else if (status == kOrderRejected || status == kOrderRefunded) {
      steps = [
        ['ชำระเงินแล้ว', paidAt == null ? '' : thaiDateTime(paidAt)],
        ['ไม่ผ่านการตรวจสอบ', order.rejectReason],
        [
          'คืนเงิน',
          status == kOrderRefunded ? 'คืนเงินเรียบร้อย' : 'แอดมินกำลังโอนคืน',
        ],
      ];
      current = status == kOrderRefunded ? 3 : 2;
    } else {
      steps = [
        ['สแกนจ่ายแล้ว', paidAt == null ? '' : thaiDateTime(paidAt)],
        ['ตรวจสอบการชำระเงิน', 'Payment Gateway ยืนยันยอดเงินแล้ว'],
        ['ชำระเงินสำเร็จ', 'เงินพักไว้ที่ Courtswap'],
        [
          'ยืนยันการเล่น',
          order.confirmedAt != null
              ? thaiDateTime(order.confirmedAt!)
              : 'เล่น ${item.listing.scheduleText} แล้วกดยืนยัน '
                    '(ภายใน $kConfirmHours ชม. หลังเล่นจบ)',
        ],
      ];
      if (status == kOrderHeld) {
        current = 3;
        currentWaiting = true;
      } else if (order.isPaid) {
        current = 4;
      } else {
        current = 0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(
            'ขั้นตอน',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16.0),
          ...List.generate(steps.length, (index) {
            return _buildStepRow(
              index: index,
              current: current,
              currentWaiting: currentWaiting,
              title: steps[index][0],
              subtitle: steps[index][1],
              isLast: index == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required int index,
    required int current,
    required bool currentWaiting,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    // ขั้นที่รอผู้ซื้อ: วงกลมสีเทาแบบขั้นที่ยังไม่ถึง แต่ข้อความยังเข้มให้อ่านคำแนะนำได้
    final isWaiting = currentWaiting && index == current;
    final isActive = index <= current;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Column(
            children: [
              StepDot(
                number: index + 1,
                step: index,
                // รอผู้ซื้อ = ส่งขั้นก่อนหน้าเป็นขั้นปัจจุบัน วงกลมนี้จะเป็นสีเทา
                currentStep: isWaiting ? current - 1 : current,
                color: kBuyerColor,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    color: index < current ? kBorderColor : kDividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: isLast ? 0.0 : 20.0),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? kBorderColor : kHintColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.0,
                        color: isActive ? kSubtextColor : kDisabledColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
