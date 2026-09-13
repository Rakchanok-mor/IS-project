import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/pages/01_sellerHomePage.dart';

class BuyerHomePage extends StatefulWidget {
  const BuyerHomePage({super.key});

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  // ชิปกรองที่เลือกอยู่
  int _selectedFilter = 0;
  final List<String> _filters = <String>['ทั้งหมด', 'วันนี้', 'ในร่ม', 'กลางแจ้ง'];

  // ข้อมูลสนามตัวอย่าง (ภายหลังจะดึงจาก Firestore)
  final List<CourtSlot> _courts = <CourtSlot>[
    CourtSlot(
      name: 'Beat Discovery Thailand',
      schedule: 'ส. 14 มี.ค. 18:00–20:00',
      price: 550,
    ),
    CourtSlot(
      name: 'Sirisuk Tennis Court',
      schedule: 'อา. 15 มี.ค. 07:00–09:00',
      price: 500,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSearchField('ค้นหาสนาม'),
                  const SizedBox(height: 12.0),
                  _buildRequestButton(),
                  const SizedBox(height: 12.0),
                  _buildFilterChips(),
                  const SizedBox(height: 12.0),
                  // รายการสนามที่ประกาศขาย
                  ...List.generate(_courts.length, (index) {
                    return CourtCard(courtSlot: _courts[index]);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ส่วนหัว: ชื่อแอป + ปุ่มสลับ ซื้อ/ขาย
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: kBorderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CourtMate',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // ออกจากระบบ แล้ว AuthGate จะพากลับไปหน้า login ให้เอง
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'ออกจากระบบ',
                onPressed: () {
                  // ล้าง username ที่จำไว้ ไม่งั้นหน้า login จะเติม email เดิมให้
                  context.read<LoginModel>().username = '';
                  FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              border: Border.all(color: kBorderColor),
              borderRadius: BorderRadius.circular(30.0),
            ),
            child: Row(
              children: [
                // อยู่หน้านี้อยู่แล้ว จึงไม่ต้องทำอะไรเมื่อกด
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      color: kBuyerColor,
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    child: const Center(
                      child: Text(
                        'ซื้อ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                // กดขาย = ไปหน้าฝั่งขาย
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30.0),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SellerHomePage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: const Center(
                        child: Text('ขาย'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(String hintText) {
    return TextField(
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: kBorderColor, width: 2.0),
        ),
      ),
    );
  }

  // ปุ่ม 'ตั้งรับสนาม' สำหรับประกาศว่าอยากได้สนามแบบไหน
  Widget _buildRequestButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ตั้งรับสนาม')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 16.0,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline),
            const SizedBox(width: 12.0),
            const Text('ตั้งรับสนาม'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      child: Row(
        children: List.generate(_filters.length, (index) {
          final bool isSelected = _selectedFilter == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20.0),
              onTap: () {
                setState(() {
                  _selectedFilter = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? kBuyerColor : Colors.white,
                  border: Border.all(color: kBorderColor),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// การ์ดแสดงสนาม 1 รายการ
class CourtCard extends StatelessWidget {
  const CourtCard({
    super.key,
    required this.courtSlot,
  });

  final CourtSlot courtSlot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          // รูปสนาม (ยังไม่มีรูปจริง ใช้กล่องว่างแทน)
          Container(
            width: 80.0,
            height: 80.0,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Center(
              child: Text(
                'court',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  courtSlot.name,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        courtSlot.schedule,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    Text(
                      '฿${courtSlot.price}',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ข้อมูลสนามที่ประกาศขาย 1 รายการ
class CourtSlot {
  const CourtSlot({
    required this.name,
    required this.schedule,
    required this.price,
  });

  final String name;
  final String schedule;
  final int price;
}
