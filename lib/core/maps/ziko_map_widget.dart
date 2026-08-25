import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'map_provider_type.dart';
import '../theme/app_theme.dart';

class ZikoMapWidget extends StatefulWidget {
  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<ll.LatLng> polylinePoints;
  final MapController? flutterMapController;
  final Function(gm.GoogleMapController)? onGoogleMapCreated;

  final ll.LatLng? restaurantLocation;
  final ll.LatLng? riderLocation;
  final ll.LatLng? deliveryLocation;
  final bool autoCenterOnRider;

  const ZikoMapWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14.0,
    this.polylinePoints = const [],
    this.flutterMapController,
    this.onGoogleMapCreated,
    this.restaurantLocation,
    this.riderLocation,
    this.deliveryLocation,
    this.autoCenterOnRider = true,
  });

  @override
  State<ZikoMapWidget> createState() => _ZikoMapWidgetState();
}

class _ZikoMapWidgetState extends State<ZikoMapWidget> {
  // Google Maps state
  gm.GoogleMapController? _googleMapController;
  bool _userInteracted = false;

  gm.BitmapDescriptor? _riderIcon;
  gm.BitmapDescriptor? _customerIcon;
  gm.BitmapDescriptor? _shopIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
  }

  Future<void> _loadCustomIcons() async {
    _riderIcon = await gm.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(35, 35)),
      'assets/map_icons/rider.png',
    );
    _customerIcon = await gm.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(35, 35)),
      'assets/map_icons/home.png',
    );
    _shopIcon = await gm.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(35, 35)),
      'assets/map_icons/shop_marker.png',
    );
    if (mounted) setState(() {});
  }

  // Removed _createCustomMarkerBitmap as it's no longer used

  void _onGoogleCreated(gm.GoogleMapController controller) {
    _googleMapController = controller;
    if (widget.onGoogleMapCreated != null) {
      widget.onGoogleMapCreated!(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (MapGlobalConfig.activeMapProvider) {
      case MapProviderType.googleMaps:
        return _buildGoogleMaps();
      case MapProviderType.flutterMap:
      default:
        return _buildFlutterMap();
    }
  }

  Widget _buildGoogleMaps() {
    final markers = <gm.Marker>{};

    if (widget.restaurantLocation != null) {
      markers.add(
        gm.Marker(
          markerId: const gm.MarkerId('restaurant'),
          position: gm.LatLng(
            widget.restaurantLocation!.latitude,
            widget.restaurantLocation!.longitude,
          ),
          icon: _shopIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueOrange),
          infoWindow: const gm.InfoWindow(title: 'Shop'),
        ),
      );
    }

    if (widget.deliveryLocation != null) {
      markers.add(
        gm.Marker(
          markerId: const gm.MarkerId('delivery'),
          position: gm.LatLng(
            widget.deliveryLocation!.latitude,
            widget.deliveryLocation!.longitude,
          ),
          icon: _customerIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
          infoWindow: const gm.InfoWindow(title: 'Customer'),
        ),
      );
    }

    if (widget.riderLocation != null) {
      markers.add(
        gm.Marker(
          markerId: const gm.MarkerId('rider'),
          position: gm.LatLng(
            widget.riderLocation!.latitude,
            widget.riderLocation!.longitude,
          ),
          icon: _riderIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
          infoWindow: const gm.InfoWindow(title: 'Rider'),
        ),
      );
    }

    final polylines = <gm.Polyline>{};

    if (widget.polylinePoints.length >= 2) {
      polylines.add(
        gm.Polyline(
          polylineId: const gm.PolylineId('route'),
          points: widget.polylinePoints
              .map(
                (p) => gm.LatLng(
                  p.latitude,
                  p.longitude,
                ),
              )
              .toList(),
          color: const Color(0xFFF45D27).withValues(alpha: 0.8), // Premium Ziko Orange with 80% opacity
          width: 5, // Slimmer profile
          jointType: gm.JointType.round,
          startCap: gm.Cap.roundCap,
          endCap: gm.Cap.roundCap,
        ),
      );
    }

    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(
          widget.initialCenter.latitude,
          widget.initialCenter.longitude,
        ),
        zoom: widget.initialZoom,
      ),
      onMapCreated: _onGoogleCreated,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      onCameraMoveStarted: () {
        if (!_userInteracted) setState(() => _userInteracted = true);
      },
    );
  }

  Widget _buildFlutterMap() {
    return FlutterMap(
      mapController: widget.flutterMapController,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture) _userInteracted = true;
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.ziko.app',
        ),
        if (widget.polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(points: widget.polylinePoints, color: AppColors.primary, strokeWidth: 4),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.restaurantLocation != null)
              Marker(point: widget.restaurantLocation!, width: 40, height: 40, child: const Icon(Icons.storefront_rounded, color: Colors.orange, size: 30)),
            if (widget.deliveryLocation != null)
              Marker(point: widget.deliveryLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
            if (widget.riderLocation != null)
              Marker(point: widget.riderLocation!, width: 55, height: 55, child: _buildRiderMarkerIcon()),
          ],
        ),
      ],
    );
  }

  Widget _buildRiderMarkerIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]),
          child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 26),
        ),
        Positioned(
          top: 0, right: 0,
          child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Text('z', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }
}
