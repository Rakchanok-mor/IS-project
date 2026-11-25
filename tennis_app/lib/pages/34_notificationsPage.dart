import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/controller/notification_controller.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/notification_model.dart';
import 'package:tennis_app/pages/16_paymentStatusPage.dart';

// แท็บ "แจ้งเตือน" รวมทั้งฝั่งซื้อและฝั่งขาย ติดป้ายบอกว่าเป็นฝั่งไหน
// ใช้ StreamBuilder ฟังแจ้งเตือนจาก controller มีอันใหม่เข้ามา หน้าจอวาดใหม่เอง
// แตะ = อ่านแล้ว + สลับโหมดให้ + เปิดหน้าที่เกี่ยวข้อง
// อยู่ในหน้าหลัก (HomePage) จึงไม่มี Scaffold ของตัวเอง
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.controller});

  // controller อยู่ที่หน้าหลัก เพราะตัวเลขบนกระดิ่งก็ฟังจากตัวเดียวกัน
  final NotificationController controller;

  // แตะแจ้งเตือน: ฝั่งซื้อที่มีคำสั่งซื้อ = หน้าสถานะคำสั่งซื้อ
  // ฝั่งซื้อที่ไม่มีคำสั่งซื้อ (สนามตรง) = หน้าหลักโหมดซื้อ (ประกาศตั้งรับของฉัน)
  // ฝั่งขาย = ประกาศของฉัน
  Future<void> _open(BuildContext context, AppNotification notification) async {
    final home = context.read<HomeModel>();
    controller.markRead(notification);

    final orderId = notification.orderId;
    if (notification.isBuyer && orderId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentStatusPage(orderId: orderId),
        ),
      );
    } else if (notification.isBuyer) {
      home.openBuyerHome();
    } else {
      home.openMyListings();
    }
  }

  Future<void> _markAllRead(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.markAllRead();
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('อ่านทั้งหมดไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: controller.onNotifications,
      initialData: controller.notifications,
      builder: (context, snapshot) {
        final items = snapshot.data ?? List.empty();
        final hasUnread = items.any((item) => item.isUnread);

        return Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 8.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'แจ้งเตือน',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // มีที่ยังไม่อ่านถึงจะกดได้
                  TextButton.icon(
                    onPressed: hasUnread ? () => _markAllRead(context) : null,
                    icon: const Icon(Icons.done_all, size: 18.0),
                    label: const Text(
                      'อ่านทั้งหมด',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(foregroundColor: kBorderColor),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildList(context, snapshot, items)),
          ],
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    AsyncSnapshot<List<AppNotification>> snapshot,
    List<AppNotification> items,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Text(
          'โหลดแจ้งเตือนไม่สำเร็จ',
          style: TextStyle(color: kSubtextColor),
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีแจ้งเตือน',
          style: TextStyle(color: kSubtextColor),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildItem(context, items[index]);
      },
    );
  }

  Widget _buildItem(BuildContext context, AppNotification notification) {
    final isUnread = notification.isUnread;
    final isUrgent = notification.isUrgent;

    // สีตามฝั่ง: ซื้อ = เขียว, ขาย = ส้ม, เร่งด่วน = แดง
    Color sideColor = notification.isBuyer ? kBuyerColor : kSellerColor;
    Color background = Colors.white;
    if (isUrgent && isUnread) {
      background = kAlertBackground;
    } else if (isUnread) {
      background = notification.isBuyer
          ? kBuyerSoftColor.withValues(alpha: 0.5)
          : kSellerColor.withValues(alpha: 0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () => _open(context, notification),
        child: Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: isUrgent && isUnread ? kAlertColor : kCardBorderColor,
              width: isUrgent && isUnread ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            crossAxisAlignment: .start,
            children: [
              // จุดบอกว่ายังไม่อ่าน
              Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.only(top: 6.0, right: 10.0),
                decoration: BoxDecoration(
                  color: isUnread
                      ? (isUrgent ? kAlertColor : sideColor)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      children: [
                        _buildSideChip(notification),
                        if (notification.sport != null) ...[
                          const SizedBox(width: 6.0),
                          _buildSportChip(notification.sport!),
                        ],
                        const SizedBox(width: 8.0),
                        Text(
                          notification.createdAtText,
                          style: const TextStyle(
                            fontSize: 12.0,
                            color: kHintColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isUrgent ? kAlertColor : kBorderColor,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 13.0,
                          color: kSubtextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kHintColor),
            ],
          ),
        ),
      ),
    );
  }

  // ป้ายกีฬา "เทนนิส" / "แบดมินตัน" (สีเทา ไม่แย่งความสนใจจากป้ายซื้อ/ขาย)
  Widget _buildSportChip(String sport) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: kMutedColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        sportLabel(sport),
        style: const TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.bold,
          color: kNeutralTextColor,
        ),
      ),
    );
  }

  // ป้าย "ซื้อ" / "ขาย"
  Widget _buildSideChip(AppNotification notification) {
    final isBuyer = notification.isBuyer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isBuyer ? kBuyerSoftColor : kSellerColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        isBuyer ? 'ซื้อ' : 'ขาย',
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.bold,
          color: isBuyer ? kBuyerColor : kSellerTextColor,
        ),
      ),
    );
  }
}
