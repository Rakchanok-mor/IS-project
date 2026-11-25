import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/report_stat_tile.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/controller/profile_controller.dart';
import 'package:tennis_app/controller/report_controller.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/models/report_model.dart';
import 'package:tennis_app/pages/31_payoutAccountPage.dart';
import 'package:tennis_app/pages/35_editProfilePage.dart';
import 'package:tennis_app/services/auth_service.dart';
import 'package:tennis_app/services/profile_service.dart';
import 'package:tennis_app/services/report_service.dart';

// หน้าบัญชี เปิดจากปุ่มกลมขวาบนของหน้าหลัก
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
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
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'บัญชี',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ข้อมูลผู้ใช้ที่ล็อกอินอยู่ (ชื่อ เบอร์ อีเมล) + ปุ่มแก้ไข
        const ProfileCard(),
        const SizedBox(height: 24.0),
        // รายงานสรุปรายได้จากการขายคอร์ท
        const Text(
          'สรุปรายได้',
          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        const IncomeSummary(),
        const SizedBox(height: 24.0),
        // บัญชีรับเงินของผู้ขาย (แอดมินโอนเงินเข้าบัญชีนี้)
        MenuTile(
          icon: Icons.account_balance_outlined,
          label: 'บัญชีรับเงิน',
          color: Colors.white,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PayoutAccountPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 16.0),
        // ช่องทางติดต่อทีมงาน
        const ContactCard(),
        const SizedBox(height: 16.0),
        // ออกจากระบบ แล้ว AuthGate จะพากลับไปหน้า login ให้เอง
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
            // ล้าง username ที่จำไว้ ไม่งั้นหน้า login จะเติม email เดิมให้
            context.read<LoginModel>().username = '';
            // ล็อกอินครั้งหน้าให้กลับมาที่แท็บหน้าหลัก
            context.read<HomeModel>().selectedTab = kTabHome;
            // ปิดหน้าบัญชีก่อน (เปิดทับหน้าหลักอยู่) แล้ว AuthGate จะพาไปหน้า login
            Navigator.popUntil(context, (route) => route.isFirst);
            authController.signOut();
          },
        ),
      ],
    );
  }
}

// การ์ดโปรไฟล์: ชื่อ เบอร์โทร อีเมล กด "แก้ไข" ไปหน้าแก้ไขโปรไฟล์
// บัญชีเก่าที่ยังไม่มีชื่อ/เบอร์ จะมีแถบชวนให้กรอก
class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  ProfileController controller = ProfileController(ProfileSupabaseService());

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // กลับมาจากหน้าแก้ไขแล้วอ่านข้อมูลใหม่
  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    if (!mounted) return;
    setState(() {
      controller.reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final name = profile.fullName.isEmpty
        ? 'ยังไม่ได้กรอกชื่อ'
        : profile.fullName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(12.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28.0,
                  backgroundColor: kNeutralSoftColor,
                  foregroundColor: Colors.black,
                  child: profile.firstName.isEmpty
                      ? const Icon(Icons.person, size: 32.0)
                      : Text(
                          profile.firstName.characters.first,
                          style: const TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 17.0,
                          fontWeight: FontWeight.bold,
                          color: profile.fullName.isEmpty
                              ? kHintColor
                              : kBorderColor,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      _buildInfo(
                        Icons.phone_outlined,
                        profile.phone.isEmpty ? '-' : profile.phoneText,
                      ),
                      const SizedBox(height: 2.0),
                      _buildInfo(Icons.mail_outline, profile.email),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _edit,
                  child: const Text(
                    'แก้ไข',
                    style: TextStyle(
                      color: kBorderColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // บัญชีเก่ายังไม่มีชื่อ/เบอร์ ชวนให้กรอก
          if (!profile.isComplete)
            InkWell(
              onTap: _edit,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                child: const Text(
                  'กรอกชื่อและเบอร์โทรให้ครบ เพื่อใช้ซื้อขายสนาม',
                  style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.0, color: kSubtextColor),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kSubtextColor),
          ),
        ),
      ],
    );
  }
}

// รายงานสรุปรายได้ของผู้ขาย แสดงในหน้าบัญชี
// โหลดข้อมูลเองตอนเปิดหน้า (แบบเดียวกับ ProfileCard)
class IncomeSummary extends StatefulWidget {
  const IncomeSummary({super.key});

  @override
  State<IncomeSummary> createState() => _IncomeSummaryState();
}

class _IncomeSummaryState extends State<IncomeSummary> {
  ReportController controller = ReportController(ReportSupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  IncomeReport income = IncomeReport.empty();
  bool isLoading = false;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoading = syncState;
      });
    });
    _loadIncome();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadIncome() async {
    try {
      await controller.fetchMyIncome();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        hasError = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      hasError = false;
      income = controller.income;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && income.soldCount == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // โหลดไม่สำเร็จ: แตะเพื่อลองใหม่ (ไม่ใช้ SnackBar จะได้ไม่กวนทั้งหน้าบัญชี)
    if (hasError) {
      return InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: _loadIncome,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kCardBorderColor),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: const Text(
            'โหลดสรุปรายได้ไม่สำเร็จ แตะเพื่อลองใหม่',
            style: TextStyle(color: kSubtextColor),
          ),
        ),
      );
    }

    return Column(
      children: [
        ReportStatTile(
          label: 'ได้รับเงินแล้ว',
          value: '฿${income.receivedTotal}',
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: ReportStatTile(
                label: 'รอโอน',
                value: '฿${income.pendingTotal}',
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ReportStatTile(
                label: 'ขายได้',
                value: '${income.soldCount} คอร์ท',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: ReportStatTile(
                label: 'ยอดขายรวม',
                value: '฿${income.salesTotal}',
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ReportStatTile(
                label: 'ถูกคืนเงินผู้ซื้อ',
                value: '${income.refundedCount} รายการ',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: kMutedColor,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            'เงินที่ได้รับ = ราคาขาย - ค่าธรรมเนียมแพลตฟอร์ม '
            '฿$kPlatformFee ต่อรายการ '
            '(หักไปแล้วรวม ฿${income.feeTotal})\n'
            '"รอโอน" คือคำสั่งซื้อที่ผู้ซื้อจ่ายแล้ว '
            'แต่ยังไม่ได้เล่น ยังไม่ยืนยัน หรือมีข้อพิพาทอยู่',
            style: const TextStyle(fontSize: 13.0, color: kNeutralTextColor),
          ),
        ),
      ],
    );
  }
}

// อีเมลทีมงานสำหรับติดต่อเรื่องปัญหาการใช้งาน
const String kSupportEmail = 'support@courtswap.com';

// การ์ดติดต่อเรา แสดงอีเมลทีมงานอย่างเดียว (ไม่ต้องกด)
class ContactCard extends StatelessWidget {
  const ContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: const Row(
        children: [
          Icon(Icons.support_agent_outlined),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'ติดต่อเรา',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.0),
                Text(kSupportEmail, style: TextStyle(color: kSubtextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ปุ่มเมนูแบบแถว (ไอคอน + ข้อความ + ลูกศร) ใช้ในแท็บบัญชี
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
