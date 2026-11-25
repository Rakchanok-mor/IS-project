import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// ปุ่มสลับโหมด ผู้ซื้อ / ผู้ขาย
// ฝั่งที่เลือกอยู่จะมีสีพื้น (เขียวมะนาว = ซื้อ, ส้ม = ขาย)
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({
    super.key,
    required this.isBuyerMode,
    required this.onChanged,
  });

  final bool isBuyerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        // พื้นขาว ฝั่งที่ไม่ได้เลือกจะไม่กลืนกับสีพื้นหน้าจอ
        color: Colors.white,
        border: Border.all(color: kBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        children: [
          ModeButton(
            label: 'ซื้อ',
            color: kBuyerColor,
            isSelected: isBuyerMode,
            onTap: () {
              onChanged(true);
            },
          ),
          const SizedBox(width: 4.0),
          ModeButton(
            label: 'ขาย',
            color: kSellerColor,
            isSelected: !isBuyerMode,
            onTap: () {
              onChanged(false);
            },
          ),
        ],
      ),
    );
  }
}

// ปุ่มครึ่งหนึ่งของ ModeSwitch
class ModeButton extends StatelessWidget {
  const ModeButton({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.fontSize = 16.0,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(26.0),
        onTap: onTap,
        child: Container(
          height: 44.0,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(26.0),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isSelected ? textColorOn(color) : kBorderColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
