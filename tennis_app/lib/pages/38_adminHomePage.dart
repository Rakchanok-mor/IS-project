import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/pages/07_accountPage.dart';
import 'package:tennis_app/pages/19_adminPaymentsPage.dart';
import 'package:tennis_app/pages/28_adminDisputeListPage.dart';
import 'package:tennis_app/pages/40_adminReportPage.dart';
import 'package:tennis_app/services/auth_service.dart';

// หน้าแรกของแอดมิน: ล็อกอินด้วยบัญชีแอดมินจะเห็นแค่เมนูแอดมิน (ไม่เห็นหน้าซื้อขาย)
// AuthGate ใน main.dart เป็นคนเลือกว่าจะเปิดหน้านี้หรือหน้าหลักปกติ
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  AuthController authController = AuthController(AuthSupabaseService());

  @override
  void dispose() {
    authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = authController.currentEmail;

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        automaticallyImplyLeading: false,
        title: const Text(
          'Courtswap แอดมิน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (email.isNotEmpty) ...[
            Text(
              'ล็อกอินเป็น $email',
              style: const TextStyle(color: kSubtextColor),
            ),
            const SizedBox(height: 16.0),
          ],
          MenuTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'การเงิน',
            color: kAdminColor.withValues(alpha: 0.3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPaymentsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 8.0),
          MenuTile(
            icon: Icons.gavel,
            label: 'ข้อพิพาท',
            color: kAdminColor.withValues(alpha: 0.3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminDisputeListPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 8.0),
          // รายงานยอดขาย + สถานะคำสั่งซื้อ
          MenuTile(
            icon: Icons.bar_chart,
            label: 'รายงาน',
            color: kAdminColor.withValues(alpha: 0.3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminReportPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24.0),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
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
              // ล้าง username ที่จำไว้ แล้ว AuthGate จะพากลับไปหน้า login ให้เอง
              context.read<LoginModel>().username = '';
              authController.signOut();
            },
          ),
        ],
      ),
    );
  }
}
