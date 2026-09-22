import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../features/auth/data/area_model.dart';
import '../theme/app_theme.dart';

class ServiceabilityHelper {
  /// Standard Ray-Casting algorithm to check if a point is inside a polygon.
  static bool isPointInPolygon(ll.LatLng point, List<ll.LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool isInside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].longitude > point.longitude) != (polygon[j].longitude > point.longitude) &&
          (point.latitude < (polygon[j].latitude - polygon[i].latitude) * (point.longitude - polygon[i].longitude) / (polygon[j].longitude - polygon[i].longitude) + polygon[i].latitude)) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }

  /// Finds the matching AreaModel for a location point based on drawn boundary polygons.
  static AreaModel? getMatchingAreaForLocation({
    required double? userLat,
    required double? userLon,
    required List<AreaModel> activeAreas,
  }) {
    if (userLat == null || userLon == null) return null;
    final point = ll.LatLng(userLat, userLon);

    bool anyAreaHasPolygon = false;

    for (final area in activeAreas) {
      if (area.polygonPoints.length >= 3) {
        anyAreaHasPolygon = true;
        if (isPointInPolygon(point, area.polygonPoints)) {
          return area; // Found exact drawn boundary match!
        }
      }
    }

    // Fallback: If no areas have drawn polygons configured yet, return null
    return null;
  }

  /// Checks if location is serviceable (either inside a polygon, or fallback if no polygons drawn yet)
  static bool isLocationServiceable({
    required double? userLat,
    required double? userLon,
    required List<AreaModel> activeAreas,
  }) {
    if (userLat == null || userLon == null) return true;
    if (activeAreas.isEmpty) return false;

    bool anyAreaHasPolygon = activeAreas.any((a) => a.polygonPoints.length >= 3);

    if (anyAreaHasPolygon) {
      final matching = getMatchingAreaForLocation(
        userLat: userLat,
        userLon: userLon,
        activeAreas: activeAreas,
      );
      return matching != null;
    }

    // If no active area has polygons drawn yet, default to true
    // so existing installations continue to work until admin draws polygons.
    return true;
  }

  /// Shows the friendly English Unserviceable Dialog to the customer.
  static void showUnserviceableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.location_off_rounded, size: 48, color: Colors.deepOrange),
            ),
            const SizedBox(height: 12),
            Text(
              'We Are Coming Soon! 🚀',
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.charcoal),
            ),
          ],
        ),
        content: Text(
          'We are not serviceable in this area yet, but we are coming soon! Don\'t worry.',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('OK, I UNDERSTAND', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
