import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewModel {
  final String id;
  final String itemId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) {
    return ReviewModel(
      id: id,
      itemId: map['item_id'] ?? '',
      userId: map['customer_id'] ?? '',
      userName: map['user_name'] ?? 'User', // Should ideally join with profiles
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      timestamp: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'customer_id': userId,
      'user_name': userName,
      'rating': rating,
      'comment': comment,
    };
  }
}
