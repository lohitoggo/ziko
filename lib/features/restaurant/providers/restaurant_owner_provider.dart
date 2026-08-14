import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/restaurant_owner_repository.dart';
import '../../auth/providers/supabase_auth_provider.dart';

final restaurantOwnerRepositoryProvider =
Provider<RestaurantOwnerRepository>((ref) {
  return RestaurantOwnerRepository();
});

final myRestaurantProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(supabaseUserProvider);
  if (user == null) return Stream.value(null);
  return ref
      .watch(restaurantOwnerRepositoryProvider)
      .watchMyBusiness(user.id);
});

final myItemsProvider =
StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, restaurantId) {
      return ref
          .watch(restaurantOwnerRepositoryProvider)
          .watchMyItems(restaurantId);
    });

final myOrdersProvider =
StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, restaurantId) {
      return ref
          .watch(restaurantOwnerRepositoryProvider)
          .watchMyOrders(restaurantId);
    });