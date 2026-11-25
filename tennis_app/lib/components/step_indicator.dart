import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// แถบบอกขั้นตอน 1 — 2 — 3
// ขั้นที่ผ่านแล้วเป็นเครื่องหมายถูก ขั้นปัจจุบันเป็นตัวเลขพื้นส้ม ขั้นที่ยังไม่ถึงเป็นสีเทา
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  // เริ่มนับที่ 0
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    for (int i = 0; i < totalSteps; i++) {
      if (i > 0) {
        // เส้นเชื่อมระหว่างขั้น เป็นสีดำเมื่อผ่านมาแล้ว
        children.add(
          Expanded(
            child: Container(
              height: 2.0,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              color: i <= currentStep ? kBorderColor : kDividerColor,
            ),
          ),
        );
      }
      children.add(StepDot(number: i + 1, step: i, currentStep: currentStep));
    }

    return Row(children: children);
  }
}

// วงกลม 1 ขั้น
class StepDot extends StatelessWidget {
  const StepDot({
    super.key,
    required this.number,
    required this.step,
    required this.currentStep,
    this.color = kSellerColor,
  });

  // สีวงกลมของขั้นที่ผ่าน/ปัจจุบัน (ฝั่งขาย = ส้ม, ฝั่งซื้อ = เขียวมะนาว)
  final Color color;
  final int number;
  final int step;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final bool isDone = step < currentStep;
    final bool isCurrent = step == currentStep;
    final bool isActive = isDone || isCurrent;

    return Container(
      width: 32.0,
      height: 32.0,
      decoration: BoxDecoration(
        color: isActive ? color : kNeutralSoftColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? kBorderColor : kCardBorderColor,
          width: 1.5,
        ),
      ),
      child: Center(
        child: isDone
            ? Icon(Icons.check, size: 18.0, color: textColorOn(color))
            : Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? textColorOn(color) : kHintColor,
                ),
              ),
      ),
    );
  }
}
