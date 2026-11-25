import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/controller/play_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/payout_account_model.dart';
import 'package:tennis_app/models/transfer_model.dart';
import 'package:tennis_app/pages/21_refundSuccessPage.dart';
import 'package:tennis_app/pages/27_payoutSuccessPage.dart';
import 'package:tennis_app/services/payment_service.dart';
import 'package:tennis_app/services/play_service.dart';

// หน้าโอนผู้ขาย / คืนเงินของแอดมิน (U4) ทั้งสองแบบโอนผ่าน Payment Gateway
// รอโอนผู้ขาย (confirmed): โอนเข้าบัญชีรับเงินของผู้ขาย → U2
// รอคืนเงิน (rejected): คืนเข้าช่องทางเดิมที่ผู้ซื้อจ่ายมา → แจ้งผู้ซื้อ + ปลดล็อกประกาศ
class AdminOrderPage extends StatefulWidget {
  const AdminOrderPage({super.key, required this.item});

  final PaymentItem item;

  @override
  State<AdminOrderPage> createState() => _AdminOrderPageState();
}

class _AdminOrderPageState extends State<AdminOrderPage> {
  PaymentController controller = PaymentController(PaymentSupabaseService());
  PlayController playController = PlayController(PlaySupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  StreamSubscription<bool>? _playSyncSubscription;
  bool isSaving = false;

  PayoutAccount? payoutAccount; // บัญชีรับเงินของผู้ขาย (หน้าโอนผู้ขาย)
  bool payoutLoaded = false;
  Transfer?
  lastTransfer; // รายการโอนล่าสุดผ่าน Payment Gateway (คืนเงิน / โอนผู้ขาย)

  PaymentItem get item => widget.item;
  Order get order => widget.item.order;
  bool get isPayout => order.status == kOrderConfirmed;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen(_onSync);
    _playSyncSubscription = playController.onSync.listen(_onSync);
    if (isPayout) {
      _loadPayoutAccount();
    }
    _loadLastTransfer();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _playSyncSubscription?.cancel();
    controller.dispose();
    playController.dispose();
    super.dispose();
  }

  void _onSync(bool syncState) {
    if (!mounted) return;
    setState(() {
      isSaving = syncState;
    });
  }

  Future<void> _loadPayoutAccount() async {
    try {
      final account = await playController.getSellerPayoutAccount(order);
      if (!mounted) return;
      setState(() {
        payoutAccount = account;
        payoutLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        payoutLoaded = true;
      });
    }
  }

  // รายการโอนล่าสุด (โชว์เหตุผลถ้าโอนไม่สำเร็จ / กำลังโอนอยู่)
  Future<void> _loadLastTransfer() async {
    final kind = isPayout ? kTransferPayout : kTransferRefund;
    try {
      final transfer = await controller.getLatestTransfer(order, kind);
      if (!mounted) return;
      setState(() {
        lastTransfer = transfer;
      });
    } catch (error) {
      // ไม่มีข้อมูลก็กดโอนได้ตามปกติ
    }
  }

  Future<bool> _confirm(String title, String content, String okLabel) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(okLabel),
            ),
          ],
        );
      },
    );
    return confirm == true;
  }

  // โอนผ่าน Payment Gateway แล้วไปหน้าสำเร็จ / แสดงเหตุผลถ้าไม่สำเร็จ
  // คืน false = ยังไม่สำเร็จ (ไม่สำเร็จ หรือยังรอผลอยู่)
  Future<bool> _transfer(String kind) async {
    Transfer transfer;
    try {
      transfer = await controller.transferAndWait(order, kind);
    } catch (error) {
      if (!mounted) return false;
      _showMessage(paymentErrorText(error));
      return false;
    }
    if (!mounted) return false;

    if (transfer.isSucceeded) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => kind == kTransferRefund
              ? RefundSuccessPage(item: item, transfer: transfer)
              : PayoutSuccessPage(
                  item: item,
                  account: payoutAccount!,
                  transfer: transfer,
                ),
        ),
      );
      return true;
    }

    setState(() {
      lastTransfer = transfer;
    });
    _showMessage(
      transfer.isFailed
          ? 'โอนไม่สำเร็จ: ${transfer.failureReason}'
          : 'ส่งคำสั่งโอนแล้ว กำลังรอผลจาก Payment Gateway',
    );
    return false;
  }

  // โอนเงินให้ผู้ขายผ่าน Payment Gateway (U1 → U2)
  // ปกติระบบโอนให้เองตอนผู้ซื้อกด "ได้เล่นแล้ว" ปุ่มนี้ใช้กับกรณีอื่น
  // (ระบบยืนยันให้ / ผลตัดสินข้อพิพาท / โอนอัตโนมัติไม่สำเร็จ)
  Future<void> _release() async {
    final ok = await _confirm(
      'โอน ฿${order.sellerPayout} ให้ผู้ขาย?',
      'ราคาขาย ฿${order.amount} หักค่าธรรมเนียม ฿$kPlatformFee\n'
          'โอนเข้า ${payoutAccount?.bankName ?? ''} ${payoutAccount?.maskedNumber ?? ''} '
          'ผ่าน Payment Gateway',
      'โอนเงิน',
    );
    if (!ok) return;
    await _transfer(kTransferPayout);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // คืนเงินผู้ซื้อผ่าน Payment Gateway เข้าช่องทางเดิมที่ผู้ซื้อโอนมา
  Future<void> _refund() async {
    final ok = await _confirm(
      'คืนเงิน ฿${order.amount} ให้ผู้ซื้อ?',
      'โอนคืนเข้าช่องทางเดิมที่ผู้ซื้อโอนมา ผ่าน Payment Gateway\n'
          'สำเร็จแล้วระบบจะแจ้งผู้ซื้อและปลดล็อกประกาศให้คนอื่นซื้อได้',
      'คืนเงิน',
    );
    if (!ok) return;
    await _transfer(kTransferRefund);
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = order.status == kOrderRejected;
    final paidAt = order.paidAt;

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: Text(
          isPayout ? 'โอนเงินให้ผู้ขาย' : 'คืนเงิน',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (isRejected) ...[
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: kAlertBackground,
                border: Border.all(color: kAlertColor, width: 1.5),
                borderRadius: BorderRadius.circular(16.0),
              ),
              // แจ้งแค่ผลการตัดสิน (ข้อพิพาท: เหตุผลมีคำว่าผลตัดสินอยู่แล้ว)
              child: Text(
                order.wasDisputed
                    ? order.rejectReason
                    : 'ไม่ผ่าน: ${order.rejectReason}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kAlertColor,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          // ผลโอนรอบก่อน: ไม่สำเร็จ (กดโอนใหม่ได้) / กำลังโอน
          if (lastTransfer case final transfer? when !transfer.isSucceeded) ...[
            _buildTransferStatus(transfer),
            const SizedBox(height: 16.0),
          ],
          if (isPayout) ...[
            _buildPayoutAccount(),
            const SizedBox(height: 16.0),
          ],
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border.all(color: kCardBorderColor),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                _buildRow('เลขที่คำสั่งซื้อ', order.reference),
                _buildRow('ยอดที่ต้องชำระ', '฿${order.amount}.00'),
                if (isPayout) ...[
                  _buildRow('ค่าธรรมเนียมแพลตฟอร์ม', '-฿$kPlatformFee'),
                  _buildRow('ยอดโอนให้ผู้ขาย', '฿${order.sellerPayout}'),
                ],
                _buildRow('ผู้ซื้อ', order.buyerName),
                _buildRow('สนาม', item.listing.title),
                _buildRow('วันเวลาเล่น', item.listing.scheduleText),
                _buildRow(
                  'ชำระเมื่อ',
                  paidAt == null ? '-' : thaiDateTime(paidAt),
                ),
                if (isPayout && order.payoutDeadline != null)
                  _buildRow(
                    'ต้องโอนภายใน',
                    thaiDateTime(order.payoutDeadline!),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isPayout
                ? SellerButton(
                    label: 'โอน ฿${order.sellerPayout} ให้ผู้ขาย',
                    color: kAdminColor,
                    isLoading: isSaving,
                    // ผู้ขายยังไม่กรอกบัญชีรับเงิน / กำลังโอนอยู่ = กดไม่ได้
                    onPressed:
                        payoutAccount == null ||
                            (lastTransfer?.isProcessing ?? false)
                        ? null
                        : _release,
                  )
                : SellerButton(
                    label: 'คืนเงิน ฿${order.amount}',
                    color: kAdminColor,
                    isLoading: isSaving,
                    onPressed: (lastTransfer?.isProcessing ?? false)
                        ? null
                        : _refund,
                  ),
          ),
        ),
      ),
    );
  }

  // กล่องผลโอนรอบก่อน (Payment Gateway)
  Widget _buildTransferStatus(Transfer transfer) {
    final failed = transfer.isFailed;
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: failed ? kAlertBackground : kMutedColor,
        border: Border.all(
          color: failed ? kAlertColor : kCardBorderColor,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Text(
        failed
            ? 'โอนรอบก่อนไม่สำเร็จ: ${transfer.failureReason}\nแก้ไขแล้วกดโอนใหม่ได้'
            : 'กำลังโอน ฿${transfer.amount} รอผลจาก Payment Gateway\n'
                  '${transfer.gatewayRef}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: failed ? kAlertColor : kNeutralTextColor,
          height: 1.5,
        ),
      ),
    );
  }

  // บัญชีรับเงินของผู้ขาย (กดค้างที่เลขบัญชีเพื่อคัดลอกได้)
  Widget _buildPayoutAccount() {
    if (!payoutLoaded) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final account = payoutAccount;
    if (account == null) {
      return Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: kAlertBackground,
          border: Border.all(color: kAlertColor, width: 1.5),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Text(
          'ผู้ขายยังไม่ได้กรอกบัญชีรับเงิน\n'
          'ติดต่อผู้ขายให้กรอกที่ แท็บบัญชี > บัญชีรับเงิน ก่อนโอน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kAlertColor,
            height: 1.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kAdminColor.withValues(alpha: 0.25),
        border: Border.all(color: kBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(
            'บัญชีรับเงินของผู้ขาย',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          _buildRow('ธนาคาร', account.bankName),
          _buildRow('ชื่อบัญชี', account.accountName),
          SelectableText(
            account.accountNumber,
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Text(label, style: const TextStyle(color: kHintColor)),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
