import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/report_stat_tile.dart';
import 'package:tennis_app/components/tab_switch.dart';
import 'package:tennis_app/controller/report_controller.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/report_model.dart';
import 'package:tennis_app/services/report_service.dart';

// หน้ารายงานของแอดมิน เปิดจากเมนู "รายงาน" ในหน้าแรกแอดมิน
// แท็บ 1 = ยอดขายรายวัน/รายเดือน, แท็บ 2 = คำสั่งซื้อแยกตามสถานะ
class AdminReportPage extends StatefulWidget {
  const AdminReportPage({super.key});

  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  ReportController controller = ReportController(ReportSupabaseService());
  StreamSubscription<bool>? _syncSubscription;

  List<SalesReportRow> salesRows = List.empty();
  List<StatusReportRow> statusRows = List.empty();
  bool isLoading = false;
  int selectedTab = 0;
  String period = kReportDaily;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoading = syncState;
      });
    });
    _loadReports();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    try {
      await controller.fetchAdminReports(period);
    } catch (error) {
      _showLoadError();
      return;
    }
    if (!mounted) return;
    setState(() {
      salesRows = controller.salesRows;
      statusRows = controller.statusRows;
    });
  }

  // เปลี่ยนรายวัน/รายเดือน: รวมยอดใหม่จากออเดอร์ที่โหลดไว้แล้ว
  void _changePeriod(String newPeriod) {
    setState(() {
      period = newPeriod;
      salesRows = controller.changePeriod(newPeriod);
    });
  }

  void _showLoadError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('โหลดรายงานไม่สำเร็จ ลองใหม่อีกครั้ง')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'รายงาน (แอดมิน)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: TabSwitch(
              labels: const ['ยอดขาย', 'สถานะคำสั่งซื้อ'],
              selectedIndex: selectedTab,
              color: kAdminColor,
              onChanged: (int index) {
                setState(() {
                  selectedTab = index;
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                children: selectedTab == 0
                    ? _buildSalesReport()
                    : _buildStatusReport(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- รายงานยอดขาย ----------

  List<Widget> _buildSalesReport() {
    int orderCount = 0;
    int totalAmount = 0;
    int feeTotal = 0;
    for (final row in salesRows) {
      orderCount += row.orderCount;
      totalAmount += row.totalAmount;
      feeTotal += row.feeTotal;
    }
    final rangeText = period == kReportDaily
        ? '30 วันล่าสุด'
        : '12 เดือนล่าสุด';

    return [
      Row(
        children: [
          _buildPeriodChip('รายวัน', kReportDaily),
          const SizedBox(width: 8.0),
          _buildPeriodChip('รายเดือน', kReportMonthly),
          const Spacer(),
          Text(rangeText, style: const TextStyle(color: kSubtextColor)),
        ],
      ),
      const SizedBox(height: 12.0),
      ReportStatTile(
        label: 'ยอดขายรวม',
        value: '฿$totalAmount',
        color: kAdminColor.withValues(alpha: 0.25),
      ),
      const SizedBox(height: 8.0),
      Row(
        children: [
          Expanded(
            child: ReportStatTile(label: 'คำสั่งซื้อ', value: '$orderCount'),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: ReportStatTile(
              label: 'ค่าธรรมเนียมที่ได้',
              value: '฿$feeTotal',
            ),
          ),
        ],
      ),
      const SizedBox(height: 8.0),
      const Text(
        'นับเฉพาะคำสั่งซื้อที่ชำระแล้วและไม่ถูกคืนเงิน '
        'ค่าธรรมเนียมนับเมื่อโอนให้ผู้ขายแล้ว',
        style: TextStyle(fontSize: 12.0, color: kHintColor),
      ),
      const SizedBox(height: 16.0),
      if (isLoading && salesRows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (salesRows.isEmpty)
        _buildEmpty('ยังไม่มียอดขายในช่วงนี้')
      else
        _buildTable(
          headers: [
            period == kReportDaily ? 'วันที่' : 'เดือน',
            'รายการ',
            'ยอดขาย',
          ],
          rows: salesRows.map((row) {
            final label = period == kReportDaily
                ? thaiShortDate(row.periodStart, withYear: true)
                : thaiMonthYear(row.periodStart);
            return [label, '${row.orderCount}', '฿${row.totalAmount}'];
          }).toList(),
        ),
    ];
  }

  Widget _buildPeriodChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: period == value,
      selectedColor: kAdminColor,
      onSelected: (bool selected) {
        if (selected && period != value) {
          _changePeriod(value);
        }
      },
    );
  }

  // ---------- รายงานสถานะคำสั่งซื้อ ----------

  List<Widget> _buildStatusReport() {
    int total = 0;
    for (final row in statusRows) {
      total += row.orderCount;
    }

    return [
      ReportStatTile(
        label: 'คำสั่งซื้อทั้งหมด',
        value: '$total',
        color: kAdminColor.withValues(alpha: 0.25),
      ),
      const SizedBox(height: 16.0),
      if (isLoading && statusRows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (statusRows.isEmpty)
        _buildEmpty('ยังไม่มีคำสั่งซื้อ')
      else
        ...List.generate(statusRows.length, (index) {
          return _buildStatusRow(statusRows[index]);
        }),
    ];
  }

  // แถวสถานะ: ชื่อ + จำนวน + ยอดเงิน
  Widget _buildStatusRow(StatusReportRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(14.0),
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
                  row.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${row.orderCount} รายการ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'ยอดเงิน ฿${row.totalAmount}',
            style: const TextStyle(fontSize: 13.0, color: kSubtextColor),
          ),
        ],
      ),
    );
  }

  // ---------- ส่วนที่ใช้ร่วม ----------

  Widget _buildEmpty(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
        child: Text(text, style: const TextStyle(color: kSubtextColor)),
      ),
    );
  }

  // ตารางง่าย ๆ: คอลัมน์แรกชิดซ้าย ที่เหลือชิดขวา
  Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kCardBorderColor),
        borderRadius: BorderRadius.circular(16.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildTableRow(headers, isHeader: true),
          ...List.generate(rows.length, (index) {
            return _buildTableRow(rows[index]);
          }),
        ],
      ),
    );
  }

  Widget _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isHeader ? kNeutralSoftColor : Colors.white,
        border: const Border(bottom: BorderSide(color: kSoftDividerColor)),
      ),
      child: Row(
        children: List.generate(cells.length, (index) {
          return Expanded(
            flex: index == 0 ? 3 : 2,
            child: Text(
              cells[index],
              textAlign: index == 0 ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                fontSize: isHeader ? 13.0 : 14.0,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? kNeutralTextColor : kBorderColor,
              ),
            ),
          );
        }),
      ),
    );
  }
}
