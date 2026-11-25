import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// กล่องตัวเลขสรุปในหน้ารายงาน: หัวข้อเล็ก + ตัวเลขใหญ่
class ReportStatTile extends StatelessWidget {
  const ReportStatTile({
    super.key,
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13.0, color: kSubtextColor),
          ),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
