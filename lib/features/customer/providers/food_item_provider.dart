import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/food_item_repository.dart';
import '../data/food_item_model.dart';

final foodItemRepositoryProvider = Provider<FoodItemRepository>((ref) {
  return FoodItemRepository();
});

final itemsByBusinessProvider =
StreamProvider.family<List<FoodItemModel>, String>((ref, businessId) {
  return ref
      .watch(foodItemRepositoryProvider)
      .watchItemsByRestaurant(businessId);
});