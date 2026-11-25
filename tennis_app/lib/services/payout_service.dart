import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/payout_account_model.dart';

// สัญญาว่าที่เก็บบัญชีรับเงินของผู้ขายต้องทำอะไรได้บ้าง
abstract class PayoutService {
  // บัญชีของเราเอง ยังไม่เคยกรอก = null
  Future<PayoutAccount?> getMyAccount();

  // บันทึก (ครั้งแรก = เพิ่ม, ครั้งต่อไป = แก้ทับ)
  Future<void> saveMyAccount(PayoutAccount account);
}

// เก็บในตาราง payout_accounts ใน Supabase (1 คน 1 บัญชี)
class PayoutSupabaseService implements PayoutService {
  @override
  Future<PayoutAccount?> getMyAccount() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await client
        .from('payout_accounts')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return PayoutAccount.fromJson(data);
  }

  @override
  Future<void> saveMyAccount(PayoutAccount account) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('ยังไม่ได้ล็อกอิน');
    }

    final data = account.toJson();
    data['user_id'] = userId;
    await client.from('payout_accounts').upsert(data);
  }
}
