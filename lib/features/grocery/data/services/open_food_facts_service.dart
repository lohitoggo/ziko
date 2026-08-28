import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OpenFoodFactsService {
  /// Fetches product information from Open Food Facts API using barcode
  Future<Map<String, dynamic>?> fetchProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          return {
            'name': product['product_name'] ?? '',
            'brand': product['brands'] ?? '',
            'image_url': product['image_url'] ?? '',
            'quantity': product['quantity'] ?? '',
            'barcode': barcode,
            'description': product['generic_name'] ?? product['ingredients_text'] ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('ERROR: Open Food Facts API Failed: $e');
      return null;
    }
  }

  /// Fetches products from Open Food Facts with India-specific optimization
  Future<List<Map<String, dynamic>>> fetchProductsByCategory(String category, {int page = 1, String? searchKeyword}) async {
    try {
      // Logic: Target ONLY Indian products to improve speed and relevance
      // API Parameters: tagtype_0=countries, tag_0=India (filters by country)
      String urlString = 'https://world.openfoodfacts.org/cgi/search.pl?action=process&page=$page&page_size=30&json=true&tagtype_0=countries&tag_0=India';
      
      String terms = '';
      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        terms = searchKeyword;
      } else if (category != 'all') {
        terms = category;
      }

      if (terms.isNotEmpty) {
        urlString += '&search_terms=${Uri.encodeComponent(terms)}';
      } else {
        urlString += '&sort_by=unique_scans_n';
      }
      
      final url = Uri.parse(urlString);
      debugPrint('DEBUG: Calling India-Optimized API: $url');
      
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List products = data['products'] ?? [];
        debugPrint('DEBUG: Found ${products.length} Indian products');
        
        return products.map((p) => {
          'name': p['product_name'] ?? p['product_name_en'] ?? p['generic_name'] ?? 'Unknown Product',
          'brand': p['brands'] ?? 'Local Brand',
          'image_url': p['image_front_url'] ?? p['image_url'] ?? '',
          'barcode': p['code'] ?? '',
          'quantity': p['quantity'] ?? '',
          'description': p['generic_name'] ?? '',
        }).toList();
      } else {
        debugPrint('ERROR: API returned ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('ERROR: Indian Search Failed: $e');
      return [];
    }
  }
}
