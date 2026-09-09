import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/payout_repository.dart';
import '../data/payout_model.dart';

final payoutRepositoryProvider = Provider<PayoutRepository>((ref) {
  return PayoutRepository();
});

final userBankDetailsProvider = FutureProvider.family<BankDetails?, String>((ref, userId) {
  return ref.watch(payoutRepositoryProvider).getBankDetails(userId);
});

final userPayoutRequestsProvider = StreamProvider.family<List<PayoutRequest>, String>((ref, userId) {
  return ref.watch(payoutRepositoryProvider).watchUserPayoutRequests(userId);
});

final allPayoutRequestsProvider = StreamProvider<List<PayoutRequest>>((ref) {
  return ref.watch(payoutRepositoryProvider).watchAllPayoutRequests();
});
