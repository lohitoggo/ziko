import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'wallet_model.dart';

class WalletRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<double> watchWalletBalance(String userId) {
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          double balance = 0.0;
          for (final row in data) {
            final amt = ((row['amount'] ?? 0) as num).toDouble();
            final type = row['type'] ?? 'credit';
            if (type == 'credit') {
              balance += amt;
            } else if (type == 'debit') {
              balance -= amt;
            }
          }
          return balance < 0 ? 0.0 : balance;
        })
        .handleError((error) {
          debugPrint('Wallet Stream Error: $error');
        });
  }

  Stream<List<WalletTransaction>> watchWalletTransactions(String userId) {
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => WalletTransaction.fromMap(e)).toList());
  }

  Future<void> addCredit({
    required String userId,
    required double amount,
    required String title,
    required String description,
  }) async {
    await _supabase.from('wallet_transactions').insert({
      'user_id': userId,
      'amount': amount,
      'type': 'credit',
      'title': title,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> addDebit({
    required String userId,
    required double amount,
    required String title,
    required String description,
  }) async {
    await _supabase.from('wallet_transactions').insert({
      'user_id': userId,
      'amount': amount,
      'type': 'debit',
      'title': title,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
