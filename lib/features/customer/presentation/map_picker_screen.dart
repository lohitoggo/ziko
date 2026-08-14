import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({super.key, required this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _pickedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  Future<void> _searchLocation() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'ziko_app'});
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newPos = LatLng(lat, lon);
          
          _mapController.move(newPos, 17);
          setState(() {
            _pickedLocation = newPos;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লোকেশন খুঁজে পাওয়া যায়নি')));
        }
      }
    } catch (e) {
      debugPrint('Search Error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Adjust Location', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, color: AppColors.charcoal)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.charcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. The Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 17,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && pos.center != null) {
                  setState(() {
                    _pickedLocation = pos.center!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.ziko.app',
              ),
            ],
          ),

          // 2. Fixed Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40), 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: const Text('Move map to pick', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.location_on_rounded, size: 45, color: AppColors.primary),
                ],
              ),
            ),
          ),

          // 3. Floating Search & Confirmation Bar
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SEARCH BAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search address or area...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      suffixIcon: _isSearching 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(icon: const Icon(Icons.search_rounded, color: AppColors.primary), onPressed: _searchLocation),
                    ),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
                const SizedBox(height: 12),
                
                // CONFIRMATION CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Search or Move the pin exactly on your doorstep.',
                              style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, _pickedLocation),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text('CONFIRM LOCATION', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Back to GPS Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 70, right: 20,
            child: FloatingActionButton.small(
              onPressed: () {
                _mapController.move(widget.initialLocation, 17);
                setState(() => _pickedLocation = widget.initialLocation);
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
