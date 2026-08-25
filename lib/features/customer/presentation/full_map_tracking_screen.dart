import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/maps/ziko_map_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/location/route_service.dart';
import '../../../core/location/route_progress.dart';

class FullMapTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final ll.LatLng customerLoc;
  final ll.LatLng? restaurantLoc;

  const FullMapTrackingScreen({
    super.key,
    required this.orderId,
    required this.customerLoc,
    this.restaurantLoc,
  });

  @override
  ConsumerState<FullMapTrackingScreen> createState() => _FullMapTrackingScreenState();
}

class _FullMapTrackingScreenState extends ConsumerState<FullMapTrackingScreen> {
  ll.LatLng? _riderLoc;
  StreamSubscription<Map<String, dynamic>?>? _riderTrackingSubscription;
  
  bool _routeRequestInFlight = false;
  ll.LatLng? _pendingRiderLocation;
  int _lastRouteSegmentIndex = 0;
  double _routeTotalDistanceKm = 0;
  double _routeTotalDurationSeconds = 0;

  List<ll.LatLng> _fullRoutePoints = [];
  List<ll.LatLng> _remainingRoutePoints = [];
  double _distanceKm = 0;
  int _etaMins = 0;
  DateTime? _lastRouteFetch;

  @override
  void initState() {
    super.initState();
    _riderTrackingSubscription = Supabase.instance.client
        .from('rider_tracking')
        .stream(primaryKey: ['order_id'])
        .eq('order_id', widget.orderId)
        .map((data) => data.isEmpty ? null : data.first)
        .listen((data) {
          if (data == null || !mounted) return;
          final lat = (data['latitude'] as num?)?.toDouble();
          final lon = (data['longitude'] as num?)?.toDouble();
          if (lat == null || lon == null) return;
          final pos = ll.LatLng(lat, lon);
          unawaited(_handleRiderUpdate(pos));
        });
  }

  @override
  void dispose() {
    _riderTrackingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleRiderUpdate(ll.LatLng newPosition) async {
    if (_routeRequestInFlight) {
      _pendingRiderLocation = newPosition;
      return;
    }

    if (_fullRoutePoints.length < 2 || _lastRouteFetch == null) {
      await _fetchNewRoute(newPosition);
      return;
    }

    final projection = RouteProgress.nearestPointOnRoute(
      position: newPosition,
      route: _fullRoutePoints,
      startSegment: _lastRouteSegmentIndex,
    );

    const rerouteThresholdMeters = 100.0;
    final elapsed = DateTime.now().difference(_lastRouteFetch!);

    if (projection.distanceMeters > rerouteThresholdMeters || elapsed.inMinutes >= 5) {
      await _fetchNewRoute(newPosition);
      return;
    }

    final remaining = RouteProgress.buildRemainingRoute(
      riderPosition: newPosition,
      route: _fullRoutePoints,
      projection: projection,
    );

    final remainingDistanceKm = projection.remainingDistanceMeters / 1000.0;
    final ratio = _routeTotalDistanceKm > 0 ? (remainingDistanceKm / _routeTotalDistanceKm).clamp(0.0, 1.0) : 0.0;
    final remainingSeconds = _routeTotalDurationSeconds * ratio;

    if (!mounted) return;

    setState(() {
      _riderLoc = newPosition;
      _remainingRoutePoints = remaining;
      _lastRouteSegmentIndex = projection.segmentIndex;
      _distanceKm = remainingDistanceKm;
      _etaMins = remainingSeconds <= 0 ? _etaMins : (remainingSeconds / 60).ceil();
    });
  }

  Future<void> _fetchNewRoute(ll.LatLng from) async {
    if (_routeRequestInFlight) return;
    _routeRequestInFlight = true;

    try {
      final routeData = await RouteService.getFullRouteData(start: from, end: widget.customerLoc);
      
      final projection = RouteProgress.nearestPointOnRoute(
        position: from,
        route: routeData.points,
      );

      final remaining = RouteProgress.buildRemainingRoute(
        riderPosition: from,
        route: routeData.points,
        projection: projection,
      );

      if (!mounted) return;

      setState(() {
        _fullRoutePoints = List.unmodifiable(routeData.points);
        _remainingRoutePoints = remaining;
        _routeTotalDistanceKm = routeData.distanceKm;
        _routeTotalDurationSeconds = routeData.durationSeconds;
        _distanceKm = projection.remainingDistanceMeters / 1000.0;
        _etaMins = routeData.durationMins;
        _lastRouteSegmentIndex = projection.segmentIndex;
        _lastRouteFetch = DateTime.now();
        _riderLoc = from;
      });
    } catch (e) {
      debugPrint('Full Map Route Error: $e');
      if (mounted) setState(() => _riderLoc = from);
    } finally {
      _routeRequestInFlight = false;
      final pending = _pendingRiderLocation;
      _pendingRiderLocation = null;
      if (pending != null && mounted) {
        unawaited(_handleRiderUpdate(pending));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.charcoal),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ZikoMapWidget(
            initialCenter: _calculateMidPoint(widget.customerLoc, _riderLoc ?? widget.customerLoc),
            initialZoom: 14.0,
            polylinePoints: _remainingRoutePoints,
            restaurantLocation: widget.restaurantLoc,
            deliveryLocation: widget.customerLoc,
            riderLocation: _riderLoc,
            autoCenterOnRider: false, 
          ),

          // Floating Rider Info
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.delivery_dining_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_distanceKm > 0 ? '${_distanceKm.toStringAsFixed(1)} km away' : 'Calculating...', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 18)),
                            Text(_etaMins > 0 ? 'Arriving in ~$_etaMins mins' : 'Rider is moving to you', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      _fab(Icons.center_focus_strong_rounded, () {
                        // Recenter logic
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ll.LatLng _calculateMidPoint(ll.LatLng p1, ll.LatLng p2) {
    return ll.LatLng((p1.latitude + p2.latitude) / 2, (p1.longitude + p2.longitude) / 2);
  }

  Widget _fab(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
