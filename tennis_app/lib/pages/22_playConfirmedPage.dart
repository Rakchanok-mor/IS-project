import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/payment_model.dart';

// หน้ายืนยันการเล่นสำเร็จ (B10) ฝั่งผู้ซื้อ
// หลังจากนี้แอดมินจะโอนเงินให้ผู้ขาย (Workflow ใช้สนาม)
class PlayConfirmedPage extends StatelessWidget {
  const PlayConfirmedPage({super.key, required this.item});

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
                'ยืนยันการเล่นแล้ว',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text(
                'ขอบคุณที่ใช้ Courtswap\n'
                'ระบบกำลังโอนเงินให้ผู้ขาย',
                textAlign: TextAlign.center,
                style: TextStyle(color: kSubtextColor, height: 1.5),
              ),
              const SizedBox(height: 24.0),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: kDividerColor),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            item.listing.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            item.listing.scheduleText,
                            style: const TextStyle(color: kSubtextColor),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            item.order.reference,
                            style: const TextStyle(
                              fontSize: 12.0,
                              color: kHintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Text(
                      '฿${item.order.amount}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              BuyerButton(
                label: 'กลับไปหน้าหลัก',
                onPressed: () {
                  // งานจบแล้ว ไม่ต้องย้อนไปหน้าสถานะ — กลับแท็บหน้าหลักอย่างเดียว
                  context.read<HomeModel>().selectedTab = kTabHome;
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
              const SizedBox(height: 8.0),
            ],
          ),
        ),
      ),
    );
  }
}
