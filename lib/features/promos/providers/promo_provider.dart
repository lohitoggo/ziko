import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/promo_repository.dart';
import '../data/promo_model.dart';

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  return PromoRepository();
});

final allPromoCodesProvider = StreamProvider<List<PromoCode>>((ref) {
  return ref.watch(promoRepositoryProvider).watchAllPromoCodes();
});

final activePromoCodesProvider = StreamProvider<List<PromoCode>>((ref) {
  final now = DateTime.now();
  return ref.watch(promoRepositoryProvider).watchAllPromoCodes().map((list) {
    return list.where((p) => p.isActive && (p.expiryDate == null || p.expiryDate!.isAfter(now))).toList();
  });
});
