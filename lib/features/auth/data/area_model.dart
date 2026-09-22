import 'package:latlong2/latlong.dart' as ll;

class AreaModel {
  final String id;
  final String name;
  final double deliveryCharge;
  final double minimumOrder;
  final int estimatedDeliveryMinutes;
  final String status;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final List<ll.LatLng> polygonPoints;

  AreaModel({
    required this.id,
    required this.name,
    required this.deliveryCharge,
    required this.minimumOrder,
    required this.estimatedDeliveryMinutes,
    required this.status,
    this.latitude,
    this.longitude,
    this.radiusKm = 10.0,
    this.polygonPoints = const [],
  });

  factory AreaModel.fromMap(String id, Map<String, dynamic> map) {
    List<ll.LatLng> parsedPolygon = [];
    final rawPolygon = map['boundary_polygon'] ?? map['polygon_points'];
    if (rawPolygon != null && rawPolygon is List) {
      for (var pt in rawPolygon) {
        if (pt is Map) {
          final lat = double.tryParse(pt['lat']?.toString() ?? '');
          final lng = double.tryParse(pt['lng']?.toString() ?? pt['lon']?.toString() ?? '');
          if (lat != null && lng != null) {
            parsedPolygon.add(ll.LatLng(lat, lng));
          }
        }
      }
    }

    return AreaModel(
      id: id,
      name: map['name'] ?? '',
      deliveryCharge: (map['delivery_charge'] ?? map['deliveryCharge'] ?? 0).toDouble(),
      minimumOrder: (map['min_order_amount'] ?? map['minimumOrder'] ?? 0).toDouble(),
      estimatedDeliveryMinutes: map['estimated_delivery_minutes'] ?? map['estimatedDeliveryMinutes'] ?? 0,
      status: (map['is_active'] ?? map['isActive'] ?? true) ? 'active' : 'inactive',
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
      radiusKm: (map['radius_km'] ?? map['radius'] ?? 10.0).toDouble(),
      polygonPoints: parsedPolygon,
    );
  }
}
