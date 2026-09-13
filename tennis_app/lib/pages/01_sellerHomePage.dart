import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/models/login_model.dart';
import 'package:tennis_app/pages/02_buyerHomePage.dart';

class SellerHomePage extends StatefulWidget {
  const SellerHomePage({super.key});

  @override
  State<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  // ประกาศของเราที่ยังขายไม่ออก (ภายหลังจะดึงจาก Firestore)
  final List<SellerListing> _listings = <SellerListing>[
    SellerListing(
      name: 'ธรรมศาสตร์ รังสิต · คอร์ต 3',
      date: 'ส. 14 มี.ค.',
      price: 350,
      views: 41,
    ),
    SellerListing(
      name: 'เมืองทอง อินดอร์ · คอร์ต 1',
      date: 'อา. 15 มี.ค.',
      price: 500,
      views: 8,
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
                  _buildSummaryBar(),
                  const SizedBox(height: 12.0),
                  // รายการประกาศของเรา
                  ...List.generate(_listings.length, (index) {
                    return ListingCard(listing: _listings[index]);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ส่วนหัว: ชื่อแอป + ปุ่มสลับ ซื้อ/ขาย (ตอนนี้อยู่ฝั่งขาย)
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
                // กดซื้อ = กลับไปหน้าฝั่งซื้อ
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30.0),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BuyerHomePage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: const Center(
                        child: Text('ซื้อ'),
                      ),
                    ),
                  ),
                ),
                // อยู่หน้านี้อยู่แล้ว จึงไม่ต้องทำอะไรเมื่อกด
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      color: kSellerColor,
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    child: const Center(
                      child: Text(
                        'ขาย',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  // แถบสรุป: จำนวนที่ขายค้างอยู่ + ปุ่มลงประกาศใหม่
  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ขายค้างอยู่ ${_listings.length} รายการ',
              style: const TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20.0),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ลงประกาศขายสนาม')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: kSellerColor,
                border: Border.all(color: kBorderColor),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: const Text(
                '+ ลงประกาศ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// การ์ดประกาศขาย 1 รายการ
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
  });

  final SellerListing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.name,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '฿${listing.price}',
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            '${listing.date} · เข้าชม ${listing.views}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ข้อมูลประกาศขาย 1 รายการ
class SellerListing {
  const SellerListing({
    required this.name,
    required this.date,
    required this.price,
    required this.views,
  });

  final String name;
  final String date;
  final int price;
  final int views;
}
