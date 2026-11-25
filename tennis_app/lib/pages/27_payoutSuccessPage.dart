import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/payment_model.dart';
import 'package:tennis_app/models/payout_account_model.dart';
import 'package:tennis_app/models/transfer_model.dart';

// หน้าโอนเงินให้ผู้ขายสำเร็จ (U2) ของแอดมิน (แบบเดียวกับ RefundSuccessPage)
class PayoutSuccessPage extends StatelessWidget {
  const PayoutSuccessPage({
    super.key,
    required this.item,
    required this.account,
    this.transfer,
  });

  final PaymentItem item;
  final PayoutAccount account;
  final Transfer? transfer; // รายการโอนผ่าน Payment Gateway

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
                'โอนเงินสำเร็จ',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'ระบบแจ้งผู้ขายแล้ว ออเดอร์นี้ปิดเรียบร้อย',
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
                    _buildRow('ผู้รับ', account.accountName),
                    _buildRow('ราคาขาย', '฿${order.amount}'),
                    _buildRow('ค่าธรรมเนียมแพลตฟอร์ม', '-฿$kPlatformFee'),
                    _buildRow('ยอดโอน', '฿${order.sellerPayout}'),
                    _buildRow(
                      'บัญชี',
                      '${account.bankName} ${account.maskedNumber}',
                    ),
                    if (transfer != null)
                      _buildRow('เลขอ้างอิงการโอน', transfer!.gatewayRef),
                    _buildRow('เลขที่คำสั่งซื้อ', order.reference),
                    _buildRow(
                      'โอนเมื่อ',
                      thaiDateTime(transfer?.completedAt ?? DateTime.now()),
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
