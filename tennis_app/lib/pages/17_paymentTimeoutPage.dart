import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/payment_config.dart';

// หน้าหมดเวลาชำระเงิน (B7): ไม่ได้ชำระภายในเวลา ระบบปลดล็อกประกาศแล้ว
class PaymentTimeoutPage extends StatelessWidget {
  const PaymentTimeoutPage({
    super.key,
    required this.listing,
    required this.order,
  });

  final Listing listing;
  final Order order;

  void _goHome(BuildContext context) {
    context.read<HomeModel>().selectedTab = kTabHome;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 48.0),
              Container(
                width: 96.0,
                height: 96.0,
                decoration: BoxDecoration(
                  color: kNeutralSoftColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    '0:00',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'หมดเวลาชำระเงิน',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text(
                'ไม่ได้รับชำระภายใน $kPaymentMinutes นาที ระบบจึงปลดล็อก\n'
                '${listing.title} ให้ผู้ซื้อคนอื่นแล้ว',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kSubtextColor, height: 1.5),
              ),
              const SizedBox(height: 24.0),
              // ถ้าถูกตัดเงินไปแล้ว ต้องใช้เลขที่คำสั่งซื้อติดต่อทีมงาน
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: kMutedColor,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    const Text(
                      'โอนเงินไปแล้ว?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'ติดต่อทีมงานพร้อมเลขที่คำสั่งซื้อ ${order.reference} '
                      'ทีมงานจะตรวจสอบและคืนเงินให้',
                      style: const TextStyle(color: kSubtextColor, height: 1.5),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              BuyerButton(
                label: 'ดูประกาศอื่นต่อ',
                onPressed: () => _goHome(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
