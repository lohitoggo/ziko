import 'package:supabase_flutter/supabase_flutter.dart';
import 'food_item_model.dart';

class WishlistRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<FoodItemModel>> watchWishlist(String userId) {
    return _supabase
        .from('wishlist')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((data) async {
          if (data.isEmpty) return [];
          final itemIds = data.map((e) => e['item_id']).toList();
          
          final itemsResponse = await _supabase
              .from('items')
              .select()
              .filter('id', 'in', itemIds);
          
          return (itemsResponse as List)
              .map((d) => FoodItemModel.fromMap(d['id'], d))
              .toList();
        });
  }

  Future<void> toggleWishlist(String userId, String itemId) async {
    final existing = await _supabase
        .from('wishlist')
        .select()
        .eq('user_id', userId)
        .eq('item_id', itemId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('item_id', itemId);
    } else {
      await _supabase.from('wishlist').insert({
        'user_id': userId,
        'item_id': itemId,
      });
    }
  }

  Future<bool> isInWishlist(String userId, String itemId) async {
    final response = await _supabase
        .from('wishlist')
        .select()
        .eq('user_id', userId)
        .eq('item_id', itemId)
        .maybeSingle();
    return response != null;
  }
}
