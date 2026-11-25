import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/models/payment_model.dart';

// หน้าส่งเรื่องแจ้งปัญหาแล้ว (B18) ฝั่งผู้ซื้อ
class ReportSentPage extends StatelessWidget {
  const ReportSentPage({super.key, required this.item});

  final PaymentItem item;

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
                width: 88.0,
                height: 88.0,
                decoration: BoxDecoration(
                  color: kBuyerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: const Icon(
                  Icons.check,
                  size: 40.0,
                  color: kOnBuyerColor,
                ),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'ส่งเรื่องแล้ว',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text(
                'เลขที่คำสั่งซื้อ ${item.order.reference}\n'
                'เราจะแจ้งผลให้ทราบในหน้าสถานะคำสั่งซื้อ',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kSubtextColor, height: 1.5),
              ),
              const Spacer(),
              BuyerButton(
                label: 'กลับไปสถานะคำสั่งซื้อ',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
