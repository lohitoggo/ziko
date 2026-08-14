class FoodItemModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String category; // Added for dynamic filtering
  final bool isVeg;
  final double price;
  final double discountPrice;
  final int stock;
  final bool isAvailable;
  final double avgRating;
  final int duration; // Service duration in minutes
  final String? imageUrl;
  final List<String> imageUrls; // Support for up to 5 images
  final List<String> availableSlots; // Support for booking slots (optional)

  FoodItemModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.category,
    required this.isVeg,
    required this.price,
    required this.discountPrice,
    required this.stock,
    required this.isAvailable,
    required this.avgRating,
    this.duration = 30, // Default 30 mins
    this.imageUrl,
    this.imageUrls = const [],
    this.availableSlots = const [],
  });

  double get finalPrice => discountPrice > 0 ? discountPrice : price;
  bool get hasDiscount => discountPrice > 0 && discountPrice < price;

  factory FoodItemModel.fromMap(String id, Map<String, dynamic> map) {
    String? image;
    List<String> images = [];
    
    if (map['image_urls'] != null && map['image_urls'] is List) {
      final List list = map['image_urls'] as List;
      for (var img in list) {
        if (img is String && images.length < 5) {
          images.add(img);
        }
      }
      if (images.isNotEmpty) image = images.first;
    }

    final slots = map['available_slots'] != null && map['available_slots'] is List
        ? (map['available_slots'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return FoodItemModel(
      id: id,
      restaurantId: map['business_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      isVeg: map['is_veg'] ?? true,
      price: (map['price'] ?? 0).toDouble(),
      discountPrice: (map['discount_price'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      isAvailable: map['is_available'] ?? true,
      avgRating: (map['avg_rating'] ?? 0).toDouble(),
      duration: map['duration'] ?? 30,
      imageUrl: image,
      imageUrls: images,
      availableSlots: slots,
    );
  }
}