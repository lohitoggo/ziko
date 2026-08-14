import 'package:supabase_flutter/supabase_flutter.dart';
import 'food_item_model.dart';

class FoodItemRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<FoodItemModel>> watchFoodItems(String businessId) {
    return _supabase
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .map((data) => data.map((d) => FoodItemModel.fromMap(d['id'], d)).toList());
  }

  Stream<List<FoodItemModel>> watchItemsByRestaurant(String businessId) {
    return watchFoodItems(businessId);
  }
}
