import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/gateway_charge_model.dart';

// แปลง error จากแอปธนาคารจำลองเป็นข้อความภาษาไทย
String mockBankErrorText(Object error) {
  final text = error.toString();
  if (text.contains('invalid_qr') || text.contains('charge_not_found')) {
    return 'อ่าน QR ไม่ได้ หรือไม่พบรายการชำระเงินนี้';
  }
  if (text.contains('charge_already_paid')) {
    return 'รายการนี้ชำระไปแล้ว';
  }
  if (text.contains('charge_expired')) {
    return 'QR หมดเวลาชำระแล้ว';
  }
  return 'ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง';
}

// แอปธนาคารจำลอง: อ่าน QR แล้วจ่ายเงินเข้า Payment Gateway
// (ของจริงคือแอปธนาคารของผู้ซื้อ อยู่นอกแอป Courtswap)
abstract class MockBankService {
  // สแกน QR → ดูรายละเอียดก่อนยืนยันโอน
  Future<GatewayCharge> scanQr(String qrData);

  // ยืนยันโอน → gateway แจ้ง Courtswap เองทาง webhook
  Future<GatewayCharge> pay(GatewayCharge charge);
}

class MockBankSupabaseService implements MockBankService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<GatewayCharge> scanQr(String qrData) async {
    final response = await _client.functions.invoke(
      'mock-gateway/bank/lookup',
      body: {'qr': qrData},
    );
    return _readCharge(response.data);
  }

  @override
  Future<GatewayCharge> pay(GatewayCharge charge) async {
    final response = await _client.functions.invoke(
      'mock-gateway/bank/pay',
      body: {'charge_id': charge.id},
    );
    return _readCharge(response.data);
  }

  GatewayCharge _readCharge(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['charge'] is Map<String, dynamic>) {
      return GatewayCharge.fromJson(data['charge'] as Map<String, dynamic>);
    }
    throw Exception('charge_not_found');
  }
}
