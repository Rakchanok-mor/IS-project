import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/attach_image_box.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/controller/play_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/pages/24_reportSentPage.dart';
import 'package:tennis_app/services/payment_service.dart';
import 'package:tennis_app/services/play_service.dart';

// หน้าแจ้งปัญหาการใช้สนาม (B17) ฝั่งผู้ซื้อ
// เล่ารายละเอียดปัญหา + ถ่ายรูปจากกล้อง (บังคับ) → เงินถูก Hold ไว้
// ให้ถ่ายจากกล้องเท่านั้น ไม่ให้เลือกจากคลังรูป กันเอารูปเก่า/รูปจากที่อื่นมาแจ้งปัญหาเท็จ
// ระบบแจ้งผู้ขายให้ชี้แจงภายใน 24 ชม. แล้วแอดมินตัดสิน
class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key, required this.item});

  final PaymentItem item;

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  PlayController controller = PlayController(PlaySupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  TextEditingController reasonController = TextEditingController();

  bool isSending = false;
  Uint8List? photoBytes;
  String photoFileName = '';

  PaymentItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSending = syncState;
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    reasonController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // เปิดกล้องถ่ายรูปปัญหาที่สนาม (กล้องหลัง)
  Future<void> _takePhoto() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600.0,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        photoBytes = bytes;
        photoFileName = file.name;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage('เปิดกล้องไม่ได้ (${error.code}) ตรวจสอบการอนุญาตใช้กล้อง');
    }
  }

  Future<void> _send() async {
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      _showMessage('กรุณาเล่ารายละเอียดปัญหา');
      return;
    }
    if (photoBytes == null) {
      _showMessage('กรุณาถ่ายรูปปัญหาที่พบ');
      return;
    }

    try {
      await controller.reportProblem(
        item.order,
        reason,
        photoBytes,
        photoFileName,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(paymentErrorText(error));
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ReportSentPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'แจ้งปัญหา',
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
          _buildSummary(),
          const SizedBox(height: 24.0),
          const Text(
            'ปัญหาที่พบ',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: reasonController,
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
            bytes: photoBytes,
            fileName: photoFileName,
            title: 'ถ่ายรูปปัญหาที่พบ',
            icon: Icons.photo_camera_outlined,
            actionLabel: 'ถ่ายรูป',
            onTap: isSending ? null : _takePhoto,
          ),
          const SizedBox(height: 6.0),
          const Padding(padding: EdgeInsets.only(left: 4.0)),
          const SizedBox(height: 16.0),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: kMutedColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: const Text(
              'เงินของคุณจะถูก Hold ไว้ ผู้ขายมีเวลาชี้แจง $kEvidenceHours ชม. '
              'แล้วแอดมินจะตัดสินว่าคืนเงินให้คุณหรือโอนให้ผู้ขาย',
              style: TextStyle(fontSize: 13.0, color: kSubtextColor),
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
            child: BuyerButton(
              label: 'ส่งเรื่อง',
              isLoading: isSending,
              onPressed: _send,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: kMutedColor,
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
                  '${item.listing.scheduleText} · ${item.order.reference}',
                  style: const TextStyle(color: kSubtextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
