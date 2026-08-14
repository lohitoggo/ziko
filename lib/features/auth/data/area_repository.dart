import 'package:supabase_flutter/supabase_flutter.dart';
import 'area_model.dart';

class AreaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<AreaModel>> watchActiveAreas() {
    return _supabase
        .from('areas')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((data) => data.map((d) => AreaModel.fromMap(d['id'], d)).toList());
  }
}
