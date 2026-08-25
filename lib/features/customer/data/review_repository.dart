import 'package:supabase_flutter/supabase_flutter.dart';
import 'review_model.dart';

class ReviewRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<ReviewModel>> watchItemReviews(String itemId) {
    return _supabase
        .from('item_reviews')
        .stream(primaryKey: ['id'])
        .eq('item_id', itemId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          // Since .stream doesn't support joins directly in the same way .select does,
          // we fetch the profile data separately for these reviews
          final List<ReviewModel> reviews = [];
          for (var d in data) {
            final id = d['id'];
            final customerId = d['customer_id'];
            
            // Fetch profile
            final profileResponse = await _supabase
                .from('profiles')
                .select('name, profile_image_url')
                .eq('id', customerId)
                .maybeSingle();
            
            reviews.add(ReviewModel.fromMap(id, {
              ...d,
              'profiles': profileResponse,
            }));
          }
          return reviews;
        });
  }

  Future<void> addReview(ReviewModel review) async {
    await _supabase.from('item_reviews').insert(review.toMap());
  }

  Future<bool> hasReviewed(String orderId, String itemId) async {
    final response = await _supabase
        .from('item_reviews')
        .select()
        .eq('order_id', orderId)
        .eq('item_id', itemId)
        .maybeSingle();
    return response != null;
  }
}
