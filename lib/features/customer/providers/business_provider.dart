import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/business_repository.dart';
import '../data/business_model.dart';
import '../data/review_repository.dart';
import '../data/review_model.dart';
import '../data/food_item_model.dart';
import '../../auth/providers/user_provider.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

final itemReviewsProvider = StreamProvider.family<List<ReviewModel>, String>((ref, itemId) {
  return ref.watch(reviewRepositoryProvider).watchItemReviews(itemId);
});

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository();
});

final recommendedItemsProvider = StreamProvider<List<FoodItemModel>>((ref) {
  return ref.watch(businessRepositoryProvider).watchRecommendedItems();
});

final selectedCategoryProvider = StateProvider<String>((ref) => 'all');

final searchQueryProvider = StateProvider<String>((ref) => '');

final businessesByAreaProvider = StreamProvider<List<BusinessModel>>((ref) {
  // CRITICAL FIX: Only watch the areaId to avoid rebuild loops when user profile syncs other data
  final areaId = ref.watch(currentUserProvider.select((u) => u.value?.areaId));
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  if (areaId == null) {
    print('DEBUG: No areaId found for current user. Waiting...');
    return Stream.value([]);
  }
  
  print('DEBUG: Refreshing Businesses for Area: $areaId, Category: $category');

  final stream = ref
      .watch(businessRepositoryProvider)
      .watchBusinessesByArea(areaId, category: category);
      
  if (query.isEmpty) return stream;
  
  return stream.map((list) => list
      .where((b) => b.name.toLowerCase().contains(query) || 
                    b.description.toLowerCase().contains(query))
      .toList());
});

final businessProvider = StreamProvider.family<BusinessModel?, String>((ref, businessId) {
  return ref.watch(businessRepositoryProvider).watchBusiness(businessId);
});
