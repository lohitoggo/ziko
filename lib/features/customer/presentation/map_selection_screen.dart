import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/location/map_service.dart';

class MapSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const MapSelectionScreen({super.key, this.initialLocation});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late MapController _mapController;
  LatLng _selectedPoint = const LatLng(22.5726, 88.3639); // Default: Kolkata
  String _currentAddress = 'ঠিকানা খোঁজা হচ্ছে...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLocation != null) {
      _selectedPoint = widget.initialLocation!;
      _fetchAddress(_selectedPoint);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('আপনার ফোনের GPS চালু করুন')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('লোকেশন পারমিশন বন্ধ আছে। সেটিংস থেকে চালু করুন।'),
              action: SnackBarAction(
                label: 'SETTINGS',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('লোকেশন পারমিশন দেওয়া হয়নি')),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // High Accuracy Fetch
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        final point = LatLng(pos.latitude, pos.longitude);
        setState(() => _selectedPoint = point);
        _mapController.move(point, 17); // Closer zoom for precision
        _fetchAddress(point);
      }
    } catch (e) {
      print('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAddress(LatLng point) async {
    final address = await MapService.getAddressFromLatLng(point);
    if (mounted) {
      setState(() => _currentAddress = address ?? 'ঠিকানা পাওয়া যায়নি');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('নিখুঁত লোকেশন পিন করুন'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.only(right: 20), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)))),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: 16,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  setState(() => _selectedPoint = pos.center);
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                   _fetchAddress(_selectedPoint);
                }
              }
            ),
            children: [
              TileLayer(
                // High-detail tiles from a professional source (Free, No-Card)
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.ziko.app',
              ),
            ],
          ),
          
          // Center Marker (Fixed in center, user moves map)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 45),
            ),
          ),

          // Bottom Info Card
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: AppColors.primary),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_city, color: AppColors.muted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, {
                            'lat': _selectedPoint.latitude,
                            'lon': _selectedPoint.longitude,
                            'address': _currentAddress,
                          }),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('এই লোকেশনটি নিশ্চিত করুন'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
