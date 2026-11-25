import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/components/sport_switch.dart';
import 'package:tennis_app/components/step_indicator.dart';
import 'package:tennis_app/controller/court_controller.dart';
import 'package:tennis_app/controller/listing_controller.dart';
import 'package:tennis_app/controller/receipt_scan_controller.dart';
import 'package:tennis_app/models/court_model.dart';
import 'package:tennis_app/models/home_model.dart';
import 'package:tennis_app/models/listing_model.dart';
import 'package:tennis_app/models/new_listing_model.dart';
import 'package:tennis_app/models/order_model.dart';
import 'package:tennis_app/pages/10_sellSuccessPage.dart';
import 'package:tennis_app/services/court_service.dart';
import 'package:tennis_app/services/listing_service.dart';
import 'package:tennis_app/services/receipt_scan_service.dart';

// หน้าลงประกาศขาย (ฝั่งผู้ขาย) แบ่งเป็น 3 ขั้นในหน้าเดียว
// 1. สนามและเวลา  2. ราคาและหลักฐานการจอง  3. ตรวจสอบก่อนลงประกาศ
class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  CourtController courtController = CourtController(CourtSupabaseService());
  ListingController controller = ListingController(ListingSupabaseService());
  StreamSubscription<bool>? _courtSubscription;
  StreamSubscription<bool>? _syncSubscription;
  ReceiptScanController scanController = ReceiptScanController(
    ReceiptScanMlKitService(),
  );
  StreamSubscription<bool>? _scanSubscription;

  static const int _totalSteps = 3;
  int step = 0;
  bool isSaving = false;

  // ขั้นที่ 1: สนามและเวลา
  late String sport;
  List<Court> courts = List.empty();
  Court? selectedCourt;
  bool isLoadingCourts = false;
  TextEditingController venueController = TextEditingController();
  FocusNode venueFocus = FocusNode();
  TextEditingController detailsController = TextEditingController();
  DateTime date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 20, minute: 0);

  // ขั้นที่ 2: ราคาและหลักฐาน
  // ราคาที่จองมา = ราคาที่อ่านได้จากรูปหลักฐาน ผู้ขายพิมพ์เองไม่ได้
  TextEditingController bookedPriceController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  Uint8List? proofBytes;
  String proofFileName = '';
  bool isScanning = false;
  bool scanFailed = false;
  int? scannedPrice;

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

    // ปุ่มลงประกาศขึ้นวงโหลดตามสถานะจาก controller (แบบเดียวกับ PostPage)
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isSaving = syncState;
      });
    });

    // ฟังสถานะอ่านราคาจากรูปหลักฐาน
    _scanSubscription = scanController.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isScanning = syncState;
      });
    });

    // ถ้าพิมพ์แก้ชื่อสนามหลังเลือกแล้ว ถือว่ายังไม่ได้เลือก ต้องเลือกจากรายการใหม่
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
    _scanSubscription?.cancel();
    courtController.dispose();
    controller.dispose();
    scanController.dispose();
    venueController.dispose();
    venueFocus.dispose();
    detailsController.dispose();
    bookedPriceController.dispose();
    priceController.dispose();
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

  // ข้อความใต้ช่องค้นหา เมื่อไม่มีสนามให้เลือก (คืน null = ไม่ต้องแสดง)
  String? _venueHint() {
    if (isLoadingCourts || selectedCourt != null) return null;
    if (courts.isEmpty) {
      return 'ยังไม่มีสนาม${sportLabel(sport)}ในระบบ';
    }
    final keyword = venueController.text.trim();
    if (keyword.isNotEmpty && !courts.any((court) => court.matches(keyword))) {
      return 'ไม่พบสนาม "$keyword" ในหมวด${sportLabel(sport)} ลองพิมพ์ชื่ออื่น';
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- ขั้นที่ 1 ----------

  void _selectCourt(Court court) {
    setState(() {
      selectedCourt = court;
      venueController.text = court.name;
    });
    venueFocus.unfocus();
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

  // เลือกวันที่ (แบบเดียวกับหน้าตั้งรับฝั่งซื้อ)
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

  String? _checkStepOne() {
    if (selectedCourt == null) {
      return 'กรุณาเลือกสนามจากรายการ';
    }
    if (detailsController.text.trim().isEmpty) {
      return 'กรุณากรอกรายละเอียด';
    }
    final start = _onDate(startTime);
    final end = _onDate(endTime);
    if (!end.isAfter(start)) {
      return 'เวลาสิ้นสุดต้องหลังเวลาเริ่ม';
    }
    // ประกาศจะถูกลบเมื่อถึงเวลาเล่น จึงต้องเป็นเวลาที่ยังไม่ถึง
    if (!start.isAfter(DateTime.now())) {
      return 'เวลาเริ่มเล่นผ่านไปแล้ว';
    }
    return null;
  }

  // ---------- ขั้นที่ 2 ----------

  int? _readPrice(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  // ราคาขายห้ามเกินราคาที่จองมา (เช็กทุกครั้งที่พิมพ์ จะได้เห็นทันที)
  String? _priceError() {
    final booked = _readPrice(bookedPriceController);
    final price = _readPrice(priceController);
    if (booked != null && price != null && price > booked) {
      return 'ราคาขายต้องไม่เกินราคาที่จองมา (฿$booked)';
    }
    return null;
  }

  String? _checkStepTwo() {
    if (isScanning) {
      return 'กำลังตรวจหลักฐาน รอสักครู่';
    }
    if (proofBytes == null) {
      return 'กรุณาแนบหลักฐานการจอง';
    }
    if (scannedPrice == null) {
      return 'อ่านราคาจากหลักฐานไม่ได้ กรุณาแนบรูปที่เห็นยอดชำระชัดเจน';
    }
    final price = _readPrice(priceController);
    if (price == null || price <= 0) {
      return 'กรุณากรอกราคาขาย';
    }
    final priceError = _priceError();
    if (priceError != null) {
      return priceError;
    }
    return null;
  }

  Future<void> _pickProof() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600.0,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      // เปลี่ยนรูป = ล้างราคาเดิม แล้วอ่านจากรูปใหม่
      setState(() {
        proofBytes = bytes;
        proofFileName = file.name;
        scannedPrice = null;
        scanFailed = false;
        bookedPriceController.clear();
      });
      await _scanProof(file.path);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage(
        'เปิดรูปภาพไม่ได้ (${error.code}) ตรวจสอบการอนุญาตเข้าถึงรูปภาพ',
      );
    } catch (error) {
      // เช่น MissingPluginException: เพิ่ม plugin ใหม่แต่ยังไม่ได้ build แอปใหม่
      debugPrint('pickImage error: $error');
      if (!mounted) return;
      _showMessage('เปิดรูปภาพไม่ได้: $error');
    }
  }

  // อ่านราคาจากรูปหลักฐาน แล้วกรอกช่อง "ราคาที่จองมา" ให้เอง
  Future<void> _scanProof(String imagePath) async {
    int? price;
    try {
      price = await scanController.scanPrice(imagePath);
    } catch (error) {
      // เช่น รันบนเครื่องที่ ML Kit ไม่รองรับ (web / desktop)
      debugPrint('scanPrice error: $error');
    }
    if (!mounted) return;
    setState(() {
      scannedPrice = price;
      scanFailed = price == null;
      bookedPriceController.text = price == null ? '' : '$price';
    });
    if (price == null) {
      _showMessage('อ่านราคาจากหลักฐานไม่ได้ กรุณาแนบรูปที่เห็นยอดชำระชัดเจน');
    }
  }

  // ---------- เปลี่ยนขั้น / ส่งข้อมูล ----------

  void _next() {
    final error = step == 0 ? _checkStepOne() : _checkStepTwo();
    if (error != null) {
      _showMessage(error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      step++;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      step--;
    });
  }

  // กรอกอะไรไปแล้วบ้างหรือยัง (ใช้ตัดสินว่าต้องถามก่อนออกไหม)
  bool get _hasInput {
    return selectedCourt != null ||
        venueController.text.trim().isNotEmpty ||
        detailsController.text.trim().isNotEmpty ||
        bookedPriceController.text.trim().isNotEmpty ||
        priceController.text.trim().isNotEmpty ||
        proofBytes != null;
  }

  // ปุ่ม ✕ มุมบน: ออกจากฟอร์มทั้งหมด กรอกไปแล้วต้องยืนยันก่อน ข้อมูลจะได้ไม่หายโดยไม่ตั้งใจ
  Future<void> _confirmExit() async {
    FocusScope.of(context).unfocus();
    if (!_hasInput) {
      Navigator.pop(context);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('ยกเลิกการลงประกาศ?'),
          content: const Text('ข้อมูลที่กรอกไว้จะหายทั้งหมด'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('กรอกต่อ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;
    Navigator.pop(context);
  }

  // ใช้ได้หลังผ่านขั้นที่ 1 และ 2 แล้วเท่านั้น (ค่าทุกช่องถูกเช็กแล้ว)
  NewListing _buildListing() {
    final court = selectedCourt!;
    return NewListing(
      sport,
      court.id,
      court.name,
      detailsController.text.trim(),
      _onDate(startTime),
      _onDate(endTime),
      _readPrice(bookedPriceController)!,
      _readPrice(priceController)!,
      proofBytes,
      proofFileName,
      scannedPrice: scannedPrice,
    );
  }

  Future<void> _submit() async {
    final listing = _buildListing();

    try {
      await controller.createListing(listing);
    } catch (error) {
      // พิมพ์สาเหตุจริงไว้ดูใน Debug Console (เช่น ฐานข้อมูลยังไม่มีคอลัมน์ใหม่)
      debugPrint('createListing error: $error');
      if (!mounted) return;
      _showMessage('ลงประกาศไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;

    // แทนที่หน้านี้ด้วยหน้าสำเร็จ กดกลับแล้วจะไปหน้าหลักเลย
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SellSuccessPage(listing: listing),
      ),
    );
  }

  // ---------- หน้าจอ ----------

  @override
  Widget build(BuildContext context) {
    // ปุ่ม ✕ มุมบน = ออกจากฟอร์ม, ปุ่ม "ย้อนกลับ" ด้านล่าง = ถอยทีละขั้น
    // ปุ่ม back ของเครื่อง: ขั้น 2–3 ถอยทีละขั้น, ขั้น 1 ทำแบบเดียวกับปุ่ม ✕
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || isSaving) return;
        if (step > 0) {
          _back();
        } else {
          _confirmExit();
        }
      },
      child: Scaffold(
        backgroundColor: kPageColor,
        appBar: AppBar(
          backgroundColor: kPageColor,
          surfaceTintColor: kPageColor,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'ยกเลิกการลงประกาศ',
            onPressed: isSaving ? null : _confirmExit,
          ),
          title: const Text(
            'ลงประกาศขาย',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(65.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
                  child: StepIndicator(
                    currentStep: step,
                    totalSteps: _totalSteps,
                  ),
                ),
                const Divider(height: 1.0, color: kDividerColor),
              ],
            ),
          ),
        ),
        body: switch (step) {
          0 => _buildStepOne(),
          1 => _buildStepTwo(),
          _ => _buildStepThree(),
        },
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ปุ่มติดอยู่ด้านล่างเสมอ เปลี่ยนตามขั้น
  Widget _buildBottomBar() {
    Widget buttons;
    if (step == 0) {
      buttons = SellerButton(label: 'ถัดไป', onPressed: _next);
    } else {
      final bool isLastStep = step == _totalSteps - 1;
      buttons = Row(
        children: [
          Expanded(
            flex: 2,
            child: SellerButton(
              label: isLastStep ? 'แก้ไข' : 'ย้อนกลับ',
              outlined: true,
              onPressed: isSaving ? null : _back,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 3,
            child: SellerButton(
              label: isLastStep ? 'ลงประกาศ' : 'ถัดไป',
              isLoading: isSaving,
              onPressed: isLastStep ? _submit : _next,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kDividerColor)),
      ),
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16.0), child: buttons),
      ),
    );
  }

  // ขั้นที่ 1: กีฬา สนาม คอร์ท วันที่ เวลา
  Widget _buildStepOne() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
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
        // ผู้ขายรู้ชื่อสนามที่จองไว้อยู่แล้ว พิมพ์ค้นหาอย่างเดียว ไม่ต้องมีแผนที่
        _buildVenueField(),
        if (_venueHint() != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 4.0),
            child: Text(
              _venueHint()!,
              style: const TextStyle(fontSize: 12.0, color: kWarningTextColor),
            ),
          ),
        _buildLabel('รายละเอียด'),
        TextField(
          controller: detailsController,
          minLines: 3,
          maxLines: 5,
          maxLength: 200,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 16.0),
          decoration: _inputDecoration(
            hint: 'เช่น คอร์ท 3, พื้นฮาร์ดคอร์ท, กลางแจ้ง',
          ),
        ),
        _buildLabel('วันที่เล่น'),
        _buildPickerBox(
          text: thaiShortDate(date, withYear: true),
          showArrow: true,
          onTap: _pickDate,
        ),
        _buildLabel('ช่วงเวลา'),
        Row(
          children: [
            Expanded(
              child: _buildPickerBox(
                text: _timeText(startTime),
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
        const SizedBox(height: 12.0),
      ],
    );
  }

  // ช่องพิมพ์ชื่อสนาม พิมพ์แล้วขึ้นรายชื่อสนามที่ตรงให้เลือก
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

    return RawAutocomplete<Court>(
      textEditingController: venueController,
      focusNode: venueFocus,
      displayStringForOption: (Court court) => court.name,
      optionsBuilder: (TextEditingValue value) {
        // ช่องว่าง = แสดงทุกสนาม, พิมพ์แล้ว = กรองทั้งชื่อไทยและอังกฤษ
        return courts.where((court) => court.matches(value.text));
      },
      onSelected: _selectCourt,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          decoration: _inputDecoration(
            hint: 'พิมพ์ชื่อสนาม',
            prefixIcon: const Icon(Icons.search),
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
                constraints: const BoxConstraints(maxHeight: 240.0),
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

  // ขั้นที่ 2: หลักฐานการจอง (แนบก่อน ระบบอ่านราคาให้) + ราคา
  Widget _buildStepTwo() {
    final priceError = _priceError();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      children: [
        _buildLabel('หลักฐานการจอง'),
        _buildProofBox(),
        Row(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  _buildLabel('ราคาที่จองมา'),
                  _buildPriceField(bookedPriceController, readOnly: true),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  _buildLabel('ราคาขาย'),
                  _buildPriceField(
                    priceController,
                    hasError: priceError != null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Text(
          priceError ??
              'ราคาที่จองมาอ่านจากหลักฐานอัตโนมัติ '
                  'ราคาขายต้องไม่เกินราคานี้',
          style: TextStyle(
            fontSize: 13.0,
            color: priceError != null
                ? Theme.of(context).colorScheme.error
                : kHintColor,
          ),
        ),
      ],
    );
  }

  // readOnly = ช่องราคาที่จองมา: ระบบกรอกจากหลักฐาน ผู้ขายแก้เองไม่ได้
  Widget _buildPriceField(
    TextEditingController controller, {
    bool hasError = false,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      decoration: _inputDecoration(
        hint: readOnly ? '–' : '0',
        prefixText: '฿ ',
        hasError: hasError,
        fillColor: readOnly ? kNeutralSoftColor : Colors.white,
      ),
      // พิมพ์แล้ววาดใหม่ ข้อความเตือนราคาจะได้อัปเดตทันที
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  // ข้อความสถานะใต้ชื่อไฟล์หลักฐาน
  String _proofStatusText() {
    if (proofBytes == null) return 'ภาพหน้าจอยืนยันการจองที่เห็นยอดชำระ';
    if (isScanning) return 'กำลังตรวจหลักฐาน…';
    if (scanFailed) return 'อ่านราคาไม่ได้ แตะเพื่อแนบรูปใหม่';
    return 'แนบแล้ว';
  }

  Color _proofStatusColor() {
    if (proofBytes == null || isScanning) return kHintColor;
    if (scanFailed) return Theme.of(context).colorScheme.error;
    return kSuccessColor;
  }

  // กล่องแนบรูปหลักฐาน: ยังไม่แนบ = ปุ่มเลือกรูป, แนบแล้ว = รูปย่อ + สถานะการตรวจ + เปลี่ยน
  Widget _buildProofBox() {
    final bytes = proofBytes;

    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: isScanning ? null : _pickProof,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: SizedBox(
                width: 56.0,
                height: 56.0,
                child: bytes == null
                    ? Container(
                        color: kNeutralSoftColor,
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: kSubtextColor,
                        ),
                      )
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    bytes == null ? 'แนบรูปหลักฐานการจอง' : proofFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _proofStatusText(),
                    style: TextStyle(
                      fontSize: 13.0,
                      color: _proofStatusColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            if (isScanning)
              const SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
            else
              Text(
                bytes == null ? 'เลือกรูป' : 'เปลี่ยน',
                style: const TextStyle(
                  color: kSubtextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ขั้นที่ 3: ตัวอย่างประกาศที่ผู้ซื้อจะเห็น
  Widget _buildStepThree() {
    final listing = _buildListing();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: _boxDecoration(),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: kSellerSoftColor,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        sportLabel(listing.sport),
                        style: const TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: kSellerTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      listing.courtName,
                      style: const TextStyle(
                        fontSize: 17.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      listing.details,
                      style: const TextStyle(color: kSubtextColor, height: 1.4),
                    ),
                    const Divider(height: 28.0, color: kDividerColor),
                    Row(
                      children: [
                        const Text(
                          'วันเวลา',
                          style: TextStyle(color: kHintColor),
                        ),
                        const Spacer(),
                        Text(
                          listing.scheduleText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 28.0, color: kDividerColor),
                    Row(
                      children: [
                        const Text(
                          'ราคาขาย',
                          style: TextStyle(color: kHintColor),
                        ),
                        const Spacer(),
                        Text(
                          '฿${listing.price}',
                          style: const TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    // ยอดสุทธิที่ผู้ขายจะได้รับเมื่อขายได้ (หักค่าธรรมเนียมแพลตฟอร์ม)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: kSellerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'คุณจะได้รับ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: .end,
                            children: [
                              Text(
                                '฿${sellerPayoutOf(listing.price)}',
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'หลังหักค่าธรรมเนียม ฿$kPlatformFee',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: kSubtextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: kMutedColor,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const Text(
                'หลังกดลงประกาศ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text(
                '• ประกาศจะถูกลบอัตโนมัติเมื่อถึงเวลาเล่น ${listing.expireText}',
                style: const TextStyle(color: kSubtextColor, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- ส่วนที่ใช้ซ้ำ ----------

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

  // หน้าตาช่องกรอกให้เหมือนกล่องอื่นในหน้า (ขอบดำ มุมมน) กดแล้วขอบเป็นสีส้ม
  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
    bool hasError = false,
    Color fillColor = Colors.white,
  }) {
    final Color borderColor = hasError
        ? Theme.of(context).colorScheme.error
        : kBorderColor;

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: kHintColor,
        fontWeight: FontWeight.normal,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 18.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(
          color: hasError ? borderColor : kSellerColor,
          width: 2.0,
        ),
      ),
    );
  }

  // กล่องที่กดแล้วเปิดตัวเลือก (วันที่ / เวลา) แบบเดียวกับหน้าตั้งรับ
  // showArrow = true (ช่องวันที่) ข้อความชิดซ้ายและมีลูกศร, ไม่งั้นข้อความอยู่กลาง
  Widget _buildPickerBox({
    required String text,
    required VoidCallback onTap,
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
                textAlign: showArrow ? TextAlign.start : TextAlign.center,
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
