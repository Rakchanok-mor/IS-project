import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// กล่องเมนูบนหน้าหลัก (ไอคอน + หัวข้อ) แตะแล้วไปหน้าอื่น
// isPrimary = true พื้นเขียวตัวหนังสือขาว (กล่องหลัก), false = พื้นขาวขอบเทา
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isPrimary = false,
    this.isBuyerMode = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isBuyerMode; // false = สีฝั่งขาย (ส้ม)

  @override
  Widget build(BuildContext context) {
    final Color background = isPrimary ? kBuyerColor : Colors.white;
    final Color foreground = isPrimary ? Colors.white : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: isPrimary ? kBuyerColor : kCardBorderColor),
          borderRadius: BorderRadius.circular(16.0),
        ),
        // ไอคอน + หัวข้ออยู่กึ่งกลางกล่อง
        child: Column(
          crossAxisAlignment: .center,
          children: [
            // กล่องไอคอนสี่เหลี่ยมมุมมน
            Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isBuyerMode
                          ? kBuyerSoftColor
                          : kSellerColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(
                icon,
                size: 22.0,
                color: isPrimary
                    ? Colors.white
                    : (isBuyerMode ? kBuyerColor : kSellerTextColor),
              ),
            ),
            const SizedBox(height: 14.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
