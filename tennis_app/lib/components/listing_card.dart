import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/models/listing_model.dart';

// การ์ดประกาศ 1 รายการ
// showStatus = true ใช้ในโหมดผู้ขาย จะมีป้ายสถานะ (มีคนสนใจ / ขายแล้ว) แทนระยะทาง
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.showStatus = false,
    this.isMine = false,
    this.onTap,
  });

  final Listing listing;
  final bool showStatus;
  // ประกาศของผู้ใช้ที่ล็อกอินอยู่ (หน้าจอเช็กด้วย listing.isOwnedBy แล้วส่งมา)
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kCardBorderColor),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.title,
                      style: const TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    '฿${listing.price}',
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.scheduleText,
                      style: const TextStyle(color: kSubtextColor),
                    ),
                  ),
                  if (showStatus)
                    StatusChip(listing: listing)
                  // ฝั่งซื้อ: ประกาศของเราเองติดป้ายให้รู้ (ซื้อเองไม่ได้)
                  else if (isMine)
                    const MineChip()
                  else if (listing.distanceKm != null)
                    Text(
                      '${listing.distanceKm!.toStringAsFixed(1)} กม.',
                      style: const TextStyle(color: kSubtextColor),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ป้าย "ประกาศของคุณ" (ใช้ในฝั่งซื้อ ทั้งการ์ดและหน้ารายละเอียด)
class MineChip extends StatelessWidget {
  const MineChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: kBuyerSoftColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: const Text(
        'ประกาศของคุณ',
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: kBuyerColor,
        ),
      ),
    );
  }
}

// ป้ายสถานะของประกาศ (ใช้ในโหมดผู้ขาย)
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    String text;
    Color background;
    Color foreground;

    if (listing.status == kStatusSold) {
      text = 'ขายแล้ว';
      background = kSuccessSoftColor;
      foreground = kSuccessTextColor;
    } else {
      text = 'ยังไม่มีคนซื้อ';
      background = kNeutralSoftColor;
      foreground = kNeutralTextColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}
