class GroceryCategory {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  GroceryCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory GroceryCategory.fromMap(Map<String, dynamic> map) {
    return GroceryCategory(
      id: map['id'],
      name: map['name'] ?? '',
      slug: map['slug'] ?? '',
      imageUrl: map['image_url'],
      sortOrder: map['sort_order'] ?? 0,
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}
