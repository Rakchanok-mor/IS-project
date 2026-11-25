import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/components/listing_card.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/payment_config.dart';
import 'package:tennis_app/pages/15_paymentPage.dart';
import 'package:tennis_app/services/auth_service.dart';
import 'package:tennis_app/services/payment_service.dart';

// หน้ารายละเอียดประกาศ (ฝั่งผู้ซื้อ) ข้อมูลทั้งหมดมาจากที่ผู้ขายกรอกตอนลงประกาศ
// กด "ซื้อทันที" → ล็อกประกาศไว้ให้ แล้วไปหน้าชำระเงิน
class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.listing});

  final Listing listing;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  PaymentController controller = PaymentController(PaymentSupabaseService());
  AuthController authController = AuthController(AuthSupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  bool isBuying = false;

  Listing get listing => widget.listing;

  // ประกาศของเราเอง = ซื้อไม่ได้
  bool get isMine => listing.isOwnedBy(authController.currentUserId);

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isBuying = syncState;
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    authController.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    try {
      final order = await controller.createOrder(listing);
      if (!mounted) return;
      // เปิดหน้าชำระเงินทับ (ไม่ใช้ pushReplacement เพราะหน้าหลักรอ await หน้านี้อยู่
      // ถ้าแทนที่ หน้าหลักจะโหลดใหม่ทันทีตอนประกาศยังถูกล็อก)
      // ออกจากขั้นตอนชำระเงินทุกทางจะกลับหน้าหลักด้วย popUntil
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(listing: listing, order: order),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(paymentErrorText(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(backgroundColor: kPageColor, surfaceTintColor: kPageColor),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
        children: [
          // ชื่อสนาม + ราคา
          Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      children: [
                        _buildSportTag(),
                        if (isMine) ...[
                          const SizedBox(width: 6.0),
                          const MineChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Text(
                '฿${listing.price}',
                style: const TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildSchedule(),
          _buildSection(title: 'ผู้ขาย', child: _buildSeller()),
          _buildSection(
            title: 'รายละเอียด',
            child: Text(
              listing.details.isEmpty
                  ? 'ผู้ขายไม่ได้ระบุรายละเอียดเพิ่มเติม'
                  : listing.details,
              style: TextStyle(
                fontSize: 15.0,
                height: 1.5,
                color: listing.details.isEmpty ? kHintColor : kBorderColor,
              ),
            ),
          ),
          _buildSection(
            title: 'ซื้ออย่างไร',
            child: const Text(
              '1. กดซื้อ ระบบจะล็อกประกาศไว้ให้คุณ $kPaymentMinutes นาที\n'
              '2. สแกน QR จ่ายเงิน ระบบยืนยันการชำระให้อัตโนมัติ\n'
              '3. เงินจะพักไว้ที่ Courtswap จนกว่าคุณจะได้เล่น จึงโอนให้ผู้ขาย',
              style: TextStyle(color: kSubtextColor, height: 1.6),
            ),
          ),
        ],
      ),
      // ประกาศของเราเอง = ไม่มีปุ่มซื้อ (ซื้อของตัวเองไม่ได้)
      bottomNavigationBar: isMine
          ? null
          : Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kDividerColor)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BuyerButton(
                    label: listing.isAvailable
                        ? 'ซื้อทันที ฿${listing.price}'
                        : 'ประกาศนี้ซื้อไม่ได้แล้ว',
                    isLoading: isBuying,
                    onPressed: listing.isAvailable ? _buy : null,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSportTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: kBuyerColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        sportLabel(listing.sport),
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: kSuccessTextColor,
        ),
      ),
    );
  }

  // กล่องวันเวลาเล่น
  Widget _buildSchedule() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: kBuyerColor.withValues(alpha: 0.2),
        border: Border.all(color: kBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: kBorderColor),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  thaiShortDate(listing.startTime, withYear: true),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2.0),
                Text(
                  '${hourMinuteText(listing.startTime)}–'
                  '${hourMinuteText(listing.endTime)} น. '
                  '(${listing.durationText})',
                  style: const TextStyle(color: kSubtextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeller() {
    final name = listing.sellerName.isEmpty ? 'ผู้ขาย' : listing.sellerName;
    return Row(
      children: [
        CircleAvatar(
          radius: 22.0,
          backgroundColor: kBuyerSoftColor,
          foregroundColor: kBuyerColor,
          child: Text(
            name.characters.first,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // หัวข้อ + เนื้อหา คั่นด้วยเส้น
  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        const Divider(height: 40.0, color: kDividerColor),
        Text(
          title,
          style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10.0),
        child,
      ],
    );
  }
}
