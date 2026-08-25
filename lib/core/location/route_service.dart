import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mappls_gl/mappls_gl.dart' as mgl;
import '../maps/map_provider_type.dart';
import 'package:flutter/foundation.dart';

class RouteException implements Exception {
  final String message;
  const RouteException(this.message);
  @override
  String toString() => 'RouteException: $message';
}

class RouteData {
  final List<ll.LatLng> points;
  final double distanceKm;
  final double durationSeconds;

  const RouteData({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });

  int get durationMins => (durationSeconds / 60).ceil();
  static const empty = RouteData(points: [], distanceKm: 0, durationSeconds: 0);
}

class RouteService {
  static Future<List<ll.LatLng>> getRoute({required ll.LatLng start, required ll.LatLng end}) async {
    final data = await getFullRouteData(start: start, end: end);
    return data.points;
  }

  static Future<RouteData> getFullRouteData({required ll.LatLng start, required ll.LatLng end}) async {
    debugPrint('RouteService: Fetching route from (${start.latitude}, ${start.longitude}) to (${end.latitude}, ${end.longitude})');
    
    // Attempt Mappls first as requested.
    try {
      final mapplsData = await _getMapplsRouteSDK(start, end);
      if (mapplsData.points.isNotEmpty) {
        debugPrint('RouteService: Mappls Routing Success');
        return mapplsData;
      } else {
        debugPrint('RouteService: Mappls returned empty route');
      }
    } catch (e) {
      debugPrint('RouteService: Mappls SDK routing error: $e');
    }

    // Attempt OSRM (Free) if Mappls fails.
    try {
      debugPrint('RouteService: Attempting OSRM fallback...');
      final osrmData = await _getOSRMRoute(start, end);
      if (osrmData.points.isNotEmpty) {
        debugPrint('RouteService: OSRM Routing Success');
        return osrmData;
      }
    } catch (e) {
      debugPrint('RouteService: OSRM routing failed: $e');
    }

    // Fallback to Google if others fail.
    switch (MapGlobalConfig.activeMapProvider) {
      case MapProviderType.googleMaps:
        return _getGoogleRouteV2(start, end);
      case MapProviderType.flutterMap:
      default:
        return RouteData.empty;
    }
  }

  /// Mappls Routing using the installed SDK class (MapplsDirection).
  /// This correctly leverages the .a.conf / .a.olf files for authentication.
  static Future<RouteData> _getMapplsRouteSDK(ll.LatLng start, ll.LatLng end) async {
    try {
      final mgl.MapplsDirection direction = mgl.MapplsDirection(
        origin: mgl.LatLng(start.latitude, start.longitude),
        destination: mgl.LatLng(end.latitude, end.longitude),
        resource: mgl.DirectionCriteria.RESOURCE_ROUTE,
        overview: mgl.DirectionCriteria.OVERVIEW_FULL,
        geometries: mgl.DirectionCriteria.GEOMETRY_POLYLINE6, // High precision
        profile: mgl.DirectionCriteria.PROFILE_DRIVING,
      );

      final mgl.DirectionResponse? response = await direction.callDirection();

      if (response == null || response.routes == null || response.routes!.isEmpty) {
        return RouteData.empty;
      }

      final route = response.routes!.first;
      final encodedPolyline = route.geometry;
      
      if (encodedPolyline == null || encodedPolyline.isEmpty) {
        return RouteData.empty;
      }

      // Decode high-precision polyline6
      final points = _decodePolyline6(encodedPolyline);

      return RouteData(
        points: points,
        distanceKm: (route.distance ?? 0) / 1000.0,
        durationSeconds: (route.duration ?? 0).toDouble(),
      );
    } catch (e) {
      debugPrint('Mappls SDK internal error: $e');
      return RouteData.empty;
    }
  }

  static Future<RouteData> _getOSRMRoute(ll.LatLng start, ll.LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson'
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return RouteData.empty;

      final data = jsonDecode(response.body);
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return RouteData.empty;

      final route = routes.first;
      final List coordinates = route['geometry']['coordinates'];
      final points = coordinates.map((c) => ll.LatLng(c[1].toDouble(), c[0].toDouble())).toList();

      return RouteData(
        points: points,
        distanceKm: (route['distance'] as num).toDouble() / 1000.0,
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (e) {
      return RouteData.empty;
    }
  }

  static Future<RouteData> _getGoogleRouteV2(ll.LatLng start, ll.LatLng end) async {
    // Current billing/permission block prevents this from working. 
    // Kept as placeholder for when account is reopened.
    return RouteData.empty;
  }

  /// Polyline6 decoder for Mappls high-precision coordinates
  static List<ll.LatLng> _decodePolyline6(String encoded) {
    final points = <ll.LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(ll.LatLng(lat / 1E6, lng / 1E6)); // Note: 1E6 for polyline6
    }
    return points;
  }
}
