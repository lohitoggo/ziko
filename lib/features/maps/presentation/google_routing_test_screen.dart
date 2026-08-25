import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/location/route_service.dart';

class GoogleRoutingTestScreen extends StatefulWidget {
  const GoogleRoutingTestScreen({super.key});

  @override
  State<GoogleRoutingTestScreen> createState() => _GoogleRoutingTestScreenState();
}

class _GoogleRoutingTestScreenState extends State<GoogleRoutingTestScreen> {
  ll.LatLng? _pointA;
  ll.LatLng? _pointB;
  List<ll.LatLng> _routePoints = [];
  double _distanceKm = 0;
  int _durationMins = 0;
  bool _isLoading = false;

  gm.BitmapDescriptor? _riderIcon;
  gm.BitmapDescriptor? _customerIcon;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    _riderIcon = await gm.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(35, 35)),
      'assets/map_icons/rider.png',
    );
    _customerIcon = await gm.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(35, 35)),
      'assets/map_icons/home.png',
    );
    if (mounted) setState(() {});
  }

  void _onMapTapped(ll.LatLng point) {
    setState(() {
      if (_pointA == null || (_pointA != null && _pointB != null)) {
        _pointA = point;
        _pointB = null;
        _routePoints = [];
        _distanceKm = 0;
        _durationMins = 0;
      } else {
        _pointB = point;
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_pointA == null || _pointB == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await RouteService.getFullRouteData(start: _pointA!, end: _pointB!);
      if (mounted) {
        setState(() {
          _routePoints = data.points;
          _distanceKm = data.distanceKm;
          _durationMins = data.durationMins;
        });
      }
    } catch (e) {
      debugPrint('Routing Test Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Routing Test', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _pointA = null;
                _pointB = null;
                _routePoints = [];
                _distanceKm = 0;
                _durationMins = 0;
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Re-implementing a simple test map for direct control
          gm.GoogleMap(
            initialCameraPosition: const gm.CameraPosition(target: gm.LatLng(22.5726, 88.3639), zoom: 12),
            onTap: (latLng) => _onMapTapped(ll.LatLng(latLng.latitude, latLng.longitude)),
            polylines: {
              if (_routePoints.isNotEmpty)
                gm.Polyline(
                  polylineId: const gm.PolylineId('test_route'),
                  points: _routePoints.map((p) => gm.LatLng(p.latitude, p.longitude)).toList(),
                  color: const Color(0xFFF45D27).withValues(alpha: 0.8),
                  width: 5,
                  jointType: gm.JointType.round,
                  startCap: gm.Cap.roundCap,
                  endCap: gm.Cap.roundCap,
                )
            },
            markers: {
              if (_pointA != null)
                gm.Marker(
                  markerId: const gm.MarkerId('pointA'),
                  position: gm.LatLng(_pointA!.latitude, _pointA!.longitude),
                  icon: _riderIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
                  infoWindow: const gm.InfoWindow(title: 'Rider (Start)'),
                ),
              if (_pointB != null)
                gm.Marker(
                  markerId: const gm.MarkerId('pointB'),
                  position: gm.LatLng(_pointB!.latitude, _pointB!.longitude),
                  icon: _customerIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
                  infoWindow: const gm.InfoWindow(title: 'Customer (Destination)'),
                ),
            },
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _pointA == null 
                      ? 'Tap map to set Start Point' 
                      : (_pointB == null ? 'Tap map to set Destination' : 'High Precision Route Found'),
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  if (_distanceKm > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoItem(Icons.directions_car_filled_rounded, '${_distanceKm.toStringAsFixed(1)} km', 'Distance'),
                        _infoItem(Icons.access_time_filled_rounded, '$_durationMins mins', 'Duration'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
