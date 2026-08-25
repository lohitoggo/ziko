import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/maps/map_provider_type.dart';
import '../../../core/maps/ziko_map_widget.dart';
import '../../../core/location/route_service.dart';
import '../../../core/location/route_progress.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/user_provider.dart';
import '../../rider/providers/rider_provider.dart';
import '../providers/order_provider.dart';
import '../data/business_model.dart';
import 'full_map_tracking_screen.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final MapController _flutterMapController = MapController();
  gm.GoogleMapController? _googleMapController;
  
  ll.LatLng? _riderLocation;
  ll.LatLng? _customerLocation;
  ll.LatLng? _restaurantLocation;
  final bool _autoCenter = true;
  
  StreamSubscription<Map<String, dynamic>?>? _riderTrackingSubscription;
  bool _routeRequestInFlight = false;
  ll.LatLng? _pendingRiderLocation;
  int _lastRouteSegmentIndex = 0;
  double _routeTotalDistanceKm = 0;
  double _routeTotalDurationSeconds = 0;

  List<ll.LatLng> _fullRoutePoints = [];
  List<ll.LatLng> _remainingRoutePoints = [];
  double _distanceInKm = 0;
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
        .listen(_onRiderTrackingUpdate);
  }

  @override
  void dispose() {
    _riderTrackingSubscription?.cancel();
    super.dispose();
  }

  void _onRiderTrackingUpdate(Map<String, dynamic>? data) {
    if (data == null || !mounted) return;

    final lat = (data['latitude'] as num?)?.toDouble();
    final lon = (data['longitude'] as num?)?.toDouble();

    if (lat == null || lon == null) return;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return;

    final position = ll.LatLng(lat, lon);

    if (_riderLocation != null) {
      final movedMeters = const ll.Distance().as(ll.LengthUnit.Meter, _riderLocation!, position);
      if (movedMeters < 5) return;
    }

    unawaited(_handleRiderUpdate(position));
  }

  Future<void> _handleRiderUpdate(ll.LatLng newPosition) async {
    if (_customerLocation == null) {
      if (mounted) setState(() => _riderLocation = newPosition);
      return;
    }

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
    double remainingDurationSeconds = 0;

    if (_routeTotalDistanceKm > 0 && _routeTotalDurationSeconds > 0) {
      final ratio = (remainingDistanceKm / _routeTotalDistanceKm).clamp(0.0, 1.0);
      remainingDurationSeconds = _routeTotalDurationSeconds * ratio;
    }

    if (!mounted) return;

    setState(() {
      _riderLocation = newPosition;
      _remainingRoutePoints = remaining;
      _lastRouteSegmentIndex = projection.segmentIndex;
      _distanceInKm = remainingDistanceKm;
      _etaMins = remainingDurationSeconds <= 0 ? _etaMins : (remainingDurationSeconds / 60).ceil();
    });
  }

  Future<void> _fetchNewRoute(ll.LatLng from) async {
    if (_routeRequestInFlight) return;
    _routeRequestInFlight = true;

    try {
      final routeData = await RouteService.getFullRouteData(start: from, end: _customerLocation!);
      
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
        _distanceInKm = projection.remainingDistanceMeters / 1000.0;
        _etaMins = routeData.durationMins;
        _lastRouteSegmentIndex = projection.segmentIndex;
        _lastRouteFetch = DateTime.now();
        _riderLocation = from;
      });
    } catch (e) {
      debugPrint('Route fetch failed: $e');
      if (mounted) setState(() => _riderLocation = from);
    } finally {
      _routeRequestInFlight = false;
      final pending = _pendingRiderLocation;
      _pendingRiderLocation = null;
      if (pending != null && mounted) {
        unawaited(_handleRiderUpdate(pending));
      }
    }
  }

  String _getFormattedStatus(String status, {bool isSalon = false}) {
    if (isSalon) {
      switch (status) {
        case 'placed': return 'Appointment Placed';
        case 'accepted': return 'Confirmed';
        case 'ready': return 'Ready for Service';
        case 'delivered': return 'Service Completed';
        default: return 'Confirmed';
      }
    }
    switch (status) {
      case 'placed': return 'Finding Rider';
      case 'accepted': return 'Store Accepted';
      case 'preparing': return 'Chef is Cooking';
      case 'ready': return 'Rider Assigned';
      case 'picked_up': return 'Order Picked Up';
      case 'out_for_delivery': return 'On The Way';
      case 'delivered': return 'Delivered';
      default: return status.toUpperCase();
    }
  }

  String _getEtaText() {
    if (_etaMins <= 0) return 'Arriving soon';
    return '$_etaMins mins';
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  static const _steps = [
    ['placed', 'Order Placed'],
    ['accepted', 'Accepted'],
    ['preparing', 'Preparing'],
    ['ready', 'Order Ready'],
    ['rider_assigned', 'Rider Assigned'],
    ['picked_up', 'Picked Up'],
    ['out_for_delivery', 'On The Way'],
    ['delivered', 'Delivered'],
  ];

  int _currentStepIndex(String status) {
    final index = _steps.indexWhere((s) => s[0] == status);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(singleOrderProvider(widget.orderId));
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFB),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (order) {
          if (order == null) return const Center(child: Text('Order not found'));

          final status = order['status'] ?? 'placed';
          final restaurantId = order['business_id'] ?? '';
          final businessAsync = ref.watch(businessProvider(restaurantId));
          final riderId = order['rider_id'];
          final isSalon = order['appointment_time'] != null;
          final currentIndex = _currentStepIndex(status);

          return businessAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (business) {
              if (_customerLocation == null) {
                final lat = (order['customer_lat'] as num?)?.toDouble();
                final lon = (order['customer_lon'] as num?)?.toDouble();
                if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                  _customerLocation = ll.LatLng(lat, lon);
                }
              }

              if (_restaurantLocation == null && business != null) {
                final lat = business.latitude;
                final lon = business.longitude;
                if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                  _restaurantLocation = ll.LatLng(lat, lon);
                }
              }

              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 25, left: 20, right: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF45D27), Color(0xFFFF8A00)]),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isSalon ? 'Booking Tracking' : 'Track Order', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              Text('ORDER ID: #${widget.orderId.substring(0, 8).toUpperCase()}', style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        _actionIcon(Icons.help_outline_rounded, Colors.white, () {}),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        children: [
                          if (isSalon) _buildSalonPass(order, business, status) else _buildMapSection(order, status),
                          _buildTimelineCard(currentIndex, isSalon: isSalon),
                          if (!isSalon) _buildDeliveryAddressCard(order, userAsync),
                          _buildItemsCard(order, isSalon: isSalon),
                          if (!isSalon && riderId != null) _buildRiderCard(riderId),
                          _buildBillCard(order),
                          _buildSupportCard(business),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomSheet: _buildBottomAction(orderAsync.value),
    );
  }

  Widget _buildMapSection(Map<String, dynamic> order, String status) {
    return Container(
      height: 320,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            ZikoMapWidget(
              initialCenter: _customerLocation ?? const ll.LatLng(22.5726, 88.3639),
              initialZoom: 14,
              flutterMapController: _flutterMapController,
              onGoogleMapCreated: (controller) => _googleMapController = controller,
              polylinePoints: _remainingRoutePoints,
              restaurantLocation: _restaurantLocation,
              deliveryLocation: _customerLocation,
              riderLocation: _riderLocation,
              autoCenterOnRider: false,
            ),
            
            _buildStatusOverlay(status),
            Positioned(
              right: 12, bottom: 12,
              child: Column(
                children: [
                  _mapFab(Icons.my_location_rounded, () async {
                    try {
                      final pos = await Geolocator.getCurrentPosition();
                      final userPos = ll.LatLng(pos.latitude, pos.longitude);
                      if (MapGlobalConfig.activeMapProvider == MapProviderType.googleMaps) {
                        _googleMapController?.animateCamera(gm.CameraUpdate.newLatLngZoom(gm.LatLng(userPos.latitude, userPos.longitude), 16));
                      } else {
                        _flutterMapController.move(userPos, 16);
                      }
                    } catch (e) {}
                  }),
                  const SizedBox(height: 8),
                  _mapFab(Icons.center_focus_strong_rounded, () {
                    if (_riderLocation != null) {
                      if (MapGlobalConfig.activeMapProvider == MapProviderType.googleMaps) {
                        _googleMapController?.animateCamera(gm.CameraUpdate.newLatLngZoom(gm.LatLng(_riderLocation!.latitude, _riderLocation!.longitude), 16));
                      } else {
                        _flutterMapController.move(_riderLocation!, 16);
                      }
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(String status) {
    return Positioned(
      top: 12, left: 12, right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STATUS', style: GoogleFonts.urbanist(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1)), Text(_getFormattedStatus(status), style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary))]),
                if (_riderLocation != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('ESTIMATED ARRIVAL', style: GoogleFonts.urbanist(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text(_getEtaText(), style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w900))
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalonPass(Map<String, dynamic> order, BusinessModel? business, String status) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('APPOINTMENT STATUS', style: GoogleFonts.urbanist(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(_getFormattedStatus(status, isSalon: true), style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary))]),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))), child: Text('CONFIRMED', style: GoogleFonts.urbanist(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(15), child: business?.logoUrl != null ? Image.network(business!.logoUrl!, width: 55, height: 55, fit: BoxFit.cover) : Container(width: 55, height: 55, color: Colors.grey.shade100, child: const Icon(Icons.storefront, color: Colors.grey))),
                    const SizedBox(width: 15),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(business?.name ?? 'Salon Name', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800)), Text(business?.address ?? 'Store Address', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)]))
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _compactPassItem(Icons.calendar_today_rounded, 'Date', order['appointment_time']?.toString().split(' | ').first ?? 'N/A'),
                    const SizedBox(width: 10),
                    _compactPassItem(Icons.access_time_rounded, 'Time', order['appointment_time']?.toString().split('|').last.split(',').first.trim() ?? 'N/A'),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(onPressed: () async {
                      final addr = business?.address ?? '';
                      final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
                      if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                    }, icon: const Icon(Icons.directions_rounded, size: 16), label: const Text('DIRECTIONS'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)))),
                    const SizedBox(width: 10),
                    _actionIcon(Icons.call_rounded, Colors.green, () => _makeCall(business?.ownerPhone)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15)]),
                  child: QrImageView(
                    data: widget.orderId,
                    version: QrVersions.auto,
                    size: 110.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.charcoal),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Text('SCAN AT STORE TO COMPLETE', style: GoogleFonts.urbanist(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1))
              ]
            )
          ),
        ],
      ),
    );
  }

  Widget _compactPassItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(value, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(int currentIndex, {bool isSalon = false}) {
    final stepsToShow = isSalon ? [['placed', 'Booking Received'], ['accepted', 'Confirmed'], ['ready', 'Ready for Service'], ['delivered', 'Completed']] : _steps;
    int effectiveIndex = currentIndex;
    if (isSalon) {
      final status = stepsToShow.length > currentIndex ? stepsToShow[currentIndex][0] : 'placed';
      effectiveIndex = stepsToShow.indexWhere((s) => s[0] == status);
      if (effectiveIndex == -1) effectiveIndex = stepsToShow.length - 1;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROGRESS', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
          const SizedBox(height: 15),
          ...List.generate(stepsToShow.length, (index) {
            final isCompleted = index <= effectiveIndex;
            final isCurrent = index == effectiveIndex;
            return Row(
              children: [
                Column(children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: isCompleted ? AppColors.softGreen : Colors.grey.shade200, border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null), child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 10) : null), 
                  if (index != stepsToShow.length - 1) Container(width: 1.5, height: 18, color: isCompleted ? AppColors.softGreen : Colors.grey.shade200)
                ]),
                const SizedBox(width: 15),
                Text(stepsToShow[index][1], style: GoogleFonts.urbanist(fontSize: 13, fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600, color: isCurrent ? AppColors.charcoal : (isCompleted ? AppColors.charcoal.withValues(alpha: 0.6) : Colors.grey.shade400))),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(Map<String, dynamic> order, AsyncValue userAsync) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text('DELIVERY TO', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey))]),
          const SizedBox(height: 15),
          userAsync.when(
            data: (user) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${user?.name ?? 'Customer'} • ${user?.phone ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${order['house_number'] ?? ''}, ${order['village'] ?? ''}, ${order['landmark'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              if (order['delivery_note'] != null) ...[
                const SizedBox(height: 12),
                Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: Text('NOTE: ${order['delivery_note']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primary, fontWeight: FontWeight.bold))),
              ]
            ]),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Error loading address'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> order, {bool isSalon = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSalon ? 'SERVICE DETAILS' : 'ORDER ITEMS', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
          const SizedBox(height: 15),
          Consumer(builder: (context, ref, _) {
            final itemsAsync = ref.watch(orderItemsProvider(widget.orderId));
            return itemsAsync.when(
              data: (items) => Column(
                children: [
                  ...items.map((i) => Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)), child: Icon(isSalon ? Icons.content_cut_rounded : Icons.fastfood_outlined, size: 14, color: AppColors.primary)), const SizedBox(width: 12), Expanded(child: Text('${i['name']} x ${i['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), Text('₹${(i['subtotal'] ?? 0).toInt()}', style: const TextStyle(fontWeight: FontWeight.w900))]))),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Error loading items'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRiderCard(String riderId) {
    final riderAsync = ref.watch(specificRiderProvider(riderId));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(30)),
      child: riderAsync.when(
        data: (rider) {
          if (rider == null) return const SizedBox();
          return Row(
            children: [
              Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle), child: const CircleAvatar(radius: 24, backgroundColor: Colors.white, child: Icon(Icons.person_rounded, color: AppColors.primary))),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rider['name'] ?? 'Rider', style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)), Text('YOUR DELIVERY PARTNER', style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.5))])),
              _actionIcon(Icons.call_rounded, Colors.white, () => _makeCall(rider['phone']), isDark: true),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const SizedBox(),
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILL SUMMARY', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
          const SizedBox(height: 12),
          _priceRow('Subtotal', (order['subtotal'] ?? 0)),
          _priceRow('Delivery Fee', order['delivery_charge']),
          _priceRow('Platform Fee', order['platform_fee']),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, thickness: 0.5)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Grand Total', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 15)), Text('₹${(order['total_amount'] as num).toInt()}', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary))]),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PAYMENT', style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), Text(order['payment_method']?.toString().toUpperCase() ?? 'COD', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('STATUS', style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), Text(order['payment_status']?.toString().toUpperCase() ?? 'PENDING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: order['payment_status'] == 'paid' ? Colors.green : Colors.orange))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BusinessModel? business) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUPPORT', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat_outlined, size: 16), label: const Text('CHAT'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _makeCall(business?.ownerPhone), icon: const Icon(Icons.call_outlined, size: 16), label: const Text('CALL'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(Map<String, dynamic>? order) {
    if (order == null) return const SizedBox.shrink();
    final status = order['status'] ?? 'placed';
    final isDelivered = status == 'delivered';
    final isSalon = order['appointment_time'] != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: ElevatedButton(
        onPressed: () async {
          if (isDelivered) return;
          
          if (isSalon) {
            final business = ref.read(businessProvider(order['business_id'] ?? '')).value;
            final addr = business?.address ?? '';
            final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
            if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullMapTrackingScreen(
                  orderId: widget.orderId,
                  customerLoc: _customerLocation!,
                  restaurantLoc: _restaurantLocation,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isDelivered ? (isSalon ? 'RATE EXPERIENCE' : 'RATE ORDER') : (isSalon ? 'NAVIGATE TO SHOP' : 'VIEW TRACKING'), style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(width: 10),
            Icon(isDelivered ? Icons.star_outline_rounded : Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, dynamic value, {bool isDiscount = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)), Text('${isDiscount ? "-" : ""}₹${(value ?? 0).toInt()}', style: TextStyle(fontSize: 13, color: isDiscount ? Colors.green : AppColors.charcoal, fontWeight: FontWeight.w800))]));
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap, {bool isDark = false}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(50), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isDark ? Colors.white24 : color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)));
  }

  Widget _mapFab(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}
