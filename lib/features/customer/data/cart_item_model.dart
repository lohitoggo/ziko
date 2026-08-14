import 'food_item_model.dart';

class CartItem {
  final FoodItemModel food;
  final int quantity;

  CartItem({required this.food, required this.quantity});

  double get subtotal => food.finalPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(food: food, quantity: quantity ?? this.quantity);
  }
}