import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  /// Fetches route between two points using OpenRouteService (Free)
  /// Returns a list of coordinates for drawing the blue polyline.
  static Future<List<LatLng>> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        
        return coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      }
      return [];
    } catch (e) {
      print('Route fetch error: $e');
      return [];
    }
  }

  /// Formats distance and time for display
  static Future<Map<String, String>> getRouteInfo(LatLng start, LatLng end) async {
    // Basic placeholder for professional UI feel
    return {
      'distance': '...', 
      'time': '...',
    };
  }
}
