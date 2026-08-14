import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  /// Converts GPS coordinates into a readable address using Nominatim (OpenStreetMap)
  /// This is 100% free and requires no API Key.
  static Future<String?> getAddressFromLatLng(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'ZikoApp/1.0', // Important for OSM compliance
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] as String?;
      }
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }

  /// Search for an address and return coordinates (Search functionality)
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'ZikoApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => {
          'name': e['display_name'],
          'lat': double.parse(e['lat']),
          'lon': double.parse(e['lon']),
        }).toList();
      }
      return [];
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }
}
