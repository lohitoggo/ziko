import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recentlyViewedProvider = StateNotifierProvider<RecentlyViewedNotifier, List<String>>((ref) {
  return RecentlyViewedNotifier();
});

class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier() : super([]) {
    _load();
  }

  static const _key = 'recently_viewed_shops';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> addView(String businessId) async {
    final newList = List<String>.from(state);
    
    // Remove if already exists to move to top
    newList.remove(businessId);
    
    // Add to top
    newList.insert(0, businessId);
    
    // Keep only last 10
    if (newList.length > 10) {
      newList.removeLast();
    }

    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, newList);
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
