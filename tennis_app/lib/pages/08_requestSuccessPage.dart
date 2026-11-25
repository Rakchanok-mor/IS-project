import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/request_model.dart';

// หน้าตั้งรับสำเร็จ: สรุปสิ่งที่ตั้งรับไว้ แล้วรอระบบจับคู่กับผู้ขาย
class RequestSuccessPage extends StatelessWidget {
  const RequestSuccessPage({super.key, required this.request});

  final CourtRequest request;

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
                'ตั้งรับสำเร็จ',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'ระบบจะแจ้งเมื่อมีผู้ขายเสนอสนามที่ตรงกัน',
                textAlign: TextAlign.center,
                style: TextStyle(color: kSubtextColor),
              ),
              const SizedBox(height: 24.0),
              // สรุปการตั้งรับ
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: kDividerColor),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  children: [
                    _buildRow('กีฬา', sportLabel(request.sport)),
                    _buildRow('สนาม', request.courtName),
                    _buildRow('วันเวลา', request.scheduleText),
                  ],
                ),
              ),
              const Spacer(),
              BuyerButton(
                label: 'ดูตั้งรับของฉัน',
                onPressed: () {
                  // ไปหน้าหลักโหมดซื้อ (ประกาศตั้งรับของฉัน)
                  context.read<HomeModel>().openBuyerHome();
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'กลับหน้าหลัก',
                  style: TextStyle(
                    color: kSubtextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
