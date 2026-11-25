import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tennis_app/models/listing_model.dart';

// แท็บของเมนูด้านล่าง (3 แท็บ) บัญชีย้ายไปเป็นปุ่มกลมขวาบนของหน้าหลัก
// แท็บ "ของฉัน" เปลี่ยนตามโหมด: โหมดซื้อ = การซื้อของฉัน, โหมดขาย = ประกาศของฉัน
const int kTabHome = 0;
const int kTabMine = 1;
const int kTabNotifications = 2;

// แท็บย่อยในหน้าการซื้อของฉัน (การตั้งรับอยู่หน้าหลักโหมดซื้อ)
const int kPurchasesTabActive = 0; // กำลังดำเนินการ
const int kPurchasesTabHistory = 1; // ประวัติ

// เก็บสถานะของหน้าหลักที่ใช้ร่วมกันทั้งแอป:
// อยู่โหมดซื้อหรือขาย, เลือกกีฬาอะไร, อยู่แท็บไหนของเมนูด้านล่าง
class HomeModel extends ChangeNotifier {
  static const String _sportKey = 'last_sport';

  bool _isBuyerMode = true;
  String _sport = kSportTennis;
  int _selectedTab = 0;

  bool get isBuyerMode => _isBuyerMode;

  set isBuyerMode(bool value) {
    _isBuyerMode = value;
    notifyListeners();
  }

  String get sport => _sport;

  // เปลี่ยนกีฬาแล้วจำไว้ในเครื่อง เปิดแอปครั้งหน้าจะได้ไม่ต้องเลือกใหม่
  set sport(String value) {
    _sport = value;
    notifyListeners();
    _saveSport(value);
  }

  int get selectedTab => _selectedTab;

  set selectedTab(int value) {
    _selectedTab = value;
    notifyListeners();
  }

  // แท็บย่อยที่จะเปิดในหน้าการซื้อของฉัน (หน้านั้นอ่านค่านี้ตอนเปิด)
  int purchasesTab = kPurchasesTabActive;

  // ไปหน้าการซื้อของฉัน (สลับเป็นโหมดซื้อให้ด้วย)
  void openMyPurchases({int tab = kPurchasesTabActive}) {
    _isBuyerMode = true;
    purchasesTab = tab;
    _selectedTab = kTabMine;
    notifyListeners();
  }

  // ไปหน้าหลักโหมดซื้อ (ประกาศตั้งรับของฉันอยู่ที่นี่)
  void openBuyerHome() {
    _isBuyerMode = true;
    _selectedTab = kTabHome;
    notifyListeners();
  }

  // ไปหน้าประกาศของฉัน (สลับเป็นโหมดขายให้ด้วย)
  void openMyListings() {
    _isBuyerMode = false;
    _selectedTab = kTabMine;
    notifyListeners();
  }

  // อ่านกีฬาที่เลือกไว้ครั้งก่อน (ถ้าไม่เคยเลือกจะเป็นเทนนิส)
  Future<void> loadSavedSport() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSport = prefs.getString(_sportKey);

    if (savedSport != null && savedSport != _sport) {
      _sport = savedSport;
      notifyListeners();
    }
  }

  Future<void> _saveSport(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sportKey, value);
  }
}
