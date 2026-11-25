import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// ช่องค้นหาสนาม พิมพ์ชื่อสนามได้ และมีปุ่ม "แผนที่" ไว้เลือกสนามจากแผนที่
class CourtSearchBar extends StatelessWidget {
  const CourtSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onOpenMap,
    this.isBuyerMode = true,
    this.hintText = 'ค้นหาประกาศ',
  });

  // ข้อความในช่องค้นหา (ฝั่งซื้อค้นประกาศขาย, ฝั่งขายค้นประกาศตั้งรับ)
  final String hintText;

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenMap;
  // สีปุ่มแผนที่: ฝั่งซื้อ = เขียวอ่อน, ฝั่งขาย = ส้มอ่อน
  final bool isBuyerMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64.0,
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: kBorderColor),
          const SizedBox(width: 12.0),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 16.0),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: kHintColor,
                  fontWeight: FontWeight.bold,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          // ปุ่มเลือกสนามจากแผนที่
          InkWell(
            borderRadius: BorderRadius.circular(22.0),
            onTap: onOpenMap,
            child: Container(
              height: 44.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: isBuyerMode
                    ? kBuyerColor.withValues(alpha: 0.25)
                    : kSellerColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22.0),
              ),
              child: const Row(
                children: [
                  Icon(Icons.map_outlined, size: 20.0, color: kBorderColor),
                  SizedBox(width: 6.0),
                  Text(
                    'แผนที่',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: kBorderColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
