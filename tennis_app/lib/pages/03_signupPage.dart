import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/auth_controller.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  AuthController controller = AuthController(AuthSupabaseService());
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isSubmitting = false;
  String? _email;
  String? _password;
  String? _firstName;
  String? _lastName;
  String? _phone;

  @override
  void dispose() {
    _passwordController.dispose();
    controller.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email must not be empty';
    }

    // เช็คแบบง่าย ๆ ว่ามี @ และจุดตามหลัง ที่เหลือให้ Supabase ตรวจอีกที
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Email is not valid';
    }

    return null;
  }

  // ชื่อ / นามสกุล ห้ามว่าง
  String? _validateName(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label must not be empty';
    }
    return null;
  }

  // เบอร์มือถือไทย 10 หลัก ขึ้นต้นด้วย 0 เช่น 0812345678
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number must not be empty';
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(value)) {
      return 'Phone number must be 10 digits, e.g. 0812345678';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password must not be empty';
    }

    // Supabase Auth ค่าเริ่มต้นบังคับอย่างน้อย 6 ตัวอักษร
    if (value.length < 6) {
      return 'Password must be at least 6 chars';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Input is not valid')));

      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    var signupMessage = '';
    var isSuccess = false;

    try {
      // ชื่อ นามสกุล เบอร์โทร เก็บในข้อมูลโปรไฟล์ของผู้ใช้ (user metadata)
      // name = ชื่อเต็ม ใช้เป็นชื่อผู้ซื้อในคำสั่งซื้อ (create_order ใน supabase/schema.sql)
      final firstName = _firstName!.trim();
      final lastName = _lastName!.trim();
      final userId = await controller.signUp(_email!, _password!, {
        'first_name': firstName,
        'last_name': lastName,
        'name': '$firstName $lastName',
        'phone': _phone!,
      });

      isSuccess = true;
      signupMessage = 'Signed up successfully $userId';
    } on AuthException catch (e) {
      signupMessage = 'Error [${e.code}] ${e.message}';
      debugPrint(signupMessage);
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (isSuccess) {
      context.read<LoginModel>().username = _email!;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(signupMessage)));

    // สมัครเสร็จ Supabase ล็อกอินให้เลย ปิดหน้านี้กลับไปให้ AuthGate พาเข้าแอป
    if (isSuccess) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        foregroundColor: Colors.black,
        elevation: 0.0,
        title: const Text('Sign up'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 16.0),
              const Text(
                'Create your account',
                style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32.0),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.badge_outlined),
                    labelText: 'First name',
                  ),
                  onSaved: (newValue) {
                    _firstName = newValue;
                  },
                  validator: (value) => _validateName(value, 'First name'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.badge_outlined),
                    labelText: 'Last name',
                  ),
                  onSaved: (newValue) {
                    _lastName = newValue;
                  },
                  validator: (value) => _validateName(value, 'Last name'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.phone_outlined),
                    hintText: '0812345678',
                    labelText: 'Phone number',
                    counterText: '',
                  ),
                  onSaved: (newValue) {
                    _phone = newValue;
                  },
                  validator: _validatePhone,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.person),
                    hintText: 'What is your email?',
                    labelText: 'Email',
                  ),
                  onSaved: (newValue) {
                    _email = newValue;
                  },
                  validator: _validateEmail,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    icon: const Icon(Icons.password),
                    hintText: 'At least 6 chars',
                    labelText: 'Password',
                    suffixIcon: GestureDetector(
                      child: const Icon(Icons.remove_red_eye),
                      onLongPress: () async {
                        setState(() {
                          _showPassword = true;
                        });

                        await Future.delayed(const Duration(seconds: 5));

                        if (!mounted) return;

                        setState(() {
                          _showPassword = false;
                        });
                      },
                    ),
                  ),
                  onSaved: (newValue) {
                    _password = newValue;
                  },
                  validator: _validatePassword,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.password),
                    hintText: 'Type your password again',
                    labelText: 'Confirm password',
                  ),
                  validator: _validateConfirmPassword,
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
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20.0,
                          width: 20.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Text(
                          'Sign up',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text(
                    'Already have an account? Log in',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
