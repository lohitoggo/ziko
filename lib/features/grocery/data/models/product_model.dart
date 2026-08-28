import '../../../customer/data/food_item_model.dart';

class GroceryProduct {
  final String id;
  final String? categoryId;
  final String name;
  final String slug;
  final String? brand;
  final String? barcode;
  final String? quantityValue;
  final String? unit;
  final double mrp;
  final double defaultSellingPrice;
  final String? imageUrl;
  final String? description;
  final String source;
  final String? sourceProductId;
  final bool isActive;

  // New fields for Shop-specific data (Loaded via Join)
  final double? shopPrice;
  final int? shopStock;
  final String? shopId;

  GroceryProduct({
    required this.id,
    this.categoryId,
    required this.name,
    required this.slug,
    this.brand,
    this.barcode,
    this.quantityValue,
    this.unit,
    this.mrp = 0.0,
    this.defaultSellingPrice = 0.0,
    this.imageUrl,
    this.description,
    this.source = 'manual',
    this.sourceProductId,
    this.isActive = true,
    this.shopPrice,
    this.shopStock,
    this.shopId,
  });

  factory GroceryProduct.fromMap(Map<String, dynamic> map) {
    // Check if inventory data is joined
    final inventory = map['grocery_inventory'] is List && (map['grocery_inventory'] as List).isNotEmpty
        ? (map['grocery_inventory'] as List).first
        : (map['grocery_inventory'] is Map ? map['grocery_inventory'] : null);

    return GroceryProduct(
      id: map['id'],
      categoryId: map['category_id'],
      name: map['name'] ?? '',
      slug: map['slug'] ?? '',
      brand: map['brand'],
      barcode: map['barcode'],
      quantityValue: map['quantity_value'],
      unit: map['unit'],
      mrp: (map['mrp'] ?? 0.0).toDouble(),
      defaultSellingPrice: (map['default_selling_price'] ?? 0.0).toDouble(),
      imageUrl: map['image_url'],
      description: map['description'],
      source: map['source'] ?? 'manual',
      sourceProductId: map['source_product_id'],
      isActive: map['is_active'] ?? true,
      shopPrice: inventory != null ? (inventory['price'] ?? 0.0).toDouble() : null,
      shopStock: inventory != null ? (inventory['stock_quantity'] ?? 0) : null,
      shopId: inventory != null ? inventory['business_id'] : null,
    );
  }

  /// Converts a Grocery product to a FoodItemModel for Cart Compatibility
  FoodItemModel toFoodItem() {
    return FoodItemModel(
      id: id,
      restaurantId: shopId ?? 'global_grocery',
      name: name,
      description: brand ?? description ?? '',
      category: 'Grocery',
      isVeg: true,
      price: mrp,
      discountPrice: shopPrice ?? defaultSellingPrice,
      stock: shopStock ?? 0,
      isAvailable: (shopStock ?? 0) > 0,
      avgRating: 5.0,
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'brand': brand,
      'barcode': barcode,
      'quantity_value': quantityValue,
      'unit': unit,
      'mrp': mrp,
      'default_selling_price': defaultSellingPrice,
      'image_url': imageUrl,
      'description': description,
      'source': source,
      'source_product_id': sourceProductId,
      'is_active': isActive,
    };
  }
}
