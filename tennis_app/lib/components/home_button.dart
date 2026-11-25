import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// ปุ่มกลับหน้าหลักด้านล่างหน้าสถานะ (ผู้ซื้อ/ผู้ขาย) เต็มความกว้าง
// สูง / กรอบ / ขนาดตัวอักษรเท่าปุ่มของขั้นนั้นที่อยู่ข้างใต้ ให้ดูสมดุลกัน
class HomeButton extends StatelessWidget {
  const HomeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.0,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kBorderColor,
          side: const BorderSide(color: kBorderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22.0),
          ),
        ),
        onPressed: onPressed,
        child: const Text(
          'กลับหน้าหลัก',
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
