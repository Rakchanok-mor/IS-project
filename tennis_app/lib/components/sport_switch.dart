import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/models/listing_model.dart';

// ปุ่มเลือกกีฬา เทนนิส / แบดมินตัน (ปุ่มที่เลือกอยู่เป็นสีดำ)
class SportSwitch extends StatelessWidget {
  const SportSwitch({super.key, required this.sport, required this.onChanged});

  final String sport;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> sports = [kSportTennis, kSportBadminton];

    return Row(
      children: List.generate(sports.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SportChip(
            label: sportLabel(sports[index]),
            isSelected: sport == sports[index],
            onTap: () {
              if (sport != sports[index]) {
                onChanged(sports[index]);
              }
            },
          ),
        );
      }),
    );
  }
}

// ปุ่มกีฬา 1 ปุ่ม
class SportChip extends StatelessWidget {
  const SportChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22.0),
      onTap: onTap,
      child: Container(
        height: 44.0,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          color: isSelected ? kBorderColor : Colors.white,
          border: Border.all(color: kBorderColor, width: 1.5),
          borderRadius: BorderRadius.circular(22.0),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : kBorderColor,
            ),
          ),
        ),
      ),
    );
  }
}
