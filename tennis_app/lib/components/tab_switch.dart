import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/mode_switch.dart';

// แท็บแบบปุ่มแคปซูล หน้าตาเดียวกับ ModeSwitch แต่ตั้งชื่อแท็บเองได้
// เช่น "กำลังดำเนินการ" / "ประวัติ"
class TabSwitch extends StatelessWidget {
  const TabSwitch({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.color = kSellerColor,
    this.fontSize = 16.0,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color color;
  final double fontSize; // แท็บเยอะ (เช่น 4 แท็บ) ใช้ตัวเล็กลง จะได้ไม่ล้น

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    for (int i = 0; i < labels.length; i++) {
      if (i > 0) {
        children.add(const SizedBox(width: 4.0));
      }
      children.add(
        ModeButton(
          label: labels[i],
          color: color,
          isSelected: i == selectedIndex,
          fontSize: fontSize,
          onTap: () {
            onChanged(i);
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(children: children),
    );
  }
}
