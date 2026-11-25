import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/transfer_model.dart';

// หน้าคืนเงินสำเร็จของแอดมิน (U5): ระบบแจ้งผู้ซื้อและปลดล็อกประกาศแล้ว
class RefundSuccessPage extends StatelessWidget {
  const RefundSuccessPage({super.key, required this.item, this.transfer});

  final PaymentItem item;
  final Transfer? transfer; // รายการโอนคืนผ่าน Payment Gateway

  @override
  Widget build(BuildContext context) {
    final order = item.order;
    final refundedAt = transfer?.completedAt ?? order.refundedAt;

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
                'คืนเงินสำเร็จ',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'ระบบแจ้งผู้ซื้อและปลดล็อกประกาศให้คนอื่นซื้อได้แล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(color: kSubtextColor),
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
                    _buildRow('ผู้ซื้อ', order.buyerName),
                    _buildRow('ยอดคืน', '฿${order.amount}'),
                    if (transfer != null) ...[
                      _buildRow('คืนเข้า', transfer!.destinationText),
                      _buildRow('เลขอ้างอิงการโอน', transfer!.gatewayRef),
                    ],
                    _buildRow('เลขที่คำสั่งซื้อ', order.reference),
                    _buildRow(
                      'คืนเมื่อ',
                      refundedAt == null ? '-' : thaiDateTime(refundedAt),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SellerButton(
                label: 'กลับไปหน้าการเงิน',
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
