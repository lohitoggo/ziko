import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final allAreasProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllAreas();
});

final allRestaurantsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllRestaurants();
});

final allRidersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllUsersByRole('rider');
});

final allCustomersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllCustomers();
});

final customerOrderHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, customerUid) {
  return ref.watch(adminRepositoryProvider).watchCustomerOrderHistory(customerUid);
});

final allOrdersAdminProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllOrders();
});

final dashboardCountsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(adminRepositoryProvider).getCounts();
});

final dashboardStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).watchDetailedStats();
});

final systemSettingsProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(adminRepositoryProvider).watchSystemSettings();
});
