import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/new_listing_model.dart';

// หน้าลงประกาศสำเร็จ: สรุปประกาศที่เพิ่งลง (แบบเดียวกับ RequestSuccessPage)
class SellSuccessPage extends StatelessWidget {
  const SellSuccessPage({super.key, required this.listing});

  final NewListing listing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 48.0),
              Container(
                width: 88.0,
                height: 88.0,
                decoration: BoxDecoration(
                  color: kSellerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: const Icon(Icons.check, size: 40.0),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'ลงประกาศสำเร็จ',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text(
                'ประกาศเปิดขายในแอปแล้ว\n'
                'ประกาศจะถูกลบอัตโนมัติ ${listing.expireText}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kSubtextColor, height: 1.5),
              ),
              const SizedBox(height: 24.0),
              // สรุปประกาศ
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: kDividerColor),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            listing.courtName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            listing.details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kSubtextColor),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            listing.scheduleText,
                            style: const TextStyle(color: kSubtextColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Text(
                      '฿${listing.price}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SellerButton(
                label: 'ไปที่ประกาศของฉัน',
                onPressed: () {
                  // สลับไปแท็บ "ประกาศของฉัน" (โหมดขาย) แล้วกลับไปหน้าหลัก
                  context.read<HomeModel>().openMyListings();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'กลับหน้าหลัก',
                  style: TextStyle(
                    color: kSubtextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
