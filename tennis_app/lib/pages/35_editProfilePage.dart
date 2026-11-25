import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/controller/profile_controller.dart';
import 'package:tennis_app/models/profile_model.dart';
import 'package:tennis_app/services/profile_service.dart';

// หน้าแก้ไขโปรไฟล์: ชื่อ นามสกุล เบอร์โทร (อีเมลแก้ไม่ได้)
// บัญชีที่สมัครก่อนมีช่องเหล่านี้ เติมข้อมูลได้จากหน้านี้
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  ProfileController controller = ProfileController(ProfileSupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  final _formKey = GlobalKey<FormState>();

  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSaving = syncState;
      });
    });

    // เติมข้อมูลเดิม
    final profile = controller.profile;
    firstNameController.text = profile.firstName;
    lastNameController.text = profile.lastName;
    phoneController.text = profile.phone;
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = Profile(
      controller.profile.email,
      firstNameController.text.trim(),
      lastNameController.text.trim(),
      phoneController.text.trim(),
    );

    try {
      await controller.saveMyProfile(profile);
    } catch (error) {
      if (!mounted) return;
      _showMessage('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;
    _showMessage('บันทึกโปรไฟล์แล้ว');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'แก้ไขโปรไฟล์',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildLabel('อีเมล'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                // อีเมลแก้ไม่ได้ ใช้พื้นจาง (เข้มกว่าพื้นหน้าจอ จะได้ไม่กลืน)
                color: kMutedColor,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Text(
                controller.profile.email,
                style: const TextStyle(color: kSubtextColor),
              ),
            ),
            const SizedBox(height: 16.0),
            _buildLabel('ชื่อ'),
            TextFormField(
              controller: firstNameController,
              decoration: _inputDecoration('ชื่อจริง'),
              validator: (value) => _required(value, 'กรุณากรอกชื่อ'),
            ),
            const SizedBox(height: 16.0),
            _buildLabel('นามสกุล'),
            TextFormField(
              controller: lastNameController,
              decoration: _inputDecoration('นามสกุล'),
              validator: (value) => _required(value, 'กรุณากรอกนามสกุล'),
            ),
            const SizedBox(height: 16.0),
            _buildLabel('เบอร์โทร'),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: _inputDecoration(
                '0812345678',
              ).copyWith(counterText: ''),
              validator: (value) {
                if (value == null || !RegExp(r'^0\d{9}$').hasMatch(value)) {
                  return 'เบอร์โทร 10 หลัก ขึ้นต้นด้วย 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BuyerButton(
              label: 'บันทึก',
              isLoading: isSaving,
              onPressed: _save,
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHintColor),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 18.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: kBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: kBorderColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: kAlertColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: kAlertColor, width: 2.0),
      ),
    );
  }
}
