import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/models/court_model.dart';

// หน้าเลือกสนามจากแผนที่: ปักหมุดสนามทุกแห่ง แตะหมุดแล้วกด "เลือกสนามนี้"
// ปิดหน้าแล้วส่งสนามที่เลือกกลับไป (Navigator.pop(context, court))
// ใช้แผนที่ OpenStreetMap ไม่ต้องมี API key
// ใช้ได้ทั้งฝั่งขาย (เลือกสนามที่จะลงประกาศ) และฝั่งซื้อ (ค้นหาประกาศของสนามนั้น)
class CourtMapPage extends StatefulWidget {
  const CourtMapPage({
    super.key,
    required this.courts,
    this.selectedCourt,
    this.isBuyerMode = false,
    this.buttonLabel = 'เลือกสนามนี้',
  });

  // ข้อความบนปุ่มด้านล่าง (หน้าหลักฝั่งซื้อใช้ "ดูประกาศของสนามนี้")
  final String buttonLabel;

  final List<Court> courts;
  final Court? selectedCourt;
  // true = ใช้สีฝั่งซื้อ (เขียว), false = สีฝั่งขาย (ส้ม)
  final bool isBuyerMode;

  @override
  State<CourtMapPage> createState() => _CourtMapPageState();
}

class _CourtMapPageState extends State<CourtMapPage> {
  // ใจกลางกรุงเทพ ใช้เมื่อไม่มีสนามที่มีพิกัด
  static const LatLng _bangkok = LatLng(13.7563, 100.5018);

  Court? tappedCourt;

  @override
  void initState() {
    super.initState();
    tappedCourt = widget.selectedCourt;
  }

  // สนามที่ยังไม่มีพิกัด (0, 0) จะไม่ปักหมุด
  List<Court> get _courtsWithLocation {
    return widget.courts
        .where((court) => court.latitude != 0.0 || court.longitude != 0.0)
        .toList();
  }

  // เปิดแผนที่ที่สนามที่เลือกไว้ ถ้ายังไม่เลือกให้อยู่กลางสนามทั้งหมด
  LatLng _initialCenter() {
    final court = tappedCourt;
    if (court != null) {
      return LatLng(court.latitude, court.longitude);
    }

    final courts = _courtsWithLocation;
    if (courts.isEmpty) {
      return _bangkok;
    }

    double latitude = 0.0;
    double longitude = 0.0;
    for (final court in courts) {
      latitude += court.latitude;
      longitude += court.longitude;
    }
    return LatLng(latitude / courts.length, longitude / courts.length);
  }

  @override
  Widget build(BuildContext context) {
    final courts = _courtsWithLocation;

    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'เลือกสนามจากแผนที่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _initialCenter(),
          initialZoom: 12.0,
          // แตะที่ว่างบนแผนที่ = ยกเลิกหมุดที่เลือก
          onTap: (tapPosition, point) {
            setState(() {
              tappedCourt = null;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.tennis_app',
          ),
          MarkerLayer(
            markers: List.generate(courts.length, (index) {
              final court = courts[index];
              final isSelected = tappedCourt?.id == court.id;
              return Marker(
                point: LatLng(court.latitude, court.longitude),
                width: 48.0,
                height: 48.0,
                // ให้ปลายหมุดชี้ที่ตำแหน่งสนามพอดี
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      tappedCourt = court;
                    });
                  },
                  child: Icon(
                    Icons.location_on,
                    size: 48.0,
                    color: isSelected ? _modeColor : kBorderColor,
                  ),
                ),
              );
            }),
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildPanel(),
          ),
        ),
      ),
    );
  }

  Color get _modeColor => widget.isBuyerMode ? kBuyerColor : kSellerColor;

  // แผงด้านล่าง: ยังไม่แตะหมุด = คำแนะนำ, แตะแล้ว = ชื่อสนาม + ปุ่มเลือก
  Widget _buildPanel() {
    final court = tappedCourt;
    if (court == null) {
      return const SizedBox(
        height: 56.0,
        child: Center(
          child: Text(
            'แตะหมุดบนแผนที่เพื่อเลือกสนาม',
            style: TextStyle(color: kSubtextColor),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: _modeColor),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                court.name,
                style: const TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        // ฝั่งซื้อใช้ปุ่มเขียวตัวหนังสือขาว ฝั่งขายใช้ปุ่มส้ม
        if (widget.isBuyerMode)
          BuyerButton(
            label: widget.buttonLabel,
            onPressed: () {
              Navigator.pop(context, court);
            },
          )
        else
          SellerButton(
            label: widget.buttonLabel,
            onPressed: () {
              Navigator.pop(context, court);
            },
          ),
      ],
    );
  }
}
