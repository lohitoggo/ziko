import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rider_repository.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/data/user_model.dart';
import '../../customer/data/business_repository.dart';
import '../../customer/data/business_model.dart';

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return RiderRepository();
});

final riderOnlineStatusProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(supabaseUserProvider);
  if (user == null) return Stream.value(false);
  return ref.watch(riderRepositoryProvider).watchOnlineStatus(user.id);
});

final myRiderProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(supabaseUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(riderRepositoryProvider).watchMyRiderProfile(user.id);
});

final specificRiderProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, riderId) {
  return ref.watch(riderRepositoryProvider).watchMyRiderProfile(riderId);
});

final businessRepositoryProvider = Provider((ref) => BusinessRepository());

final availableOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final riderProfileAsync = ref.watch(myRiderProfileProvider);
  return riderProfileAsync.when(
    data: (profile) {
      if (profile == null) return Stream.value([]);
      final List<String> areaIds = List<String>.from(profile['area_ids'] ?? []);
      // Fallback to single area_id if array is missing
      if (areaIds.isEmpty && profile['area_id'] != null) {
        areaIds.add(profile['area_id']);
      }
      return ref.watch(riderRepositoryProvider).watchAvailableOrders(areaIds);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

final businessProvider = StreamProvider.family<BusinessModel?, String>((ref, id) {
  return ref.watch(businessRepositoryProvider).watchBusiness(id);
});

final userDetailsProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

final myDeliveriesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(supabaseUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(riderRepositoryProvider).watchMyDeliveries(user.id);
});

final myCompletedDeliveriesProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(supabaseUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(riderRepositoryProvider).watchMyCompletedDeliveries(user.id);
});
