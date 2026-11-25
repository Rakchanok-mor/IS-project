import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';

// กล่องแนบรูป (เช่น หลักฐานการจอง / รูปประกอบการแจ้งปัญหา) ยังไม่แนบ = ปุ่มเลือกรูป, แนบแล้ว = รูปย่อ + เปลี่ยน
class AttachImageBox extends StatelessWidget {
  const AttachImageBox({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.title,
    required this.onTap,
    this.icon = Icons.add_photo_alternate_outlined,
    this.actionLabel = 'เลือกรูป',
  });

  final Uint8List? bytes;
  final String fileName;
  final String title;
  final VoidCallback? onTap;
  // ไอคอนและคำบนปุ่มตอนยังไม่แนบ (หน้าแจ้งปัญหาใช้กล้อง = ไอคอนกล้อง + "ถ่ายรูป")
  final IconData icon;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final image = bytes;

    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kBorderColor, width: 1.5),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: SizedBox(
                width: 56.0,
                height: 56.0,
                child: image == null
                    ? Container(
                        color: kNeutralSoftColor,
                        child: Icon(icon, color: kSubtextColor),
                      )
                    : Image.memory(image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    image == null ? title : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // แนบแล้วถึงจะมีบรรทัดบอกว่า "แนบแล้ว"
                  if (image != null) ...[
                    const SizedBox(height: 2.0),
                    const Text(
                      'แนบแล้ว',
                      style: TextStyle(fontSize: 13.0, color: kSuccessColor),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              image == null ? actionLabel : 'เปลี่ยน',
              style: const TextStyle(
                color: kSubtextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
