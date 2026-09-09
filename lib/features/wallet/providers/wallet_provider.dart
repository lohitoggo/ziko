import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wallet_repository.dart';
import '../data/wallet_model.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

final userWalletBalanceProvider = StreamProvider.family<double, String>((ref, userId) {
  return ref.watch(walletRepositoryProvider).watchWalletBalance(userId);
});

final userWalletTransactionsProvider = StreamProvider.family<List<WalletTransaction>, String>((ref, userId) {
  return ref.watch(walletRepositoryProvider).watchWalletTransactions(userId);
});
