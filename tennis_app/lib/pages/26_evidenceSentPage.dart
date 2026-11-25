import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/components/step_indicator.dart';
import 'package:tennis_app/models/order_model.dart';

// หน้าส่งหลักฐานแล้ว (A14) ฝั่งผู้ขาย: บอกขั้นตอนต่อไปของข้อพิพาท
class EvidenceSentPage extends StatelessWidget {
  const EvidenceSentPage({super.key, required this.item});

  final SellerListing item;

  @override
  Widget build(BuildContext context) {
    const List<String> steps = [
      'ผู้ซื้อแจ้งปัญหา',
      'คุณส่งหลักฐานแล้ว',
      'แอดมินตรวจสอบ',
      'แจ้งผลตัดสิน',
    ];

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
                  color: kSellerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: const Icon(Icons.check, size: 40.0),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'ส่งหลักฐานแล้ว',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'แอดมินจะตรวจสอบหลักฐานของทั้งสองฝ่าย\n'
                'เงินยังถูก Hold ไว้จนกว่าจะได้ข้อสรุป',
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
                child: Column(
                  children: List.generate(steps.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == steps.length - 1 ? 0.0 : 12.0,
                      ),
                      child: Row(
                        children: [
                          StepDot(
                            number: index + 1,
                            step: index,
                            currentStep: 2,
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(child: Text(steps[index])),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),
              SellerButton(
                label: 'กลับไปสถานะการชำระเงิน',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
