import 'package:supabase_flutter/supabase_flutter.dart';
import 'address_model.dart';

class AddressRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<AddressModel>> watchUserAddresses(String userId) {
    return _supabase
        .from('user_addresses')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .map((data) => data.map((d) => AddressModel.fromMap(d)).toList());
  }

  Future<void> saveAddress(AddressModel address) async {
    // If setting as default, unset others first
    if (address.isDefault) {
      try {
        await _supabase
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', address.userId);
      } catch (e) {
        // Ignore if no addresses exist
      }
    }

    final data = {
      'user_id': address.userId,
      'house_number': address.houseNumber,
      'village': address.village,
      'landmark': address.landmark,
      'pin_code': address.pinCode,
      'area_id': address.areaId,
      'latitude': address.latitude,
      'longitude': address.longitude,
      'is_default': address.isDefault,
    };

    if (address.id.isEmpty) {
      await _supabase.from('user_addresses').insert(data);
    } else {
      await _supabase.from('user_addresses').update(data).eq('id', address.id);
    }
  }

  Future<void> deleteAddress(String id) async {
    await _supabase.from('user_addresses').delete().eq('id', id);
  }

  Future<void> setDefault(String userId, String addressId) async {
    await _supabase
        .from('user_addresses')
        .update({'is_default': false})
        .eq('user_id', userId);
        
    await _supabase
        .from('user_addresses')
        .update({'is_default': true})
        .eq('id', addressId);
  }
}
