import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_model.dart';

class UserRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AppUser?> getUser(String uid) async {
    final response = await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
    if (response == null) return null;
    return AppUser.fromMap({...response, 'uid': response['id']});
  }

  /// CRITICAL FIX: Use upsert to ensure profile exists
  Future<void> updateRole(String uid, String role) async {
    await _supabase.from('profiles').upsert({
      'id': uid,
      'role': role,
    });
  }

  /// CRITICAL FIX: Use upsert for comprehensive profile details
  Future<void> updateProfileDetails(String uid, {
    required String name,
    required String phone,
    String? email,
    String? secondaryPhone,
    String? address,
    String? pinCode,
  }) async {
    await _supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'secondary_phone': secondaryPhone,
      'address': address,
      'pin_code': pinCode,
    });
  }

  Future<void> updateArea(String uid, String areaId) async {
    await _supabase.from('profiles').upsert({
      'id': uid,
      'area_id': areaId,
    });
  }

  Future<void> updateName(String uid, String name) async {
    await _supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
    });
  }

  Stream<AppUser?> watchUser(String uid) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((data) {
          if (data.isEmpty) return null;
          final profile = data.first;
          return AppUser.fromMap({...profile, 'uid': profile['id']});
        })
        .handleError((error) {
          print('Realtime error in watchUser: $error');
        });
  }
}
