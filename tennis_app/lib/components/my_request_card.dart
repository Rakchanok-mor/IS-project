import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/request_model.dart';

// การ์ดการตั้งรับ 1 รายการ (หน้าหลักโหมดซื้อ: ประกาศตั้งรับของฉัน)
// สนาม + ช่วงเวลา + สถานะ แล้วตามด้วยประกาศที่ระบบจับคู่ให้ (แตะเพื่อดู/ซื้อ)
// การ์ดแค่วาดหน้าจอ การเปิดประกาศ หน้าที่ใช้การ์ดเป็นคนส่งเข้ามา
class MyRequestCard extends StatelessWidget {
  const MyRequestCard({
    super.key,
    required this.request,
    required this.onOpenListing,
  });

  final MyRequest request;
  final void Function(Listing listing) onOpenListing;

  @override
  Widget build(BuildContext context) {
    final hasMatches = request.hasMatches;
    final chipText = hasMatches
        ? 'มีประกาศขายตรง ${request.matches.length}'
        : 'รอผู้ขาย';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: hasMatches ? kBorderColor : kCardBorderColor,
          width: hasMatches ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      request.courtName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      request.scheduleText,
                      style: const TextStyle(color: kSubtextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: hasMatches ? kBuyerColor : kNeutralSoftColor,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: hasMatches ? kOnBuyerColor : kNeutralTextColor,
                  ),
                ),
              ),
            ],
          ),
          // ประกาศที่ตรงกัน แตะเพื่อดูรายละเอียด/ซื้อ
          ...request.matches.map(_buildMatch),
        ],
      ),
    );
  }

  Widget _buildMatch(Listing listing) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => onOpenListing(listing),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: kBuyerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.0),
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
                    Text(
                      listing.scheduleText,
                      style: const TextStyle(
                        fontSize: 13.0,
                        color: kSubtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '฿${listing.price}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4.0),
              const Icon(Icons.chevron_right, size: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}
