import 'dart:async';

import 'package:tennis_app/models/gateway_charge_model.dart';
import 'package:tennis_app/services/mock_bank_service.dart';

// ตัวกลางระหว่างหน้าแอปธนาคารจำลองกับ service (แบบเดียวกับ PostController)
class MockBankController {
  GatewayCharge? charge;
  final MockBankService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  MockBankController(this.service);

  Future<GatewayCharge> scanQr(String qrData) async {
    onSyncController.add(true);
    try {
      charge = await service.scanQr(qrData);
    } finally {
      onSyncController.add(false);
    }
    return charge!;
  }

  Future<GatewayCharge> pay(GatewayCharge current) async {
    onSyncController.add(true);
    try {
      charge = await service.pay(current);
    } finally {
      onSyncController.add(false);
    }
    return charge!;
  }

  void dispose() {
    onSyncController.close();
  }
}
