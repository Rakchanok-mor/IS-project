import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/services/auth_service.dart';

// หน้าบัญชีถูกระงับ: ล็อกอินด้วยบัญชีที่โดนแบน (schema.sql หัวข้อ 23) จะเห็นแค่หน้านี้
// AuthGate ใน main.dart เป็นคนเลือกเปิดหน้านี้
class BannedPage extends StatefulWidget {
  const BannedPage({super.key, required this.reason});

  final String reason;

  @override
  State<BannedPage> createState() => _BannedPageState();
}

class _BannedPageState extends State<BannedPage> {
  AuthController authController = AuthController(AuthSupabaseService());

  @override
  void dispose() {
    authController.dispose();
    super.dispose();
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
                width: 88.0,
                height: 88.0,
                decoration: BoxDecoration(
                  color: kAlertBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: kAlertColor, width: 1.5),
                ),
                child: const Icon(Icons.block, size: 40.0, color: kAlertColor),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'บัญชีถูกระงับ',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'บัญชีนี้ซื้อ ขาย และตั้งรับสนามไม่ได้แล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(color: kSubtextColor, height: 1.5),
              ),
              const SizedBox(height: 24.0),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: kDividerColor),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    const Text(
                      'เหตุผล',
                      style: TextStyle(fontSize: 13.0, color: kHintColor),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      widget.reason,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'ถ้าคิดว่าเป็นความผิดพลาด กรุณาติดต่อทีมงาน Courtswap\n'
                'รายการที่ค้างอยู่ (คืนเงิน / โอนเงิน) ระบบยังดำเนินการให้จนเสร็จ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.0,
                  color: kSubtextColor,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  side: const BorderSide(color: kBorderColor),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  context.read<LoginModel>().username = '';
                  authController.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
