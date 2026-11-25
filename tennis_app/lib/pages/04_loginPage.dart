import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/pages/03_signupPage.dart';
import 'package:tennis_app/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthController controller = AuthController(AuthSupabaseService());
  final _formKey = GlobalKey<FormState>();
  int _passwordLength = 0;
  bool _showPassword = false;
  String? _username;
  String? _password;

  String? _validateTextField(String fieldName, String? value, int length) {
    if (value!.isEmpty) {
      return '$fieldName must not be empty';
    }

    if (value.length <= length) {
      return '$fieldName must be longer than $length chars';
    }

    return null;
  }

  // แปลง error code ของ Supabase เป็นข้อความที่ผู้ใช้อ่านเข้าใจ
  String _loginErrorMessage(AuthException e) {
    if (e.code == 'invalid_credentials') {
      return 'Incorrect email or password. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  void initState() {
    super.initState();
    _username = context.read<LoginModel>().username;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 40.0),
              const Text(
                'Courtswap',
                style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              const SizedBox(height: 32.0),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  initialValue: _username,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.person),
                    hintText: 'What is your email?',
                    labelText: 'Email',
                  ),
                  onSaved: (newValue) {
                    _username = newValue;
                  },
                  validator: (value) {
                    return _validateTextField('Email', value, 5);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    icon: const Icon(Icons.password),
                    hintText: 'What is your password?',
                    labelText: 'Password',
                    suffixText: '$_passwordLength',
                    suffixIcon: GestureDetector(
                      child: const Icon(Icons.remove_red_eye),
                      onLongPress: () async {
                        setState(() {
                          _showPassword = true;
                        });

                        await Future.delayed(const Duration(seconds: 5));

                        setState(() {
                          _showPassword = false;
                        });
                      },
                    ),
                  ),
                  onSaved: (newValue) {
                    _password = newValue;
                  },
                  onChanged: (value) {
                    setState(() {
                      _passwordLength = value.length;
                    });
                  },
                  validator: (value) {
                    return _validateTextField('Password', value, 3);
                  },
                ),
              ),
              const SizedBox(height: 16.0),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBuyerColor,
                    foregroundColor: kOnBuyerColor,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      side: const BorderSide(color: kBorderColor),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Input is not valid')),
                      );

                      return;
                    }

                    _formKey.currentState!.save();

                    var loginMessage = '';
                    var isSuccess = false;

                    try {
                      await controller.signIn(_username!, _password!);

                      isSuccess = true;
                      loginMessage = 'Signed in successfully';
                    } on AuthException catch (e) {
                      loginMessage = _loginErrorMessage(e);
                      debugPrint('Error [${e.code}] ${e.message}');
                    }

                    if (!context.mounted) return;

                    // จำเฉพาะอีเมลที่ล็อกอินผ่าน
                    if (isSuccess) {
                      context.read<LoginModel>().username = _username!;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(loginMessage)));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      side: const BorderSide(color: kBorderColor),
                    ),
                  ),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SignupPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
