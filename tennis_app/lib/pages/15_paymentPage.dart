import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/controller/mock_bank_controller.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/pages/16_paymentStatusPage.dart';
import 'package:tennis_app/pages/17_paymentTimeoutPage.dart';
import 'package:tennis_app/services/mock_bank_service.dart';
import 'package:tennis_app/services/payment_service.dart';

// หน้าชำระเงิน (B5): QR พร้อมเพย์ที่ Payment Gateway ออกให้คำสั่งซื้อนี้ + เลขที่คำสั่งซื้อ
// ผู้ซื้อสแกนจ่ายภายในเวลาที่ล็อกไว้ (นับถอยหลัง)
// เงินเข้าแล้ว gateway แจ้งระบบเอง (webhook) หน้านี้ถามสถานะซ้ำทุก 3 วินาที → ไปหน้าสถานะ (B6)
// หมดเวลา → ปลดล็อกประกาศ ไปหน้าหมดเวลา (B7)
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.listing, required this.order});

  final Listing listing;
  final Order order;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  PaymentController controller = PaymentController(PaymentSupabaseService());
  // จำลองฝั่งแอปธนาคารของผู้ซื้อ (สแกน QR แล้วโอน)
  MockBankController bankController = MockBankController(
    MockBankSupabaseService(),
  );
  StreamSubscription<bool>? _syncSubscription;
  Timer? _timer;
  Timer? _pollTimer;

  bool isSending = false;
  bool isPaying = false; // กดชำระแล้ว กำลังรอ gateway ยืนยัน
  bool chargeFailed = false;
  bool isLeaving = false; // กำลังไปหน้าอื่นแล้ว กันเปิดหน้าถัดไปซ้ำ
  Duration timeLeft = Duration.zero;
  late Order order;

  Listing get listing => widget.listing;

  @override
  void initState() {
    super.initState();
    order = widget.order;
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSending = syncState;
      });
    });

    // นับถอยหลังทุกวินาที จากเวลาหมดอายุที่ฐานข้อมูลกำหนด
    timeLeft = order.timeLeft;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // ถามสถานะทุก 3 วินาที รอ gateway แจ้งว่าเงินเข้า
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkPaid(),
    );
    _createCharge();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    _syncSubscription?.cancel();
    controller.dispose();
    bankController.dispose();
    super.dispose();
  }

  void _tick() {
    final left = order.timeLeft;
    if (left.isNegative || left == Duration.zero) {
      _timer?.cancel();
      _onTimeout();
      return;
    }
    setState(() {
      timeLeft = left;
    });
  }

  // ขอ QR จาก Payment Gateway (เปิดหน้าซ้ำ = ได้ QR เดิม)
  Future<void> _createCharge() async {
    setState(() {
      chargeFailed = false;
    });
    try {
      final charged = await controller.createCharge(order);
      if (!mounted) return;
      setState(() {
        order = charged;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        chargeFailed = true;
      });
      _showMessage(paymentErrorText(error));
    }
  }

  // เงินเข้าแล้วหรือยัง: ไม่ใช่ "รอชำระ" แล้ว = gateway แจ้งผลแล้ว ไปหน้าสถานะ
  Future<void> _checkPaid() async {
    if (isLeaving || order.chargeId == null) return;
    Order latest;
    try {
      latest = await controller.refreshOrder(order);
    } catch (error) {
      return; // เน็ตหลุดชั่วคราว รอบหน้าถามใหม่
    }
    if (!mounted || isLeaving) return;
    if (latest.status == kOrderPendingPayment) return;
    _goToStatus();
  }

  void _goToStatus() {
    isLeaving = true;
    _timer?.cancel();
    _pollTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentStatusPage(orderId: order.id),
      ),
    );
  }

  // กดชำระเงิน = จำลองว่าผู้ซื้อสแกน QR ด้วยแอปธนาคารแล้วโอน
  // (ของจริงผู้ซื้อสแกนเองนอกแอป) จากนั้นรอ gateway แจ้งผลทาง webhook (~2 วินาที)
  Future<void> _payNow() async {
    final qr = order.chargeQr;
    if (qr == null) return;
    setState(() {
      isPaying = true;
    });
    try {
      final charge = await bankController.scanQr(qr);
      if (!charge.isPaid) {
        await bankController.pay(charge);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isPaying = false;
      });
      _showMessage(mockBankErrorText(error));
      return;
    }

    // ถามสถานะถี่ขึ้น (ทุก 1 วินาที ไม่เกิน 15 วินาที) เงินเข้าแล้วไปหน้าสถานะเอง
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || isLeaving) return;
      await _checkPaid();
      if (!mounted || isLeaving) return;
    }
    setState(() {
      isPaying = false;
    });
    _showMessage('ชำระเงินแล้ว รอระบบยืนยันสักครู่');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // หมดเวลา: ปลดล็อกประกาศ แล้วไปหน้าหมดเวลา
  Future<void> _onTimeout() async {
    if (isLeaving) return;
    // เช็กครั้งสุดท้าย เผื่อจ่ายทันแต่ webhook มาถึงช้า
    await _checkPaid();
    if (!mounted || isLeaving) return;
    isLeaving = true;
    _pollTimer?.cancel();
    try {
      await controller.expireOrder(order);
    } catch (error) {
      // ปลดล็อกไม่สำเร็จก็ไม่เป็นไร ฐานข้อมูลจะปลดเองเมื่อมีคนกดซื้อครั้งถัดไป
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentTimeoutPage(listing: listing, order: order),
      ),
    );
  }

  // กดออกจากหน้า = ถามก่อนว่าจะยกเลิกคำสั่งซื้อไหม
  Future<void> _askCancel() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('ยกเลิกคำสั่งซื้อ?'),
          content: const Text(
            'ระบบจะปลดล็อกประกาศให้คนอื่นซื้อได้ ถ้าสแกนจ่ายไปแล้ว รอระบบยืนยันสักครู่',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ชำระต่อ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'ยกเลิกคำสั่งซื้อ',
                style: TextStyle(color: kAlertColor),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await controller.cancelOrder(order);
    } catch (error) {
      if (!mounted) return;
      _showMessage('ยกเลิกไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;
    isLeaving = true;
    _timer?.cancel();
    _pollTimer?.cancel();
    // ยกเลิกแล้วกลับหน้าหลัก (ปิดหน้ารายละเอียดด้วย) หน้าหลักจะโหลดประกาศใหม่
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !isSending && !isPaying) {
          _askCancel();
        }
      },
      child: Scaffold(
        backgroundColor: kPageColor,
        appBar: AppBar(
          backgroundColor: kPageColor,
          surfaceTintColor: kPageColor,
          title: const Text(
            'ชำระเงิน',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1.0, color: kDividerColor),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildCountdown(),
            const SizedBox(height: 16.0),
            _buildQrCard(),
            const SizedBox(height: 8.0),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kDividerColor)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // ของจริงผู้ซื้อสแกนด้วยแอปธนาคารเอง ปุ่มนี้จำลองการสแกนจ่าย
              child: BuyerButton(
                label: 'ชำระเงิน',
                isLoading: isSending || isPaying,
                onPressed: order.chargeQr == null ? null : _payNow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // แถบนับถอยหลัง ใกล้หมดเวลา (ไม่ถึง 5 นาที) เปลี่ยนเป็นสีแดง
  Widget _buildCountdown() {
    final minutes = timeLeft.inMinutes.toString().padLeft(2, '0');
    final seconds = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');
    final isUrgent = timeLeft.inMinutes < 5;
    final color = isUrgent ? kAlertColor : kBorderColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isUrgent ? kAlertBackground : kBuyerColor.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: color),
          const SizedBox(width: 12.0),
          const Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'ล็อกประกาศไว้ให้คุณแล้ว',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.0),
                Text(
                  'สแกนจ่ายก่อนหมดเวลา ระบบยืนยันให้อัตโนมัติ',
                  style: TextStyle(fontSize: 13.0, color: kSubtextColor),
                ),
              ],
            ),
          ),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
              fontSize: 26.0,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // QR จาก gateway: กำลังขอ / ขอไม่สำเร็จ (กดลองใหม่) / พร้อมสแกน
  Widget _buildQr() {
    final qr = order.chargeQr;
    if (qr != null) {
      return QrImageView(data: qr, size: 200.0, backgroundColor: Colors.white);
    }
    if (chargeFailed) {
      return SizedBox(
        height: 200.0,
        child: Center(
          child: TextButton.icon(
            onPressed: _createCharge,
            icon: const Icon(Icons.refresh),
            label: const Text('สร้าง QR อีกครั้ง'),
          ),
        ),
      );
    }
    return const SizedBox(
      height: 200.0,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // QR พร้อมเพย์ + ข้อมูลคำสั่งซื้อ
  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          const Text(
            'Thai QR PromptPay',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2.0),
          const Text(
            'รับชำระผ่าน Payment Gateway (จำลอง)',
            style: TextStyle(color: kSubtextColor),
          ),
          const SizedBox(height: 12.0),
          _buildQr(),
          const SizedBox(height: 4.0),
          const Text(
            'QR นี้ใช้ได้กับคำสั่งซื้อนี้เท่านั้น ยอดเงินและเลขที่คำสั่งซื้ออยู่ใน QR แล้ว',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: kHintColor),
          ),
          const Divider(height: 28.0, color: kDividerColor),
          _buildRow(
            'ยอดชำระ',
            Text(
              '฿${order.amount}.00',
              style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildRow('เลขที่คำสั่งซื้อ', _buildReference()),
          _buildRow(
            'สนาม',
            Text(
              listing.title,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _buildRow(
            'วันเวลา',
            Text(
              listing.scheduleText,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // เลขที่คำสั่งซื้อ กดแล้วคัดลอก (เอาไปใส่ในบันทึกช่วยจำตอนโอนได้)
  Widget _buildReference() {
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: order.reference));
        if (!mounted) return;
        _showMessage('คัดลอกเลขที่คำสั่งซื้อแล้ว');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            order.reference,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4.0),
          const Icon(Icons.copy, size: 16.0, color: kHintColor),
        ],
      ),
    );
  }

  Widget _buildRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: kHintColor)),
          const SizedBox(width: 16.0),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }
}
