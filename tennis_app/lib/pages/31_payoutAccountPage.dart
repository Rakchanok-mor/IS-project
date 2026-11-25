import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tennis_app/components/app_colors.dart';
import 'package:tennis_app/components/seller_button.dart';
import 'package:tennis_app/controller/payout_controller.dart';
import 'package:tennis_app/models/payout_account_model.dart';
import 'package:tennis_app/services/payout_service.dart';

// หน้าบัญชีรับเงินของผู้ขาย: แอดมินใช้โอนเงินให้หลังผู้ซื้อยืนยันว่าได้เล่นแล้ว
// เข้าได้จากแท็บบัญชี
class PayoutAccountPage extends StatefulWidget {
  const PayoutAccountPage({super.key});

  @override
  State<PayoutAccountPage> createState() => _PayoutAccountPageState();
}

class _PayoutAccountPageState extends State<PayoutAccountPage> {
  PayoutController controller = PayoutController(PayoutSupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  TextEditingController numberController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  bool isLoading = false;
  String bankName = kBanks.first;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoading = syncState;
      });
    });
    _load();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    numberController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // เคยกรอกแล้ว = เติมค่าเดิมให้แก้ไข
  Future<void> _load() async {
    PayoutAccount? account;
    try {
      account = await controller.fetchMyAccount();
    } catch (error) {
      if (!mounted) return;
      _showMessage('โหลดไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted || account == null) return;
    setState(() {
      if (kBanks.contains(account!.bankName)) {
        bankName = account.bankName;
      }
      numberController.text = account.accountNumber;
      nameController.text = account.accountName;
    });
  }

  Future<void> _save() async {
    final number = numberController.text.trim();
    final name = nameController.text.trim();
    if (number.length < 10) {
      _showMessage('กรุณากรอกเลขบัญชี / เบอร์พร้อมเพย์ให้ครบ');
      return;
    }
    if (name.isEmpty) {
      _showMessage('กรุณากรอกชื่อบัญชี');
      return;
    }

    try {
      await controller.saveMyAccount(PayoutAccount(bankName, number, name));
    } catch (error) {
      if (!mounted) return;
      _showMessage('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
      return;
    }
    if (!mounted) return;
    _showMessage('บันทึกบัญชีรับเงินแล้ว');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageColor,
      appBar: AppBar(
        backgroundColor: kPageColor,
        surfaceTintColor: kPageColor,
        title: const Text(
          'บัญชีรับเงิน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: kDividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(10.0),
        children: [
          const SizedBox(height: 24.0),
          _buildLabel('ธนาคาร'),
          DropdownButtonFormField<String>(
            initialValue: bankName,
            items: kBanks.map((bank) {
              return DropdownMenuItem(value: bank, child: Text(bank));
            }).toList(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                bankName = value;
              });
            },
            decoration: _inputDecoration(hint: ''),
          ),
          const SizedBox(height: 16.0),
          _buildLabel('เลขบัญชี / เบอร์พร้อมเพย์'),
          TextField(
            controller: numberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 15,
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            decoration: _inputDecoration(hint: 'เช่น 0123456789'),
          ),
          const SizedBox(height: 8.0),
          _buildLabel('ชื่อบัญชี'),
          TextField(
            controller: nameController,
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            decoration: _inputDecoration(hint: 'ชื่อ-นามสกุล ตามสมุดบัญชี'),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDividerColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SellerButton(
              label: 'บันทึก',
              isLoading: isLoading,
              onPressed: _save,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: kHintColor,
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 18.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: kBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: kBorderColor, width: 2.0),
      ),
    );
  }
}
