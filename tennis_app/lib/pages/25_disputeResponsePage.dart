import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/attach_image_box.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/controller/order_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/pages/26_evidenceSentPage.dart';
import 'package:tennis_app/services/order_service.dart';
import 'package:tennis_app/services/payment_service.dart';

// หน้าชี้แจงข้อพิพาท (A13) ฝั่งผู้ขาย
// เห็นปัญหาที่ผู้ซื้อแจ้ง + เวลาที่เหลือ (นับถอยหลัง 24 ชม.)
// เขียนคำชี้แจง + แนบรูปหลักฐาน เช่น แชท LINE กับสนาม ใบยืนยันการจอง → A14
class DisputeResponsePage extends StatefulWidget {
  const DisputeResponsePage({super.key, required this.item});

  final SellerListing item;

  @override
  State<DisputeResponsePage> createState() => _DisputeResponsePageState();
}

class _DisputeResponsePageState extends State<DisputeResponsePage> {
  OrderController controller = OrderController(OrderSupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  TextEditingController noteController = TextEditingController();
  Timer? _timer;

  bool isSending = false;
  Duration timeLeft = Duration.zero;
  Uint8List? evidenceBytes;
  String evidenceFileName = '';

  SellerListing get item => widget.item;
  Order get order => widget.item.order!;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSending = syncState;
      });
    });

    // ส่งซ้ำเพื่อแก้ไข: เติมคำชี้แจงเดิมให้
    noteController.text = order.sellerNote;

    // นับถอยหลังทุกวินาที จากเวลาที่ผู้ซื้อแจ้งปัญหา + 24 ชม.
    timeLeft = order.evidenceTimeLeft;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        timeLeft = order.evidenceTimeLeft;
      });
      if (timeLeft.isNegative) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syncSubscription?.cancel();
    controller.dispose();
    noteController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickEvidence() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600.0,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        evidenceBytes = bytes;
        evidenceFileName = file.name;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage('เปิดรูปภาพไม่ได้ (${error.code})');
    }
  }

  Future<void> _send() async {
    final note = noteController.text.trim();
    final bytes = evidenceBytes;
    if (note.isEmpty) {
      _showMessage('กรุณาเขียนคำชี้แจง');
      return;
    }
    if (bytes == null) {
      _showMessage('กรุณาแนบรูปหลักฐานอย่างน้อย 1 รูป');
      return;
    }

    try {
      await controller.submitEvidence(order, note, bytes, evidenceFileName);
    } catch (error) {
      if (!mounted) return;
      _showMessage(paymentErrorText(error));
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => EvidenceSentPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = timeLeft.isNegative;

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: Text(
          'ข้อพิพาท ${order.reference}',
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
          _buildCountdown(isClosed),
          const SizedBox(height: 16.0),
          _buildComplaint(),
          const SizedBox(height: 24.0),
          const Text(
            'คำชี้แจงของคุณ',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: noteController,
            enabled: !isClosed,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 16.0),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16.0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: const BorderSide(color: kBorderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: const BorderSide(color: kBorderColor, width: 2.0),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          AttachImageBox(
            bytes: evidenceBytes,
            fileName: evidenceFileName,
            title: 'แนบหลักฐานเพิ่มเติม',
            onTap: isSending || isClosed ? null : _pickEvidence,
          ),
          const SizedBox(height: 8.0),
          const Text(
            'ส่งได้ครั้งเดียว ส่งแล้วแก้ไขไม่ได้',
            style: TextStyle(fontSize: 13.0, color: kSubtextColor),
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
            child: SellerButton(
              label: isClosed ? 'เลยเวลาส่งหลักฐานแล้ว' : 'ส่งหลักฐาน',
              isLoading: isSending,
              onPressed: isClosed ? null : _send,
            ),
          ),
        ),
      ),
    );
  }

  // กล่องนับถอยหลัง 24 ชม.
  Widget _buildCountdown(bool isClosed) {
    return Container(
      padding: const EdgeInsets.all(16.0),
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
                const Text(
                  'ชี้แจงภายใน',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2.0),
                Text(
                  isClosed
                      ? 'หมดเวลาแล้ว ระบบจะคืนเงินให้ผู้ซื้อ'
                      : 'ไม่ชี้แจง = คืนเงินให้ผู้ซื้ออัตโนมัติ',
                  style: const TextStyle(fontSize: 13.0, color: kSubtextColor),
                ),
              ],
            ),
          ),
          Text(
            countdownText(timeLeft),
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ปัญหาที่ผู้ซื้อแจ้ง
  Widget _buildComplaint() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kAlertBackground,
        border: Border.all(color: kAlertColor, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            order.disputeCategory.isEmpty
                ? 'ผู้ซื้อแจ้งปัญหา'
                : 'ผู้ซื้อแจ้ง: ${order.disputeCategory}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kAlertColor,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            order.disputeReason.isEmpty ? '-' : order.disputeReason,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 8.0),
          Text(
            '${item.listing.title} · ${item.listing.scheduleText}',
            style: const TextStyle(fontSize: 13.0, color: kSubtextColor),
          ),
        ],
      ),
    );
  }
}
