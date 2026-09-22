import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mappls_gl/mappls_gl.dart' as mgl;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';

class AdminAreaDrawScreen extends StatefulWidget {
  final List<ll.LatLng> initialPolygon;
  final String areaName;

  const AdminAreaDrawScreen({
    super.key,
    required this.initialPolygon,
    required this.areaName,
  });

  @override
  State<AdminAreaDrawScreen> createState() => _AdminAreaDrawScreenState();
}

class _AdminAreaDrawScreenState extends State<AdminAreaDrawScreen> {
  final List<gm.LatLng> _points = [];
  gm.GoogleMapController? _mapController;
  late final TextEditingController _searchCtrl;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.areaName);
    for (var p in widget.initialPolygon) {
      _points.add(gm.LatLng(p.latitude, p.longitude));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onMapTapped(gm.LatLng position) {
    setState(() {
      _points.add(position);
    });
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  void _clearAllPoints() {
    setState(() {
      _points.clear();
    });
  }

  Future<void> _fetchOfficialBoundary() async {
    final rawQuery = _searchCtrl.text.trim();
    if (rawQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('গ্রাম বা এলাকার নাম লিখুন')),
      );
      return;
    }

    setState(() => _isSearching = true);

    List<gm.LatLng> fetchedPoints = [];
    gm.LatLng? fallbackCenter;

    // Step 1: Use Mappls (MapmyIndia) Geocoding first for high precision Indian location search
    try {
      final mapplsRes = await mgl.MapplsGeocode(address: rawQuery).callGeocode();
      if (mapplsRes != null && mapplsRes.results != null && mapplsRes.results!.isNotEmpty) {
        final top = mapplsRes.results!.first;
        final lat = double.tryParse(top.latitude?.toString() ?? '');
        final lng = double.tryParse(top.longitude?.toString() ?? '');
        if (lat != null && lng != null) {
          fallbackCenter = gm.LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Mappls Geocode search error: $e');
    }

    // Step 2: Query for boundary polygons
    final queriesToTry = [
      '$rawQuery, India',
      '$rawQuery, West Bengal, India',
      rawQuery,
    ];

    for (final q in queriesToTry) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&polygon_geojson=1&countrycodes=in&limit=1',
        );
        final response = await http.get(url, headers: {'User-Agent': 'ziko_app'});

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          if (data.isNotEmpty) {
            final item = data[0];

            if (item['lat'] != null && item['lon'] != null) {
              fallbackCenter = gm.LatLng(
                double.parse(item['lat'].toString()),
                double.parse(item['lon'].toString()),
              );
            }

            if (item['geojson'] != null) {
              final geojson = item['geojson'];
              final String type = geojson['type'] ?? '';
              final List coordinates = geojson['coordinates'] ?? [];

              if (type == 'Polygon' && coordinates.isNotEmpty) {
                final ring = coordinates[0];
                for (var pt in ring) {
                  if (pt is List && pt.length >= 2) {
                    fetchedPoints.add(gm.LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
                  }
                }
              } else if (type == 'MultiPolygon' && coordinates.isNotEmpty) {
                final poly = coordinates[0];
                if (poly is List && poly.isNotEmpty) {
                  final ring = poly[0];
                  for (var pt in ring) {
                    if (pt is List && pt.length >= 2) {
                      fetchedPoints.add(gm.LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
                    }
                  }
                }
              }
            }

            if (fetchedPoints.isNotEmpty) {
              break; // Polygon successfully found
            }
          }
        }
      } catch (e) {
        debugPrint('Fetch attempt error for $q: $e');
      }
    }

    // Fallback: If no complex polygon returned, but we found village GPS center:
    // Generate a smart 4-point initial boundary box around village center (~1.5km)
    if (fetchedPoints.isEmpty && fallbackCenter != null) {
      final lat = fallbackCenter.latitude;
      final lng = fallbackCenter.longitude;
      const delta = 0.012; // Approx 1.5 km
      fetchedPoints = [
        gm.LatLng(lat + delta, lng - delta),
        gm.LatLng(lat + delta, lng + delta),
        gm.LatLng(lat - delta, lng + delta),
        gm.LatLng(lat - delta, lng - delta),
      ];
    }

    if (fetchedPoints.isNotEmpty) {
      setState(() {
        _points.clear();
        _points.addAll(fetchedPoints);
      });

      _mapController?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(fetchedPoints.first, 14),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$rawQuery" -এর ম্যাপ বাউন্ডারি সেটিং করা হয়েছে! (${fetchedPoints.length} পয়েন্ট) ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$rawQuery" এলাকাটি খুঁজে পাওয়া যায়নি। সঠিক বানান দিয়ে আবার চেষ্টা করুন।'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) setState(() => _isSearching = false);
  }

  void _confirmBoundary() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কমপক্ষে ৩টি পিন যোগ করে বাউন্ডারি তৈরি করুন')),
      );
      return;
    }

    final List<ll.LatLng> result = _points
        .map((p) => ll.LatLng(p.latitude, p.longitude))
        .toList();

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final Set<gm.Polygon> polygons = {};
    final Set<gm.Marker> markers = {};

    if (_points.isNotEmpty) {
      polygons.add(
        gm.Polygon(
          polygonId: const gm.PolygonId('area_boundary'),
          points: _points,
          strokeColor: AppColors.primary,
          strokeWidth: 3,
          fillColor: AppColors.primary.withValues(alpha: 0.25),
        ),
      );

      if (_points.length <= 50) {
        for (int i = 0; i < _points.length; i++) {
          markers.add(
            gm.Marker(
              markerId: gm.MarkerId('pt_$i'),
              position: _points[i],
              infoWindow: gm.InfoWindow(title: 'Point ${i + 1}'),
              icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueOrange),
            ),
          );
        }
      }
    }

    final gm.LatLng initialTarget = _points.isNotEmpty
        ? _points.first
        : const gm.LatLng(21.7781, 87.7501);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.areaName.isNotEmpty ? 'Boundary: ${widget.areaName}' : 'Draw Area Boundary',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo Last Point',
              onPressed: _undoLastPoint,
            ),
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear All',
              onPressed: _clearAllPoints,
            ),
        ],
      ),
      body: Stack(
        children: [
          gm.GoogleMap(
            initialCameraPosition: gm.CameraPosition(
              target: initialTarget,
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTapped,
            polygons: polygons,
            markers: markers,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Search & Auto-Fetch Header
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'গ্রাম বা এলাকার নাম লিখুন (যেমন: Contai, Sabang)...',
                        hintStyle: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: (_) => _fetchOfficialBoundary(),
                    ),
                  ),
                  _isSearching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton.icon(
                          onPressed: _fetchOfficialBoundary,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                          label: const Text('AUTO FETCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ],
              ),
            ),
          ),

          // Instructions Banner
          Positioned(
            top: 72,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _points.isEmpty
                    ? '💡 অটো-ফেচ করুন অথবা ম্যাপে পিন ট্যাপ করে সীমানা ড্র করুন'
                    : 'বাউন্ডারি পয়েন্ট: ${_points.length} টি। প্রয়োজনে ট্যাপ করে যোগ/এডিট করুন।',
                style: GoogleFonts.urbanist(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Bottom Confirmation Bar
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _confirmBoundary,
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: Text(
                  'CONFIRM BOUNDARY (${_points.length} POINTS)',
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _points.length >= 3 ? AppColors.primary : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
