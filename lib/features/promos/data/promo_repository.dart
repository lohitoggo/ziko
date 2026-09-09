import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'promo_model.dart';

class PromoRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<PromoCode>> watchAllPromoCodes() {
    return _supabase
        .from('promo_codes')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((e) => PromoCode.fromMap(e)).toList())
        .handleError((error) {
          debugPrint('Error watching promo codes: $error');
        });
  }

  Future<void> createPromoCode(PromoCode promo) async {
    await _supabase.from('promo_codes').insert(promo.toMap());
  }

  Future<void> togglePromoStatus(String id, bool isActive) async {
    await _supabase.from('promo_codes').update({'is_active': isActive}).eq('id', id);
  }

  Future<void> deletePromoCode(String id) async {
    await _supabase.from('promo_codes').delete().eq('id', id);
  }
}
