import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/buyer_button.dart';
import 'package:tennis_app/components/sport_switch.dart';
import 'package:tennis_app/controller/court_controller.dart';
import 'package:tennis_app/controller/request_controller.dart';
import 'package:tennis_app/models/court_model.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/request_model.dart';
import 'package:tennis_app/pages/08_requestSuccessPage.dart';
import 'package:tennis_app/pages/11_courtMapPage.dart';
import 'package:tennis_app/services/court_service.dart';
import 'package:tennis_app/services/request_service.dart';

// หน้าตั้งรับสนาม (ฝั่งผู้ซื้อ): เลือกกีฬา สนาม วันที่ และช่วงเวลาที่เล่นได้
// แล้วรอให้ระบบจับคู่กับประกาศของผู้ขายที่ตรงกัน
class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  CourtController courtController = CourtController(CourtSupabaseService());
  RequestController controller = RequestController(RequestSupabaseService());
  StreamSubscription<bool>? _courtSubscription;
  StreamSubscription<bool>? _syncSubscription;

  late String sport;
  List<Court> courts = List.empty();
  Court? selectedCourt;
  bool isLoadingCourts = false;
  bool isSaving = false;

  TextEditingController venueController = TextEditingController();
  FocusNode venueFocus = FocusNode();

  DateTime date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay startTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    // เริ่มจากกีฬาที่เลือกไว้ในหน้าหลัก
    sport = context.read<HomeModel>().sport;

    // ฟังสถานะโหลดรายชื่อสนาม
    _courtSubscription = courtController.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoadingCourts = syncState;
      });
    });
    // ฟังสถานะบันทึกการตั้งรับ
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSaving = syncState;
      });
    });

    // ถ้าพิมพ์แก้ชื่อหลังเลือกสนามแล้ว ถือว่ายังไม่ได้เลือก ต้องเลือกจากรายการใหม่
    // และ rebuild ทุกครั้งที่พิมพ์ เพื่ออัปเดตข้อความ "ไม่พบสนาม" ใต้ช่องค้นหา
    venueController.addListener(() {
      final court = selectedCourt;
      setState(() {
        if (court != null && venueController.text != court.name) {
          selectedCourt = null;
        }
      });
    });

    _loadCourts();
  }

  @override
  void dispose() {
    _courtSubscription?.cancel();
    _syncSubscription?.cancel();
    courtController.dispose();
    controller.dispose();
    venueController.dispose();
    venueFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    setState(() {
      selectedCourt = null;
      venueController.clear();
    });
    List<Court> result = List.empty();
    try {
      result = await courtController.fetchCourts(sport);
    } catch (error) {
      if (!mounted) return;
      _showMessage('โหลดรายชื่อสนามไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
    if (!mounted) return;
    setState(() {
      courts = result;
    });
  }

  void _selectCourt(Court court) {
    setState(() {
      selectedCourt = court;
      venueController.text = court.name;
    });
    venueFocus.unfocus();
  }

  // เลือกสนามจากแผนที่ (หน้าเดียวกับฝั่งขาย ใช้สีฝั่งซื้อ)
  Future<void> _openMap() async {
    venueFocus.unfocus();
    final Court? picked = await Navigator.push<Court>(
      context,
      MaterialPageRoute(
        builder: (context) => CourtMapPage(
          courts: courts,
          selectedCourt: selectedCourt,
          isBuyerMode: true,
        ),
      ),
    );
    if (picked != null) {
      _selectCourt(picked);
    }
  }

  // ปุ่มเปิดแผนที่ เลือกสนามจากหมุด
  Widget _buildMapButton() {
    final canOpen = !isLoadingCourts && courts.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: canOpen ? _openMap : null,
      child: Container(
        height: 56.0,
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        decoration: BoxDecoration(
          color: kBuyerColor.withValues(alpha: 0.25),
          border: Border.all(color: kBorderColor, width: 1.5),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Row(
          children: [
            Icon(Icons.map_outlined, size: 20.0, color: kBorderColor),
            SizedBox(width: 6.0),
            Text(
              'แผนที่',
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
                color: kBorderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ข้อความใต้ช่องค้นหา เมื่อไม่มีสนามให้เลือก (คืน null = ไม่ต้องแสดง)
  String? _venueHint() {
    if (isLoadingCourts || selectedCourt != null) return null;
    if (courts.isEmpty) {
      return 'ยังไม่มีสนาม${sportLabel(sport)}ในระบบ';
    }
    final keyword = venueController.text.trim();
    if (keyword.isNotEmpty && !courts.any((court) => court.matches(keyword))) {
      return 'ไม่พบสนาม "$keyword" ในหมวด${sportLabel(sport)} ลองพิมพ์ชื่ออื่นหรือเลือกจากแผนที่';
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        date = picked;
      });
    }
  }

  // แสดงเวลาแบบ 24 ชั่วโมง เช่น "17:00" ไม่ขึ้นกับการตั้งค่าของเครื่อง
  String _timeText(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  // เลือกเวลาแบบ 24 ชั่วโมง
  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
  }

  DateTime _onDate(TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final court = selectedCourt;
    if (court == null) {
      _showMessage('กรุณาเลือกสนาม');
      return;
    }

    final start = _onDate(startTime);
    final end = _onDate(endTime);
    if (!end.isAfter(start)) {
      _showMessage('เวลาสิ้นสุดต้องหลังเวลาเริ่ม');
      return;
    }
    if (!end.isAfter(DateTime.now())) {
      _showMessage('ช่วงเวลานี้ผ่านไปแล้ว');
      return;
    }

    final request = CourtRequest(sport, court.id, court.name, start, end);

    try {
      await controller.createRequest(request);
    } catch (error) {
      if (!mounted) return;
      _showMessage('ตั้งรับไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;

    // แทนที่หน้านี้ด้วยหน้าสำเร็จ กดกลับแล้วจะไปหน้าหลักเลย
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RequestSuccessPage(request: request),
      ),
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
          'ตั้งรับสนาม',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildLabel('กีฬา'),
          SportSwitch(
            sport: sport,
            onChanged: (String value) {
              sport = value;
              _loadCourts();
            },
          ),
          _buildLabel('สนาม'),
          // ช่องค้นหาชื่อสนาม + ปุ่มเลือกจากแผนที่ (แบบเดียวกับหน้าลงประกาศขาย)
          Row(
            children: [
              Expanded(child: _buildVenueField()),
              const SizedBox(width: 8.0),
              _buildMapButton(),
            ],
          ),
          if (_venueHint() != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0, left: 4.0),
              child: Text(
                _venueHint()!,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: kWarningTextColor,
                ),
              ),
            ),
          _buildLabel('วันที่'),
          _buildPickerBox(
            text: thaiShortDate(date, withYear: true),
            showArrow: true,
            onTap: _pickDate,
          ),
          _buildLabel('ช่วงเวลาที่เล่นได้'),
          Row(
            children: [
              Expanded(
                child: _buildPickerBox(
                  text: _timeText(startTime),
                  center: true,
                  onTap: () async {
                    final picked = await _pickTime(startTime);
                    if (picked != null) {
                      setState(() {
                        startTime = picked;
                      });
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('–', style: TextStyle(color: kHintColor)),
              ),
              Expanded(
                child: _buildPickerBox(
                  text: _timeText(endTime),
                  center: true,
                  onTap: () async {
                    final picked = await _pickTime(endTime);
                    if (picked != null) {
                      setState(() {
                        endTime = picked;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      // ปุ่มตั้งรับติดอยู่ด้านล่างเสมอ
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BuyerButton(
              label: 'ตั้งรับ',
              isLoading: isSaving,
              onPressed: _submit,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: kBorderColor, width: 1.5),
      borderRadius: BorderRadius.circular(16.0),
    );
  }

  // ช่องพิมพ์ชื่อสนาม พิมพ์แล้วขึ้นรายชื่อสนามที่ตรงให้เลือก (แบบเดียวกับหน้าลงประกาศขาย)
  Widget _buildVenueField() {
    if (isLoadingCourts) {
      return Container(
        height: 56.0,
        decoration: _boxDecoration(),
        child: const Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        ),
      );
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: const BorderSide(color: kBorderColor, width: 1.5),
    );

    return RawAutocomplete<Court>(
      textEditingController: venueController,
      focusNode: venueFocus,
      displayStringForOption: (Court court) => court.name,
      // ช่องว่าง = แสดงทุกสนาม, พิมพ์แล้ว = กรองทั้งชื่อไทยและอังกฤษ
      optionsBuilder: (TextEditingValue value) {
        return courts.where((court) => court.matches(value.text));
      },
      onSelected: _selectCourt,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'พิมพ์ชื่อสนาม',
            hintStyle: const TextStyle(
              color: kHintColor,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 18.0,
            ),
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: kBorderColor, width: 2.0),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Material(
              color: Colors.white,
              elevation: 4.0,
              borderRadius: BorderRadius.circular(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 240.0,
                  // กว้างเท่าช่องพิมพ์ (จอ - padding ซ้ายขวา)
                  maxWidth: MediaQuery.of(context).size.width - 32.0,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final court = options.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(court.name),
                      subtitle:
                          court.nameEn.isEmpty || court.nameEn == court.name
                          ? null
                          : Text(court.nameEn),
                      onTap: () {
                        onSelected(court);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // กล่องที่กดแล้วเปิดตัวเลือก (วันที่ / เวลา)
  Widget _buildPickerBox({
    required String text,
    required VoidCallback onTap,
    bool center = false,
    bool showArrow = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: onTap,
      child: Container(
        height: 56.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showArrow) const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }
}
