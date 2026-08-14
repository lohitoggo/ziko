import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../data/cart_item_model.dart';
import '../data/food_item_model.dart';

class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier() : super({});

  String? restaurantId;
  String? selectedSlot;
  DateTime selectedDate = DateTime.now();

  void addItem(FoodItemModel food, {VoidCallback? onSalonLimit, bool isSalon = false}) {
    // যদি অন্য রেস্টুরেন্টের আইটেম কার্টে থাকে, প্রথমে কার্ট খালি করে দিন
    if (restaurantId != null && restaurantId != food.restaurantId) {
      clear();
    }
    restaurantId = food.restaurantId;

    final existing = state[food.id];
    
    // RELIABLE CHECK: Use passed flag or category string
    final bool isSalonItem = isSalon || food.category.toLowerCase().contains('salon');

    if (existing != null) {
      // ABSOLUTE BLOCK with Alert Callback
      if (isSalonItem) {
        if (onSalonLimit != null) onSalonLimit();
        return; 
      }
      state = {
        ...state,
        food.id: existing.copyWith(quantity: existing.quantity + 1),
      };
    } else {
      state = {...state, food.id: CartItem(food: food, quantity: 1)};
    }
  }

  void setAppointment(String? slot, DateTime date) {
    selectedSlot = slot;
    selectedDate = date;
    state = {...state}; // Trigger rebuild
  }

  void removeItem(String foodId) {
    final existing = state[foodId];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      final newState = {...state};
      newState.remove(foodId);
      state = newState;
      if (state.isEmpty) {
        restaurantId = null;
        selectedSlot = null;
      }
    } else {
      state = {
        ...state,
        foodId: existing.copyWith(quantity: existing.quantity - 1),
      };
    }
  }

  int quantityOf(String foodId) => state[foodId]?.quantity ?? 0;

  double get totalAmount =>
      state.values.fold(0, (sum, item) => sum + item.subtotal);

  int get totalItems =>
      state.values.fold(0, (sum, item) => sum + item.quantity);

  int get totalDuration =>
      state.values.fold(0, (sum, item) => sum + (item.food.duration as num).toInt());

  void clear() {
    state = {};
    restaurantId = null;
    selectedSlot = null;
    selectedDate = DateTime.now();
  }
}

final cartProvider =
StateNotifierProvider<CartNotifier, Map<String, CartItem>>((ref) {
  return CartNotifier();
});