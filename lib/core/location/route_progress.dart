import 'package:latlong2/latlong.dart';

class RouteProjection {
  final int segmentIndex;
  final double distanceMeters;
  final double remainingDistanceMeters;

  RouteProjection({
    required this.segmentIndex,
    required this.distanceMeters,
    required this.remainingDistanceMeters,
  });
}

class RouteProgress {
  static const Distance _distance = Distance();

  /// Finds the nearest segment on the route from current position.
  static RouteProjection nearestPointOnRoute({
    required LatLng position,
    required List<LatLng> route,
    int startSegment = 0,
  }) {
    if (route.length < 2) {
      return RouteProjection(segmentIndex: 0, distanceMeters: 0, remainingDistanceMeters: 0);
    }

    int closestSegment = startSegment;
    double minDistance = double.infinity;

    // We only look ahead to avoid jumping back if the rider reverses slightly
    for (int i = startSegment; i < route.length - 1; i++) {
      final dist = _distanceToSegment(position, route[i], route[i + 1]);
      if (dist < minDistance) {
        minDistance = dist;
        closestSegment = i;
      }
    }

    // Calculate total remaining distance from closest point forward
    double remaining = 0;
    // Approximate: distance from current pos to next node + remaining nodes
    remaining += _distance.as(LengthUnit.Meter, position, route[closestSegment + 1]);
    for (int i = closestSegment + 1; i < route.length - 1; i++) {
      remaining += _distance.as(LengthUnit.Meter, route[i], route[i + 1]);
    }

    return RouteProjection(
      segmentIndex: closestSegment,
      distanceMeters: minDistance,
      remainingDistanceMeters: remaining,
    );
  }

  /// Builds a list of points from the rider's current position to the end.
  static List<LatLng> buildRemainingRoute({
    required LatLng riderPosition,
    required List<LatLng> route,
    required RouteProjection projection,
  }) {
    if (route.isEmpty) return [];
    if (projection.segmentIndex >= route.length - 1) return [riderPosition, route.last];

    final List<LatLng> remaining = [];
    remaining.add(riderPosition);
    remaining.addAll(route.sublist(projection.segmentIndex + 1));
    return remaining;
  }

  static double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    // Basic point-to-segment distance using latitude/longitude as Cartesian coordinates
    // for short distances. This is standard for 100m thresholds.
    double x = p.longitude, y = p.latitude;
    double x1 = a.longitude, y1 = a.latitude;
    double x2 = b.longitude, y2 = b.latitude;

    double dx = x2 - x1;
    double dy = y2 - y1;

    if (dx == 0 && dy == 0) return _distance.as(LengthUnit.Meter, p, a);

    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);

    if (t < 0) return _distance.as(LengthUnit.Meter, p, a);
    if (t > 1) return _distance.as(LengthUnit.Meter, p, b);

    return _distance.as(LengthUnit.Meter, p, LatLng(y1 + t * dy, x1 + t * dx));
  }
}
