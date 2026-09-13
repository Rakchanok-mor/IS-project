import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/firebase_options.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/pages/01_sellerHomePage.dart';
import 'package:tennis_app/pages/02_buyerHomePage.dart';
import 'package:tennis_app/pages/loginPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LoginModel()),
      ],
      child: AuthGate(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CourtMate',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: kBuyerColor),
      ),
      initialRoute: '/2',
      routes: {
        '/1': (context) => SellerHomePage(),
        '/2': (context) => BuyerHomePage(),
        '/9': (context) => LoginPage(),
      },
    );
  }
}

// ยังไม่ล็อกอิน = เห็นหน้า Login, ล็อกอินแล้ว = เข้าแอป
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'CourtMate',
            theme: ThemeData(
              colorScheme: .fromSeed(seedColor: kBuyerColor),
            ),
            home: LoginPage(),
          );
        }
        return MyApp();
      },
    );
  }
}
