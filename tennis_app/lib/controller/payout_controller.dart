import 'dart:async';

import 'package:tennis_app/models/payout_account_model.dart';
import 'package:tennis_app/services/payout_service.dart';

// ตัวกลางระหว่างหน้าบัญชีรับเงินกับที่เก็บข้อมูล (แบบเดียวกับ RequestController)
// onSync บอกหน้าจอว่ากำลังโหลด/บันทึกอยู่ (true) หรือเสร็จแล้ว (false)
class PayoutController {
  PayoutAccount? account;
  final PayoutService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  PayoutController(this.service);

  Future<PayoutAccount?> fetchMyAccount() async {
    onSyncController.add(true);
    try {
      account = await service.getMyAccount();
    } finally {
      onSyncController.add(false);
    }
    return account;
  }

  Future<void> saveMyAccount(PayoutAccount newAccount) async {
    onSyncController.add(true);
    try {
      await service.saveMyAccount(newAccount);
      account = newAccount;
    } finally {
      onSyncController.add(false);
    }
  }

  void dispose() {
    onSyncController.close();
  }
}
