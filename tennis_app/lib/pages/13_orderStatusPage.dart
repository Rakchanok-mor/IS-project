import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/home_button.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/components/seller_listing_card.dart';
import 'package:tennis_app/components/step_indicator.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/pages/25_disputeResponsePage.dart';

// หน้าสถานะประกาศ 1 รายการ (ฝั่งผู้ขาย) กดได้ทุกประกาศ ทั้งที่มีและยังไม่มีผู้ซื้อ
// - กล่องสรุป: อยู่ขั้นไหน เหลืออีกกี่ขั้นจะได้เงิน
// - ขั้นตอน: ผู้ซื้อกดซื้อ → ผู้ซื้อชำระเงิน → ผู้ซื้อยืนยันการเล่น → Courtswap โอนเงินให้คุณ
// - เงินที่จะได้รับ: ราคาขาย - ค่าธรรมเนียมแพลตฟอร์ม
// ถ้าผู้ซื้อแจ้งปัญหา (A9) กดไปหน้าชี้แจง + ส่งหลักฐาน (A13) ได้จากหน้านี้
class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key, required this.item});

  final SellerListing item;

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  SellerListing get item => widget.item;

  Order? get order => widget.item.order;

  // ไปหน้าชี้แจง (A13) กลับมาแล้ววาดใหม่ (ข้อมูลหลักฐานถูกเก็บในออเดอร์เดิม)
  Future<void> _openResponse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DisputeResponsePage(item: item)),
    );
    if (!mounted) return;
    setState(() {});
  }

  // กลับแท็บหน้าหลัก (ปิดทุกหน้าที่ซ้อนอยู่)
  void _goHome() {
    context.read<HomeModel>().selectedTab = kTabHome;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final current = order;
    final isExpired = current == null && item.isPlayed;

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        // ไม่มีลูกศร back ใช้ปุ่มกลับหน้าหลักด้านล่างแทน
        automaticallyImplyLeading: false,
        title: const Text(
          'สถานะประกาศ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: SellerStatusChip(item: item)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSummary(),
          // กล่องสรุปแสดงเฉพาะตอนจบแล้ว (หมดเวลา / คืนเงินผู้ซื้อ / ได้รับเงินแล้ว)
          // ระหว่างดำเนินการดูความคืบหน้าจากไทม์ไลน์แทน
          // มีข้อพิพาท: ใช้กล่องผู้ซื้อแจ้งปัญหาด้านล่างแทน
          if (!item.isDisputed && _isFinished) ...[
            const SizedBox(height: 16.0),
            _buildProgress(),
          ],
          if (item.isDisputed) ...[
            const SizedBox(height: 16.0),
            _buildDispute(current!),
          ],
          // ประกาศหมดเวลา (ไม่มีผู้ซื้อ): ไม่แสดงไทม์ไลน์และเงินที่จะได้รับ
          if (!isExpired) ...[
            const SizedBox(height: 16.0),
            _buildSteps(),
            const SizedBox(height: 16.0),
            _buildMoney(),
          ],
          if (current != null) ...[
            const SizedBox(height: 16.0),
            _buildDetails(current),
          ],
        ],
      ),
      // ปุ่มกลับหน้าหลัก (เต็มความกว้าง ขนาดเท่าปุ่มอื่น) อยู่บนสุด
      // ตอนต้องส่งหลักฐานโต้แย้ง มีปุ่มชี้แจงขนาดเล็กลงไว้ข้างใต้ (ส่งแล้วปุ่มหาย แก้ไขไม่ได้)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HomeButton(onPressed: _goHome),
                if (item.canSendEvidence) ...[
                  const SizedBox(height: 12.0),
                  SellerButton(
                    label: 'ชี้แจง + ส่งหลักฐาน',
                    height: 44.0,
                    fontSize: 15.0,
                    onPressed: _openResponse,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // สรุปประกาศ + ราคาขาย
  Widget _buildSummary() {
    final listing = item.listing;
    final details = listing.details.trim();
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              SportIconBox(sport: listing.sport),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      listing.scheduleText,
                      style: const TextStyle(color: kSubtextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '฿${item.saleAmount}',
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // รายละเอียดที่ผู้ขายกรอกตอนลงประกาศ (ไม่ได้กรอก = ไม่แสดง)
          if (details.isNotEmpty) ...[
            const Divider(height: 24.0, color: kSoftDividerColor),
            const Text(
              'รายละเอียด',
              style: TextStyle(fontSize: 13.0, color: kHintColor),
            ),
            const SizedBox(height: 4.0),
            Text(
              details,
              style: const TextStyle(color: kNeutralTextColor, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  // จบแล้วหรือยัง: ประกาศหมดเวลาไม่มีผู้ซื้อ / คืนเงินผู้ซื้อ / โอนให้เราแล้ว
  bool get _isFinished {
    final current = order;
    if (current == null) return item.isPlayed;
    return item.isRefundedToBuyer || current.status == kOrderReleased;
  }

  // กล่องสรุปผล (แสดงเฉพาะตอน _isFinished)
  Widget _buildProgress() {
    final current = order;

    IconData icon;
    String title;
    String message;
    Color background = kSellerColor.withValues(alpha: 0.2);
    Color border = kBorderColor;

    if (current == null) {
      icon = Icons.event_busy;
      title = 'ประกาศหมดเวลา';
      message = 'ไม่มีผู้ซื้อก่อนถึงเวลาเล่น';
      background = kMutedColor;
      border = kCardBorderColor;
    } else if (item.isRefundedToBuyer) {
      icon = Icons.replay;
      title = 'คืนเงินให้ผู้ซื้อ';
      message = current.rejectReason.isEmpty
          ? 'ออเดอร์นี้ไม่มีการโอนเงินให้คุณ'
          : current.rejectReason;
      background = kMutedColor;
      border = kCardBorderColor;
    } else {
      // โอนให้ผู้ขายแล้ว (released)
      icon = Icons.check_circle_outline;
      title = 'ได้รับเงินแล้ว ฿${current.sellerPayout}';
      message = current.releasedAt == null
          ? 'Courtswap โอนเข้าบัญชีรับเงินของคุณแล้ว'
          : 'โอนเมื่อ ${thaiDateTime(current.releasedAt!)}';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(icon, color: border == kAlertColor ? kAlertColor : kBorderColor),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  message,
                  style: const TextStyle(color: kSubtextColor, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // กล่องแจ้งปัญหาจากผู้ซื้อ
  Widget _buildDispute(Order current) {
    final sent = current.hasEvidence;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kAlertBackground,
        border: Border.all(color: kAlertColor, width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(
            'ผู้ซื้อแจ้งปัญหา',
            style: TextStyle(fontWeight: FontWeight.bold, color: kAlertColor),
          ),
          const SizedBox(height: 8.0),
          if (current.disputeCategory.isNotEmpty)
            Text(
              current.disputeCategory,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          Text(
            current.disputeReason.isEmpty ? '-' : current.disputeReason,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 8.0),
          Text(
            sent
                ? 'คุณส่งหลักฐานแล้ว ทีมงานกำลังตรวจสอบ'
                : item.canSendEvidence
                ? 'ส่งหลักฐานว่าผู้ซื้อได้ใช้สนามจริงภายใน '
                      '${thaiDateTime(current.evidenceDeadline!)} '
                      'ไม่งั้นระบบจะคืนเงินให้ผู้ซื้อ'
                : 'เลยเวลาส่งหลักฐานแล้ว',
            style: const TextStyle(fontSize: 13.0, color: kSubtextColor),
          ),
        ],
      ),
    );
  }

  // ขั้นตอนกว่าจะได้เงิน (แนวตั้ง)
  Widget _buildSteps() {
    final current = item.sellerStep;
    final paidAt = order?.paidAt;
    final confirmedAt = order?.confirmedAt;
    final releasedAt = order?.releasedAt;

    final List<List<String>> steps = [
      [
        'ผู้ซื้อกดซื้อ',
        order == null ? 'รอผู้ซื้อ' : 'ผู้ซื้อ ${order!.buyerName}',
      ],
      [
        'ผู้ซื้อชำระเงิน',
        paidAt != null
            ? 'เงินพักไว้ที่ Courtswap · ${thaiDateTime(paidAt)}'
            : 'ผู้ซื้อสแกนจ่าย ระบบยืนยันอัตโนมัติ',
      ],
      // ผู้ซื้อแจ้งปัญหา: ขั้นที่ 3 เปลี่ยนจากยืนยันการเล่นเป็นข้อพิพาท
      if (order?.wasDisputed ?? false)
        ['ผู้ซื้อแจ้งปัญหา', _disputeStepText(order!)]
      else
        [
          'ผู้ซื้อยืนยันการเล่น',
          confirmedAt != null
              ? thaiDateTime(confirmedAt)
              : 'หลังเล่น ${item.listing.scheduleText}',
        ],
      [
        'Courtswap โอนเงินให้คุณ',
        releasedAt != null
            ? '฿${item.payoutAmount} · ${thaiDateTime(releasedAt)}'
            : 'โอนอัตโนมัติหลังผู้ซื้อยืนยัน',
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ไทม์ไลน์คำสั่งซื้อ',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${current.clamp(0, kSellerSteps)}/$kSellerSteps',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kSubtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          ...List.generate(steps.length, (index) {
            return _buildStepRow(
              index: index,
              current: item.isRefundedToBuyer ? -1 : current,
              // ขั้นปัจจุบันฝั่งผู้ขายคือสิ่งที่ยังรออยู่ (ผู้ซื้อซื้อ/จ่าย/ยืนยัน, โอนเงิน)
              // ยังไม่เกิด = วงกลมสีเทา ยกเว้นข้อพิพาทที่ผู้ซื้อแจ้งมาแล้วจริง
              currentWaiting: order?.status != kOrderDisputed,
              title: steps[index][0],
              subtitle: steps[index][1],
              isLast: index == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }

  // ข้อความใต้ขั้น "ผู้ซื้อแจ้งปัญหา": รอชี้แจง → รอแอดมินตัดสิน → ผลตัดสิน
  String _disputeStepText(Order current) {
    if (current.resolution == kResolutionSeller) {
      return 'ผลตัดสิน: โอนเงินให้คุณ';
    }
    if (current.resolution == kResolutionBuyer) {
      return 'ผลตัดสิน: คืนเงินผู้ซื้อ';
    }
    if (current.hasEvidence) return 'ส่งหลักฐานแล้ว รอแอดมินตัดสิน';
    return 'รอคุณชี้แจงภายใน ${thaiDateTime(current.evidenceDeadline!)}';
  }

  Widget _buildStepRow({
    required int index,
    required int current,
    required bool currentWaiting,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    // ขั้นที่ยังรออยู่: วงกลมสีเทาแบบขั้นที่ยังไม่ถึง แต่ข้อความยังเข้มให้รู้ว่ารออะไร
    final isWaiting = currentWaiting && index == current;
    final isActive = index <= current;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: .start,
        children: [
          // วงกลม + เส้นต่อลงไปขั้นถัดไป
          Column(
            children: [
              StepDot(
                number: index + 1,
                step: index,
                // ยังรออยู่ = ส่งขั้นก่อนหน้าเป็นขั้นปัจจุบัน วงกลมนี้จะเป็นสีเทา
                currentStep: isWaiting ? current - 1 : current,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    color: index < current ? kBorderColor : kDividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: isLast ? 0.0 : 20.0),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? kBorderColor : kHintColor,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.0,
                      color: isActive ? kSubtextColor : kDisabledColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // เงินที่จะได้รับ: ราคาขาย - ค่าธรรมเนียมแพลตฟอร์ม
  Widget _buildMoney() {
    final isReleased = order?.status == kOrderReleased;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(
            'เงินที่จะได้รับ',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          _buildDetailRow('ราคาขาย', '฿${item.saleAmount}'),
          _buildDetailRow(
            'ค่าธรรมเนียมแพลตฟอร์ม',
            '-฿$kPlatformFee',
            valueColor: kAlertColor,
          ),
          const Divider(height: 16.0, color: kSoftDividerColor),
          Row(
            children: [
              Expanded(
                child: Text(
                  isReleased ? 'คุณได้รับ' : 'คุณจะได้รับ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                item.isRefundedToBuyer ? '฿0' : '฿${item.payoutAmount}',
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // รายละเอียดธุรกรรม (มีผู้ซื้อแล้วเท่านั้น)
  Widget _buildDetails(Order current) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text(
            'รายละเอียดธุรกรรม',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          _buildDetailRow('เลขที่คำสั่งซื้อ', current.reference),
          _buildDetailRow('ผู้ซื้อ', current.buyerName),
          if (current.paidAt != null)
            _buildDetailRow('ชำระเมื่อ', thaiDateTime(current.paidAt!)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Text(label, style: const TextStyle(color: kHintColor)),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? kBorderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: kCardBorderColor),
      borderRadius: BorderRadius.circular(16.0),
    );
  }
}
