import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// ปุ่มหลักของฝั่งผู้ซื้อ (สีเขียวมะนาว ขอบดำ) เช่น ปุ่มตั้งรับ
class BuyerButton extends StatelessWidget {
  const BuyerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 56.0,
    this.fontSize = 17.0,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  // ย่อปุ่มได้ด้วย height / fontSize (ปกติ 56 / 17)
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBuyerColor,
          foregroundColor: kOnBuyerColor,
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
            : Row(
                mainAxisAlignment: .center,
                children: [
                  if (icon != null) ...[Icon(icon), const SizedBox(width: 8.0)],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
