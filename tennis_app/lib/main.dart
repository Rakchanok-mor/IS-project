import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/controller/payment_controller.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/pages/04_loginPage.dart';
import 'package:tennis_app/pages/05_homePage.dart';
import 'package:tennis_app/pages/38_adminHomePage.dart';
import 'package:tennis_app/pages/39_bannedPage.dart';
import 'package:tennis_app/services/auth_service.dart';
import 'package:tennis_app/services/payment_service.dart';
import 'package:tennis_app/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LoginModel()),
        ChangeNotifierProvider(create: (context) => HomeModel()),
      ],
      child: const MyApp(),
    ),
  );
}

// MaterialApp มีตัวเดียวทั้งแอป ธีมกับชื่อแอปตั้งไว้ที่นี่ที่เดียว
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courtswap',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: kBuyerColor),
        // พื้นหลังทุกหน้า (หน้าที่สร้างใหม่ไม่ต้องใส่เอง)
        scaffoldBackgroundColor: kPageColor,
        // ช่องกรอกข้อมูลพื้นขาว จะได้ไม่กลืนกับพื้นหน้าจอ
        // (ช่องที่กำหนด fillColor เอง เช่น ช่องอีเมลสีเทา ยังใช้สีของตัวเอง)
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ยังไม่ล็อกอิน = เห็นหน้า Login
// ล็อกอินแล้ว: โดนแบน = หน้าบัญชีถูกระงับ, แอดมิน (อยู่ในตาราง admins) = หน้าแอดมิน,
// คนทั่วไป = หน้าหลัก
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

// สถานะบัญชีที่เช็กตอนล็อกอิน
class _AccountStatus {
  const _AccountStatus({this.isAdmin = false, this.banReason});

  final bool isAdmin;
  final String? banReason; // ไม่โดนแบน = null
}

class _AuthGateState extends State<AuthGate> {
  AuthController authController = AuthController(AuthSupabaseService());
  PaymentController paymentController = PaymentController(
    PaymentSupabaseService(),
  );

  @override
  void dispose() {
    authController.dispose();
    paymentController.dispose();
    super.dispose();
  }

  // จำผลเช็กไว้ต่อ user จะได้ไม่ถามฐานข้อมูลใหม่ทุกครั้งที่ build
  String? _checkedUserId;
  Future<_AccountStatus>? _status;

  Future<_AccountStatus> _statusFor(String userId) {
    if (_checkedUserId != userId || _status == null) {
      _checkedUserId = userId;
      _status = _loadStatus();
    }
    return _status!;
  }

  Future<_AccountStatus> _loadStatus() async {
    // เช็กไม่ได้ (เช่น เน็ตหลุด) = ถือว่าไม่ใช่แอดมิน / ไม่โดนแบน
    // (ถึงแอปเช็กพลาด ฐานข้อมูลก็ยังไม่ให้คนที่โดนแบนทำรายการอยู่ดี)
    final results = await Future.wait([
      paymentController.isAdmin().catchError((_) => false),
      paymentController.getMyBanReason().catchError((_) => null),
    ]);
    return _AccountStatus(
      isAdmin: results[0] as bool,
      banReason: results[1] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authController.onAuthStateChange,
      builder: (context, snapshot) {
        // ใช้ session ปัจจุบันเลย จะได้ไม่เด้งไปหน้า Login แวบหนึ่งตอนเปิดแอป
        final session = snapshot.data?.session ?? authController.currentSession;
        if (session == null) {
          _checkedUserId = null;
          _status = null;
          return LoginPage();
        }

        return FutureBuilder<_AccountStatus>(
          future: _statusFor(session.user.id),
          builder: (context, statusSnapshot) {
            if (statusSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final status = statusSnapshot.data ?? const _AccountStatus();
            final banReason = status.banReason;
            if (banReason != null) {
              return BannedPage(reason: banReason);
            }
            if (status.isAdmin) {
              return const AdminHomePage();
            }
            return const HomePage();
          },
        );
      },
    );
  }
}
