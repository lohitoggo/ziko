import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/grocery_repository.dart';
import '../data/services/open_food_facts_service.dart';
import '../data/models/category_model.dart';
import '../data/models/product_model.dart';
import '../data/models/inventory_model.dart';
import '../../auth/providers/user_provider.dart';

final groceryRepositoryProvider = Provider<GroceryRepository>((ref) {
  return GroceryRepository();
});

final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>((ref) {
  return OpenFoodFactsService();
});

final groceryCategoriesProvider = FutureProvider<List<GroceryCategory>>((ref) {
  return ref.watch(groceryRepositoryProvider).getCategories();
});

// Provider for products by category (Supports pagination)
final productsByCategoryProvider = FutureProvider.family<List<GroceryProduct>, String>((ref, categoryId) {
  return ref.watch(groceryRepositoryProvider).getProductsByCategory(categoryId);
});

final grocerySearchQueryProvider = StateProvider<String>((ref) => '');

final allProductsProvider = FutureProvider<List<GroceryProduct>>((ref) {
  final query = ref.watch(grocerySearchQueryProvider);
  final areaId = ref.watch(currentUserProvider.select((u) => u.value?.areaId));
  
  return ref.watch(groceryRepositoryProvider).getAllProducts(
    query: query, 
    areaId: areaId
  );
});

// Provides FULL list of master products with shop-specific inventory data joined
final shopFullInventoryProvider = FutureProvider.family<List<GroceryProduct>, String>((ref, shopId) {
  return ref.watch(groceryRepositoryProvider).getFullInventoryForShop(shopId);
});

final shopInventoryProvider = StreamProvider.family<List<GroceryInventory>, String>((ref, shopId) {
  return ref.watch(groceryRepositoryProvider).watchShopInventory(shopId);
});
