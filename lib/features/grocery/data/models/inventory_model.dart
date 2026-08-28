import 'product_model.dart';

class GroceryInventory {
  final String id;
  final String productId;
  final String businessId;
  final int stockQuantity;
  final double price;
  final bool isAvailable;
  final DateTime updatedAt;
  
  // Optional: Embed product details for easier UI rendering
  final GroceryProduct? product;

  GroceryInventory({
    required this.id,
    required this.productId,
    required this.businessId,
    this.stockQuantity = 0,
    this.price = 0.0,
    this.isAvailable = true,
    required this.updatedAt,
    this.product,
  });

  factory GroceryInventory.fromMap(Map<String, dynamic> map) {
    // Robust Product Extracting (Handles both Object and List returns from Supabase)
    dynamic productData = map['grocery_products'];
    if (productData is List && productData.isNotEmpty) {
      productData = productData.first;
    }

    return GroceryInventory(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      businessId: map['business_id'] ?? '',
      stockQuantity: map['stock_quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      isAvailable: map['is_available'] ?? true,
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      product: productData != null && productData is Map<String, dynamic>
          ? GroceryProduct.fromMap(productData) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'business_id': businessId,
      'stock_quantity': stockQuantity,
      'price': price,
      'is_available': isAvailable,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
