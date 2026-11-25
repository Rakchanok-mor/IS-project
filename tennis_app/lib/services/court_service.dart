import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennis_app/models/court_model.dart';

// สัญญาว่าที่เก็บข้อมูลสนามต้องทำอะไรได้บ้าง
abstract class CourtService {
  // สนามที่มีกีฬานี้ เรียงตามชื่อ
  Future<List<Court>> getCourts(String sport);
}

// ดึงจากตาราง courts ใน Supabase
class CourtSupabaseService implements CourtService {
  @override
  Future<List<Court>> getCourts(String sport) async {
    final data = await Supabase.instance.client
        .from('courts')
        .select()
        .contains('sports', [sport])
        .order('name');

    AllCourts all = AllCourts.fromJson(data);
    return all.courts;
  }
}
