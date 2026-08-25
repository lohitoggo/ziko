
class ReviewModel {
  final String id;
  final String itemId;
  final String userId;
  final String? orderId;
  final String userName;
  final String? profileImageUrl;
  final double rating;
  final String comment;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.itemId,
    required this.userId,
    this.orderId,
    required this.userName,
    this.profileImageUrl,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) {
    final profile = map['profiles'];
    
    return ReviewModel(
      id: id,
      itemId: map['item_id'] ?? '',
      userId: map['customer_id'] ?? '',
      orderId: map['order_id'],
      userName: profile != null ? (profile['name'] ?? 'Customer') : (map['user_name'] ?? 'User'),
      profileImageUrl: profile != null ? profile['profile_image_url'] : null,
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      timestamp: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'customer_id': userId,
      'order_id': orderId,
      // Note: We don't send 'user_name' if the column doesn't exist in the table.
      // If it does exist, you can uncomment the line below.
      // 'user_name': userName, 
      'rating': rating.toInt(), // Ensuring it's an integer for the database
      'comment': comment,
    };
  }
}
