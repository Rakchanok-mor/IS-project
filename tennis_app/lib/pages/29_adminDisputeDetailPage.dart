import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/controller/play_controller.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/pages/30_disputeResolvedPage.dart';
import 'package:tennis_app/services/payment_service.dart';
import 'package:tennis_app/services/play_service.dart';

// หน้าตัดสินข้อพิพาท (U7) ของแอดมิน
// ดูหลักฐานของผู้ซื้อ (ปัญหาที่แจ้ง + รูป) และผู้ขาย (คำชี้แจง + รูป)
// เลือกผล: โอนให้ผู้ขาย (เข้าคิวโอนผู้ขาย) / คืนเงินผู้ซื้อ (เข้าคิวคืนเงิน) → U8
class AdminDisputeDetailPage extends StatefulWidget {
  const AdminDisputeDetailPage({super.key, required this.item});

  final PaymentItem item;

  @override
  State<AdminDisputeDetailPage> createState() => _AdminDisputeDetailPageState();
}

class _AdminDisputeDetailPageState extends State<AdminDisputeDetailPage> {
  PlayController controller = PlayController(PlaySupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  TextEditingController noteController = TextEditingController();

  bool isSaving = false;
  bool? favorBuyer; // ยังไม่เลือก = null
  // แบนฝ่ายที่ผิดด้วย: ผู้ขายถูก = แบนผู้ซื้อ (Case 2), ผู้ซื้อถูก = แบนผู้ขาย (Case 3)
  bool banLoser = false;
  String? buyerPhotoUrl;
  String? sellerPhotoUrl;

  PaymentItem get item => widget.item;
  Order get order => widget.item.order;
  bool get isOpen => order.status == kOrderDisputed;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSaving = syncState;
      });
    });
    _loadPhotos();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    try {
      final buyerUrl = await controller.getFileUrl(order.disputePhotoPath);
      final sellerUrl = await controller.getFileUrl(order.evidencePath);
      if (!mounted) return;
      setState(() {
        buyerPhotoUrl = buyerUrl;
        sellerPhotoUrl = sellerUrl;
      });
    } catch (error) {
      // โหลดรูปไม่ได้ก็ยังอ่านข้อความตัดสินได้
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resolve() async {
    final choice = favorBuyer;
    if (choice == null) {
      _showMessage('กรุณาเลือกผลตัดสิน');
      return;
    }

    final note = noteController.text.trim();
    try {
      await controller.resolveDispute(order, choice, note);
    } catch (error) {
      if (!mounted) return;
      _showMessage(paymentErrorText(error));
      return;
    }

    // แบนฝ่ายที่ผิด (ตัดสินไปแล้ว แบนไม่สำเร็จก็ไม่ย้อนผลตัดสิน แค่แจ้งแอดมิน)
    if (banLoser) {
      final banBuyer = !choice;
      try {
        await controller.banOrderParty(
          order,
          banBuyer,
          note.isNotEmpty
              ? note
              : (banBuyer
                    ? 'แจ้งปัญหาเท็จ (สนามยืนยันว่ามีการเข้าใช้)'
                    : 'หลักฐานการจองไม่ถูกต้อง'),
        );
        _showMessage(banBuyer ? 'แบนผู้ซื้อแล้ว' : 'แบนผู้ขายแล้ว');
      } catch (error) {
        _showMessage('ตัดสินแล้ว แต่แบนไม่สำเร็จ: ${paymentErrorText(error)}');
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DisputeResolvedPage(item: item, favorBuyer: choice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: Text(
          order.reference,
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
          _buildSummary(),
          const SizedBox(height: 16.0),
          _buildSide(
            title: 'ผู้ซื้อ · ${order.buyerName}',
            heading: order.disputeCategory.isEmpty
                ? 'ปัญหาที่แจ้ง'
                : order.disputeCategory,
            text: order.disputeReason,
            photoUrl: buyerPhotoUrl,
            background: kAlertBackground,
          ),
          const SizedBox(height: 12.0),
          _buildSide(
            title: 'ผู้ขาย · ${item.listing.sellerName}',
            heading: order.hasEvidence ? 'คำชี้แจง' : 'ยังไม่ส่งหลักฐาน',
            text: order.hasEvidence
                ? order.sellerNote
                : 'ส่งได้ถึง ${thaiDateTime(order.evidenceDeadline!)} '
                      'ถ้าไม่ส่ง ระบบจะคืนเงินผู้ซื้อให้อัตโนมัติ',
            photoUrl: sellerPhotoUrl,
            background: kSellerColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 24.0),
          if (isOpen) ..._buildDecision() else _buildResult(),
        ],
      ),
      bottomNavigationBar: isOpen
          ? Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kDividerColor)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SellerButton(
                    label: 'บันทึกผลตัดสิน',
                    color: kAdminColor,
                    isLoading: isSaving,
                    onPressed: _resolve,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          SportIconBox(sport: item.listing.sport),
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
              ],
            ),
          ),
          Text(
            '฿${order.amount}',
            style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // กล่องหลักฐานของแต่ละฝ่าย
  Widget _buildSide({
    required String title,
    required String heading,
    required String text,
    required String? photoUrl,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13.0, color: kSubtextColor),
          ),
          const SizedBox(height: 4.0),
          Text(heading, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4.0),
          Text(text.isEmpty ? '-' : text, style: const TextStyle(height: 1.5)),
          if (photoUrl != null) ...[
            const SizedBox(height: 8.0),
            _buildPhoto(photoUrl),
          ],
        ],
      ),
    );
  }

  // รูปย่อ กดแล้วดูเต็มจอ
  Widget _buildPhoto(String url) {
    final image = Image.network(url, fit: BoxFit.cover);
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: SizedBox(width: 96.0, height: 96.0, child: image),
      ),
    );
  }

  // ตัวเลือกผลตัดสิน + บันทึก
  List<Widget> _buildDecision() {
    return [
      const Text(
        'ผลการตัดสิน',
        style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8.0),
      _buildOption(false, 'ผู้ขายถูก', 'โอน ฿${order.sellerPayout} ให้ผู้ขาย'),
      _buildOption(true, 'ผู้ซื้อถูก', 'คืน ฿${order.amount} ให้ผู้ซื้อ'),
      if (favorBuyer != null) _buildBanOption(favorBuyer!),
      const SizedBox(height: 8.0),
      TextField(
        controller: noteController,
        minLines: 2,
        maxLines: 4,
        style: const TextStyle(fontSize: 16.0),
        decoration: InputDecoration(
          hintText: 'บันทึกเหตุผล (ไม่บังคับ)',
          hintStyle: const TextStyle(color: kHintColor),
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
    ];
  }

  Widget _buildOption(bool value, String title, String subtitle) {
    final isSelected = favorBuyer == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          setState(() {
            // เปลี่ยนผลตัดสิน = ฝ่ายที่จะแบนเปลี่ยน ให้ติ๊กใหม่
            if (favorBuyer != value) banLoser = false;
            favorBuyer = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: isSelected ? kAdminColor.withValues(alpha: 0.3) : null,
            border: Border.all(
              color: isSelected ? kBorderColor : kCardBorderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.0,
                        color: kSubtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ติ๊กแบนฝ่ายที่ผิด (แสดงหลังเลือกผลตัดสิน)
  Widget _buildBanOption(bool buyerWins) {
    final title = buyerWins
        ? 'แบนผู้ขาย · ${item.listing.sellerName}'
        : 'แบนผู้ซื้อ · ${order.buyerName}';
    final subtitle = buyerWins
        ? 'เช่น หลักฐานการจองปลอม หรือสนามยืนยันว่าไม่มีการจองนี้'
        : 'เช่น แจ้งปัญหาเท็จ สนามยืนยันว่ามีการเข้าใช้จริง';

    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: () {
        setState(() {
          banLoser = !banLoser;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: banLoser ? kAlertBackground : null,
          border: Border.all(
            color: banLoser ? kAlertColor : kCardBorderColor,
            width: banLoser ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          children: [
            Icon(
              banLoser ? Icons.check_box : Icons.check_box_outline_blank,
              color: banLoser ? kAlertColor : null,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: banLoser ? kAlertColor : null,
                    ),
                  ),
                  Text(
                    '$subtitle\nโดนแบนแล้วซื้อ/ขาย/ตั้งรับไม่ได้อีก',
                    style: const TextStyle(
                      fontSize: 13.0,
                      color: kSubtextColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ตัดสินไปแล้ว: แสดงผลอย่างเดียว
  Widget _buildResult() {
    final toBuyer = order.resolution == kResolutionBuyer;
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: kMutedColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Text(
        'ผลตัดสิน: ${toBuyer ? 'คืนเงินผู้ซื้อ' : 'โอนให้ผู้ขาย'}'
        '${order.resolvedAt == null ? '' : ' · ${thaiDateTime(order.resolvedAt!)}'}'
        '${order.resolutionNote.isEmpty ? '' : '\n${order.resolutionNote}'}'
        '${toBuyer && order.resolutionNote.isEmpty ? '\n${order.rejectReason}' : ''}',
        style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
      ),
    );
  }
}
