import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'food_item_model.dart';

class FoodItemRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<FoodItemModel>> watchFoodItems(String businessId) {
    return _supabase
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .map<List<FoodItemModel>>((data) => data.map((d) => FoodItemModel.fromMap(d['id'], d)).toList())
        .handleError((e) => debugPrint('REALTIME ERROR (Food Items): $e'));
  }

  Stream<List<FoodItemModel>> watchItemsByRestaurant(String businessId) {
    return watchFoodItems(businessId);
  }
}
