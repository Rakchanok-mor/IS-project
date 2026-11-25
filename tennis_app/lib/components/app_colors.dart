import 'package:flutter/material.dart';

// สีประจำฝั่งซื้อ (เขียวเข้มแบบพื้นสนามเทนนิส)
const Color kBuyerColor = Color(0xFF2E6B45);

// สีตัวหนังสือบนพื้นสีฝั่งซื้อ (พื้นเข้ม ต้องใช้ตัวหนังสือสีขาว)
const Color kOnBuyerColor = Colors.white;

// เขียวอ่อนฝั่งซื้อ ใช้เป็นพื้นป้าย/กล่องไอคอน (คู่กับตัวหนังสือสี kBuyerColor)
const Color kBuyerSoftColor = Color(0xFFDCEAE1);

// เลือกสีตัวหนังสือให้อ่านออกบนพื้นสีนั้น ๆ
// พื้นเขียวเข้มฝั่งซื้อ = ขาว, พื้นสีอ่อนอื่น ๆ = ดำ
Color textColorOn(Color background) {
  if (background == kBuyerColor) {
    return kOnBuyerColor;
  }
  return kBorderColor;
}

// สีประจำฝั่งขาย (ส้มอ่อน) ใช้แยกให้เห็นว่าอยู่คนละโหมดกับฝั่งซื้อ
const Color kSellerColor = Color(0xFFF4A259);

// สีประจำหน้าแอดมิน (ม่วงอ่อน) ใช้โอนผู้ขายและคืนเงิน
const Color kAdminColor = Color(0xFFC9B8F5);

// สีพื้นหลังหน้าจอ (เทาอมครีมอ่อน) การ์ด/กล่องสีขาววางบนพื้นนี้จะแยกออกมาชัด
// ใช้กับ Scaffold + AppBar ทุกหน้า (ตั้งเป็นค่าเริ่มต้นใน theme ของ main.dart ด้วย)
// การ์ด, dialog, แถบเมนูล่าง, QR ยังเป็นสีขาว
const Color kPageColor = Color(0xFFF7F7F4);

// พื้นกล่องข้อความแบบจาง (เช่น กล่อง "หลังกดลงประกาศ", สถานะที่จบแล้ว)
// เข้มกว่าพื้นหน้าจอนิดหนึ่ง จะได้ยังเห็นเป็นกล่องบนพื้น kPageColor
const Color kMutedColor = Color(0xFFEDEDE7);

// สีเส้นขอบของกล่อง/ปุ่มต่าง ๆ
const Color kBorderColor = Color(0xFF1A1A1A);

// ---------- ตัวหนังสือ / ไอคอนโทนเทา ----------

// ตัวหนังสือรอง (วันเวลา, คำอธิบายใต้หัวข้อ)
const Color kSubtextColor = Color(0xFF5E5E5E);

// ตัวหนังสือบนป้ายสถานะแบบกลาง ๆ (คู่กับพื้น kNeutralSoftColor)
const Color kNeutralTextColor = Color(0xFF4A4A4A);

// ตัวหนังสือจาง / ไอคอนที่ยังกดไม่ได้ / คำใบ้
const Color kHintColor = Color(0xFF9E9E9E);

// ขั้นตอนที่ยังมาไม่ถึง (จางกว่า kHintColor)
const Color kDisabledColor = Color(0xFFBDBDBD);

// ---------- เส้นและพื้นโทนเทา ----------

// เส้นคั่น / ขอบกล่องบนหน้าจอ
const Color kDividerColor = Color(0xFFE4E4DF);

// เส้นคั่นภายในการ์ด (อ่อนกว่า kDividerColor)
const Color kSoftDividerColor = Color(0xFFEDEDE8);

// ขอบการ์ดรายการ (การ์ดสีขาววางบนพื้น kPageColor)
const Color kCardBorderColor = Color(0xFFDEDED8);

// พื้นป้ายสถานะแบบกลาง ๆ / กล่องรูปที่ยังไม่ได้แนบ
const Color kNeutralSoftColor = Color(0xFFF1F1EE);

// ---------- ฝั่งขาย ----------

// ตัวหนังสือน้ำตาลบนพื้นส้มอ่อนของฝั่งขาย
const Color kSellerTextColor = Color(0xFF6B4A27);

// ส้มอ่อนฝั่งขาย ใช้เป็นพื้นป้ายสถานะ "จ่ายแล้ว / รอโอน"
const Color kSellerSoftColor = Color(0xFFFCEBD9);

// ---------- สถานะสำเร็จ / แจ้งเตือน ----------

// ป้าย "ขายแล้ว / โอนแล้ว": ตัวหนังสือเขียวมะกอกบนพื้นเขียวอ่อน
const Color kSuccessTextColor = Color(0xFF3A4A0E);
const Color kSuccessSoftColor = Color(0xFFE3EFC0);

// ข้อความสำเร็จ (เช่น อ่านสลิปผ่าน)
const Color kSuccessColor = Color(0xFF3A7A1E);

// สีแดงสำหรับเรื่องที่ต้องรีบจัดการ (ผู้ซื้อแจ้งปัญหา, ใกล้หมดเวลาจ่าย)
const Color kAlertColor = Color(0xFFD93025);
const Color kAlertBackground = Color(0xFFFDECEA);

// ข้อความเตือนเล็ก ๆ ใต้ช่องกรอก
const Color kWarningTextColor = Color(0xFFD9534F);
