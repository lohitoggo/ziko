import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'payout_model.dart';

class PayoutRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<BankDetails?> getBankDetails(String userId) async {
    try {
      final res = await _supabase.from('bank_details').select().eq('user_id', userId).maybeSingle();
      if (res == null) return null;
      return BankDetails.fromMap(res);
    } catch (e) {
      debugPrint('Error getting bank details: $e');
      return null;
    }
  }

  Future<void> saveBankDetails(BankDetails details) async {
    await _supabase.from('bank_details').upsert(details.toMap());
  }

  Future<void> createPayoutRequest({
    required String userId,
    required String userName,
    required String userPhone,
    required String userType,
    required double amount,
    required BankDetails bankDetails,
  }) async {
    await _supabase.from('payout_requests').insert({
      'user_id': userId,
      'user_name': userName,
      'user_phone': userPhone,
      'user_type': userType,
      'amount': amount,
      'status': 'pending',
      'bank_details': bankDetails.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<PayoutRequest>> watchUserPayoutRequests(String userId) {
    return _supabase
        .from('payout_requests')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => PayoutRequest.fromMap(e)).toList());
  }

  Stream<List<PayoutRequest>> watchAllPayoutRequests() {
    return _supabase
        .from('payout_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => PayoutRequest.fromMap(e)).toList());
  }

  Future<void> updatePayoutStatus(String requestId, String status) async {
    await _supabase.from('payout_requests').update({'status': status}).eq('id', requestId);
  }
}
