import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wishlist_repository.dart';
import '../data/food_item_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';

final wishlistRepositoryProvider = Provider((ref) => WishlistRepository());

final wishlistProvider = StreamProvider<List<FoodItemModel>>((ref) {
  final user = ref.watch(supabaseUserProvider);
  if (user == null) return Stream.value([]);
  
  return ref.watch(wishlistRepositoryProvider)
      .watchWishlist(user.id)
      .handleError((e) {
        print('SUPABASE WISHLIST ERROR: $e');
        return <FoodItemModel>[];
      });
});

final isInWishlistProvider = FutureProvider.family<bool, String>((ref, itemId) async {
  // Use select to only watch id to avoid irrelevant rebuilds
  final uid = ref.watch(supabaseUserProvider.select((u) => u?.id));
  if (uid == null) return false;
  return ref.read(wishlistRepositoryProvider).isInWishlist(uid, itemId);
});
