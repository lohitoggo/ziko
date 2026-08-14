import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/address_repository.dart';
import '../data/address_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';

final addressRepositoryProvider = Provider((ref) => AddressRepository());

final userAddressesProvider = StreamProvider<List<AddressModel>>((ref) {
  final uid = ref.watch(supabaseUserProvider.select((u) => u?.id));
  if (uid == null) return Stream.value([]);
  
  return ref.watch(addressRepositoryProvider)
      .watchUserAddresses(uid)
      .handleError((e) {
        print('SUPABASE ADDRESS ERROR: $e');
        return <AddressModel>[];
      });
});

final defaultAddressProvider = Provider<AddressModel?>((ref) {
  final addresses = ref.watch(userAddressesProvider).value ?? [];
  if (addresses.isEmpty) return null;
  return addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
});
