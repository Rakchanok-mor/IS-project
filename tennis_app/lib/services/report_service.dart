import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/report_model.dart';

// สัญญาว่าที่เก็บข้อมูลต้องส่งออเดอร์อะไรให้รายงานได้บ้าง
// (ดึงมาดิบ ๆ ส่วนการรวมยอดทำใน report_model.dart)
abstract class ReportService {
  // แอดมิน: ออเดอร์ทั้งหมดในระบบ
  Future<List<ReportOrder>> getAllOrders();

  // ผู้ขาย: ออเดอร์ของประกาศที่เราลงขาย
  Future<List<ReportOrder>> getMySellerOrders();
}

// อ่านจากตาราง orders ใน Supabase
// RLS ใน schema.sql กันสิทธิ์ให้แล้ว: แอดมินอ่านได้ทุกออเดอร์,
// ผู้ขายอ่านได้เฉพาะออเดอร์ของประกาศตัวเอง
class ReportSupabaseService implements ReportService {
  @override
  Future<List<ReportOrder>> getAllOrders() async {
    final data = await Supabase.instance.client
        .from('orders')
        .select('amount, status, paid_at');
    AllReportOrders all = AllReportOrders.fromJson(data);
    return all.orders;
  }

  @override
  Future<List<ReportOrder>> getMySellerOrders() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return List.empty();

    // join กับ listings เพื่อกรองเฉพาะประกาศของเรา
    // (ไม่กรอง จะได้ออเดอร์ที่เราเป็นผู้ซื้อปนมาด้วย)
    final data = await client
        .from('orders')
        .select('amount, status, paid_at, listings!inner(seller_id)')
        .eq('listings.seller_id', userId);
    AllReportOrders all = AllReportOrders.fromJson(data);
    return all.orders;
  }
}
