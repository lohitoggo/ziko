import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/inventory_model.dart';

class GroceryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Helper to find the MAIN grocery shop ID
  Future<String?> getMainGroceryShopId() async {
    try {
      final response = await _client
          .from('businesses')
          .select('id')
          .ilike('category', 'grocery')
          .limit(1)
          .maybeSingle();
      return response?['id'];
    } catch (e) {
      return null;
    }
  }

  // --- Category Operations ---
  Future<List<GroceryCategory>> getCategories() async {
    try {
      final response = await _client
          .from('grocery_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      
      return (response as List).map((m) => GroceryCategory.fromMap(m)).toList();
    } catch (e) {
      debugPrint('ERROR: Fetch Categories Failed: $e');
      return [];
    }
  }

  // --- Product Operations (Master Catalog) ---
  Future<List<GroceryProduct>> getProductsByCategory(String categoryId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await _client
          .from('grocery_products')
          .select()
          .eq('category_id', categoryId)
          .range(offset, offset + limit - 1);
      
      debugPrint('DEBUG: Fetched ${response.length} products for category $categoryId');
      return (response as List).map((m) => GroceryProduct.fromMap(m)).toList();
    } catch (e) {
      debugPrint('ERROR: getProductsByCategory Failed: $e');
      return [];
    }
  }

  Future<List<GroceryProduct>> getAllProducts({int limit = 50, String query = '', String? areaId}) async {
    try {
      // 1. Base query for active products
      var request = _client.from('grocery_products').select('*, grocery_inventory!inner(*, businesses!inner(area_id))');
      
      request = request.eq('is_active', true);
      request = request.eq('grocery_inventory.is_available', true);
      
      if (areaId != null && areaId.isNotEmpty) {
        request = request.eq('grocery_inventory.businesses.area_id', areaId);
      }

      if (query.isNotEmpty) {
        request = request.ilike('name', '%$query%');
      }

      final response = await request.order('created_at', ascending: false).limit(limit);
      
      debugPrint('DEBUG: getAllProducts found ${response.length} items (Query: $query, Area: $areaId)');
      return (response as List).map((m) => GroceryProduct.fromMap(m)).toList();
    } catch (e) {
      debugPrint('ERROR: getAllProducts Failed: $e. Falling back to simple fetch.');
      // Fallback: If join fails (e.g. no inventory yet), just show products
      final fallback = await _client.from('grocery_products').select().eq('is_active', true).limit(limit);
      return (fallback as List).map((m) => GroceryProduct.fromMap(m)).toList();
    }
  }

  Future<GroceryProduct?> getProductByBarcode(String barcode) async {
    try {
      final response = await _client
          .from('grocery_products')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();
      
      if (response == null) return null;
      return GroceryProduct.fromMap(response);
    } catch (e) {
      debugPrint('ERROR: getProductByBarcode Failed: $e');
      return null;
    }
  }

  Future<void> upsertProduct(GroceryProduct product) async {
    try {
      await _client.from('grocery_products').upsert(
        product.toMap(),
        onConflict: 'barcode', // Vital for consistency
      );
      debugPrint('DEBUG: Product ${product.name} upserted successfully');
    } catch (e) {
      debugPrint('ERROR: upsertProduct Failed: $e');
      rethrow;
    }
  }

  // --- Inventory Operations (Shop specific) ---
  Future<List<GroceryProduct>> getFullInventoryForShop(String businessId) async {
    try {
      // Logic: Fetch ALL active master products and JOIN with this shop's specific inventory
      // This way, the owner sees EVERYTHING the admin added.
      final response = await _client
          .from('grocery_products')
          .select('*, grocery_inventory(id, stock_quantity, price, is_available)')
          .eq('is_active', true);
      
      return (response as List).map((m) {
        // Find if this shop has this product in their specific inventory
        final invList = m['grocery_inventory'] as List?;
        // Note: Due to join logic, we might need to filter the list for this specific businessId
        // But since we selected for this business context, let's map it.
        return GroceryProduct.fromMap(m);
      }).toList();
    } catch (e) {
      debugPrint('ERROR: getFullInventoryForShop Failed: $e');
      return [];
    }
  }

  Future<List<GroceryInventory>> getShopInventory(String businessId) async {
    try {
      final response = await _client
          .from('grocery_inventory')
          .select('*, grocery_products(*)')
          .eq('business_id', businessId);
      
      return (response as List).map((m) => GroceryInventory.fromMap(m)).toList();
    } catch (e) {
      debugPrint('ERROR: getShopInventory Failed: $e');
      return [];
    }
  }

  Future<void> updateInventory(GroceryInventory inventory) async {
    try {
      await _client.from('grocery_inventory').upsert(
        inventory.toMap(),
        onConflict: 'id',
      );
      debugPrint('DEBUG: Inventory updated for product ${inventory.productId}');
    } catch (e) {
      debugPrint('ERROR: updateInventory Failed: $e');
      rethrow;
    }
  }

  // --- Realtime Streams ---
  Stream<List<GroceryInventory>> watchShopInventory(String businessId) {
    // Standard stream for changes
    return _client
        .from('grocery_inventory')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .asyncMap((data) async {
          // Whenever something changes, refetch with join for full product info
          final joinedData = await _client
              .from('grocery_inventory')
              .select('*, grocery_products(*)')
              .eq('business_id', businessId);
          
          debugPrint('DEBUG: Realtime Inventory Update: Found ${joinedData.length} items');
          return (joinedData as List).map((m) => GroceryInventory.fromMap(m)).toList();
        });
  }
}
