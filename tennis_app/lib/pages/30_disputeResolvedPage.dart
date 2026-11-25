import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/models/payment_model.dart';

// หน้าบันทึกผลตัดสินแล้ว (U8) ของแอดมิน
// บอกขั้นต่อไป: ไปโอนเงินที่หน้าการเงิน (แท็บโอนผู้ขาย หรือ คืนเงิน)
class DisputeResolvedPage extends StatelessWidget {
  const DisputeResolvedPage({
    super.key,
    required this.item,
    required this.favorBuyer,
  });

  final PaymentItem item;
  final bool favorBuyer;

  @override
  Widget build(BuildContext context) {
    final order = item.order;

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
                  color: kAdminColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: const Icon(Icons.check, size: 40.0),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'บันทึกผลตัดสินแล้ว',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text(
                favorBuyer
                    ? 'ไปที่ การเงิน > คืนเงิน เพื่อโอนคืนให้ผู้ซื้อ'
                    : 'ไปที่ การเงิน > โอนผู้ขาย เพื่อโอนเงินให้ผู้ขาย',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kSubtextColor),
              ),
              const SizedBox(height: 24.0),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: kDividerColor),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  children: [
                    _buildRow('ข้อพิพาท', order.reference),
                    _buildRow('สนาม', item.listing.title),
                    _buildRow(
                      'ผล',
                      favorBuyer ? 'คืนเงินผู้ซื้อ' : 'โอนให้ผู้ขาย',
                    ),
                    _buildRow('ยอดเงิน', '฿${order.amount}'),
                  ],
                ),
              ),
              const Spacer(),
              SellerButton(
                label: 'กลับไปหน้าข้อพิพาท',
                color: kAdminColor,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
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
