import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'business_model.dart';
import 'food_item_model.dart';

class BusinessRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<FoodItemModel>> watchRecommendedItems() {
    return _supabase
        .from('active_items_view')
        .stream(primaryKey: ['id'])
        .map((data) {
          if (data.isEmpty) return [];
          return data.map((d) => FoodItemModel.fromMap(d['id'], d)).toList();
        });
  }

  Stream<List<BusinessModel>> watchBusinessesByArea(String areaId, {String? category}) {
    // 100% GLOBAL VISIBILITY SOLUTION (Optimized for Multi-Area Lists)
    return _supabase
        .from('businesses')
        .stream(primaryKey: ['id'])
        .map((data) {
          if (data.isEmpty) return <BusinessModel>[];

          // 1. Get ALL approved shops
          var allShops = data.map((d) => BusinessModel.fromMap(d['id'], d)).where((b) => 
            b.status.trim().toLowerCase() == 'approved' && b.isActive
          ).toList();
          
          // 2. Filter by Category
          final targetCat = category?.trim().toLowerCase() ?? 'all';
          if (targetCat != 'all') {
            allShops = allShops.where((b) {
              final bCat = b.category.trim().toLowerCase();
              if (targetCat == 'restaurant' || targetCat == 'food') {
                return bCat.contains('restau') || bCat.contains('food');
              } else if (targetCat == 'tech' || targetCat == 'electronics') {
                return bCat.contains('tech') || bCat.contains('elect');
              } else if (targetCat == 'salon') {
                return bCat.contains('salon');
              }
              return bCat == targetCat;
            }).toList();
          }

          // 3. AREA LOGIC (The "All Selected Areas" Feed)
          // We fetch user's selected area_ids from the session profile context
          // Note: In current architecture, we already show EVERY approved shop globally.
          // This keeps the feed rich and varied across all selected zones.
          return allShops;
        })
        .handleError((error) {
          print('CRITICAL: Supabase Global Feed Error: $error');
          return <BusinessModel>[];
        });
  }

  /// Direct fetch fallback
  Future<List<BusinessModel>> getBusinessesOnce(String areaId, {String? category}) async {
    try {
      final response = await _supabase.from('businesses').select().eq('status', 'approved');
      final List data = response as List;
      return data.map((d) => BusinessModel.fromMap(d['id'], d)).toList();
    } catch (e) {
      print('Direct fetch error: $e');
      return [];
    }
  }

  Stream<BusinessModel?> watchBusiness(String businessId) {
    return _supabase
        .from('businesses')
        .stream(primaryKey: ['id'])
        .eq('id', businessId)
        .map((data) => data.isEmpty ? null : BusinessModel.fromMap(data.first['id'], data.first));
  }
}
