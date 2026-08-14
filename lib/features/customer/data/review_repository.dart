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
        .map((data) => data.map((d) => ReviewModel.fromMap(d['id'], d)).toList());
  }

  Future<void> addReview(ReviewModel review) async {
    await _supabase.from('item_reviews').insert(review.toMap());
  }
}
