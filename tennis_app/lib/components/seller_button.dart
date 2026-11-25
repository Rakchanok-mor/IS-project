import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// ปุ่มหลักของฝั่งผู้ขาย (สีส้ม ขอบดำ) แบบเดียวกับ BuyerButton
// outlined = true เป็นปุ่มรอง (พื้นขาว) เช่น ย้อนกลับ / แก้ไข
class SellerButton extends StatelessWidget {
  const SellerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 56.0,
    this.fontSize = 17.0,
    this.outlined = false,
    this.color = kSellerColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  // ย่อปุ่มได้ด้วย height / fontSize (ปกติ 56 / 17)
  final double height;
  final double fontSize;
  final bool outlined;
  // สีพื้นปุ่ม ปกติเป็นส้มฝั่งขาย (หน้าแอดมินใช้สีม่วง kAdminColor)
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: outlined ? Colors.white : color,
          foregroundColor: kBorderColor,
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: kBorderColor, width: 1.5),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        // กดไม่ได้ระหว่างกำลังบันทึก กันกดซ้ำ
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
