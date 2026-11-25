import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/order_model.dart';

// การ์ดประกาศของฉัน 1 รายการ (หน้าตาเดียวกับ ListingCard)
// ถ้ามีคนซื้อแล้ว จะมีชื่อผู้ซื้อ + เลขคำสั่งซื้อ, ผู้ซื้อแจ้งปัญหา = ป้ายสถานะสีแดง
class SellerListingCard extends StatelessWidget {
  const SellerListingCard({super.key, required this.item, this.onTap});

  final SellerListing item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kCardBorderColor),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: .start,
                  children: [
                    SportIconBox(sport: item.listing.sport),
                    const SizedBox(width: 12.0),
                    Expanded(child: _buildInfo()),
                    const SizedBox(width: 8.0),
                    SellerStatusChip(item: item),
                  ],
                ),
              ),
              if (item.hasMatchingRequests) _buildRequestRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    final listing = item.listing;
    final order = item.order;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          listing.title,
          style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4.0),
        Text(
          '${thaiShortDate(listing.startTime)} · '
          '${hourMinuteText(listing.startTime)}–${hourMinuteText(listing.endTime)}',
          style: const TextStyle(color: kSubtextColor),
        ),
        const SizedBox(height: 2.0),
        // มีคนซื้อแล้ว: แสดงชื่อผู้ซื้อ + เลขคำสั่งซื้อ (แบบเดียวกับการซื้อของฉัน เช่น CS-00012)
        Text(
          order != null
              ? 'ผู้ซื้อ: ${order.buyerName}'
                    '${order.reference.isEmpty ? '' : ' · ${order.reference}'}'
              : '฿${listing.price}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.0,
            color: kHintColor,
            fontWeight: order != null ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // แถวบอกว่ามีผู้ซื้อตั้งรับตรงกับประกาศนี้ (A5) แตะการ์ดเพื่อดูรายชื่อผู้ตั้งรับ
  Widget _buildRequestRow() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 14.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: kSellerColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search_outlined, size: 20.0),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              'มีผู้ตั้งรับตรง ${item.requestCount} คน · ระบบแจ้งเตือนผู้ซื้อแล้ว',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

// กล่องไอคอนกีฬา ใช้แทนรูปสนาม
// isBuyerMode = true ใช้พื้นเขียวอ่อนฝั่งซื้อ ไม่งั้นพื้นส้มอ่อนฝั่งขาย
class SportIconBox extends StatelessWidget {
  const SportIconBox({
    super.key,
    required this.sport,
    this.size = 48.0,
    this.isBuyerMode = false,
  });

  final String sport;
  final double size;
  final bool isBuyerMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isBuyerMode
            ? kBuyerSoftColor
            : kSellerColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Icon(
        sport == kSportBadminton ? Icons.sports : Icons.sports_tennis,
        size: size * 0.5,
        color: kBorderColor,
      ),
    );
  }
}

// ป้ายสถานะของประกาศ/ออเดอร์ (สีชุดเดียวกับ StatusChip ใน listing_card)
class SellerStatusChip extends StatelessWidget {
  const SellerStatusChip({super.key, required this.item});

  final SellerListing item;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    final status = item.order?.status;
    if (status == kOrderDisputed) {
      // ผู้ซื้อแจ้งปัญหา: ป้ายสีแดง (มีข้อพิพาท / รอแอดมินตัดสิน)
      background = kAlertBackground;
      foreground = kAlertColor;
    } else if (status == kOrderReleased) {
      background = kSuccessSoftColor;
      foreground = kSuccessTextColor;
    } else if (status != null && status != kOrderRefunded) {
      // จ่ายแล้ว / รอยืนยัน / รอโอน
      background = kSellerSoftColor;
      foreground = kSellerTextColor;
    } else {
      // ยังไม่มีคนซื้อ / หมดเวลา / คืนเงินแล้ว
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
        item.statusLabel,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}
