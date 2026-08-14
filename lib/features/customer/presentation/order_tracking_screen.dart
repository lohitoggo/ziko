import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/location/route_service.dart';
import '../../auth/providers/user_provider.dart';
import '../../rider/data/tracking/tracking_repository.dart';
import '../../rider/providers/rider_provider.dart';
import '../providers/order_provider.dart';
import '../data/business_model.dart';

import 'package:qr_flutter/qr_flutter.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  final TrackingRepository _trackingRepo = TrackingRepository();

  List<LatLng> _polylinePoints = [];
  LatLng? _riderLocation;
  LatLng? _customerLocation;
  double _distanceInKm = 0.0;

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  String _getEta(double km) {
    if (km < 0.1) return 'Arriving now';
    // Assume 20km/h average speed including traffic
    final mins = (km / 20 * 60).ceil() + 2;
    return '$mins mins';
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

  String _getFormattedStatus(String status, {bool isSalon = false}) {
    if (isSalon) {
      switch (status) {
        case 'placed': return 'Booking Received';
        case 'accepted': return 'Booking Confirmed';
        case 'ready': return 'Ready for Service';
        case 'delivered': return 'Service Completed';
        default: return 'Confirmed';
      }
    }
    switch (status) {
      case 'placed': return 'Order Placed';
      case 'accepted': return 'Store Accepted';
      case 'preparing': return 'Chef is Cooking';
      case 'ready': return 'Rider Assigned';
      case 'picked_up': return 'Order Picked Up';
      case 'out_for_delivery': return 'On The Way';
      case 'delivered': return 'Delivered';
      default: return 'Processing';
    }
  }

  Future<void> _updateRoute() async {
    if (_riderLocation != null && _customerLocation != null) {
      final points = await RouteService.getRoute(start: _riderLocation!, end: _customerLocation!);
      if (mounted) setState(() => _polylinePoints = points);
    }
  }

  void _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(singleOrderProvider(widget.orderId));
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: orderAsync.when(
        data: (order) {
          if (order == null) return const Center(child: Text('Order not found'));

          final status = order['status'] ?? 'placed';
          final riderId = order['rider_id'];
          final businessId = order['business_id'];
          final businessAsync = ref.watch(businessProvider(businessId ?? ''));

          return businessAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (business) {
              final isSalon = business?.category == 'salon';
              final currentIndex = _currentStepIndex(status);
              _customerLocation = LatLng(order['customer_lat'] ?? 22.5726, order['customer_lon'] ?? 88.3639);

              return Column(
                children: [
                  // 1. Header
                  Container(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 16, right: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF45D27), Color(0xFFFF8A00)]),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isSalon ? 'Booking Status' : 'Order Status', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            Text('ID: #${widget.orderId.substring(0, 8).toUpperCase()}', style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            children: [
                              if (isSalon) _buildSalonPass(order, business, status) else _buildMapSection(order, status),
                              _buildTimelineCard(currentIndex, isSalon: isSalon),
                              if (!isSalon) _buildDeliveryAddressCard(order, userAsync),
                              _buildItemsCard(order, isSalon: isSalon),
                              if (!isSalon && riderId != null) _buildRiderCard(riderId),
                              _buildPaymentCard(order),
                              _buildSupportCard(business),
                            ],
                          ),
                        ),
                        _buildBottomAction(status, isSalon: isSalon, business: business),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildMapSection(Map<String, dynamic> order, String status) {
    return Container(
      height: 240, margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))], border: Border.all(color: Colors.white, width: 4)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _customerLocation!, initialZoom: 14),
              children: [
                TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.ziko.app'),
                if (_polylinePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _polylinePoints, color: AppColors.primary, strokeWidth: 5)]),
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _trackingRepo.watchRiderLocation(widget.orderId),
                  builder: (context, snapshot) {
                    final List<Marker> markers = [];
                    markers.add(Marker(point: _customerLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.blue, size: 35)));

                    if (snapshot.hasData && snapshot.data != null) {
                      final lat = snapshot.data!['latitude'] as double;
                      final lon = snapshot.data!['longitude'] as double;
                      final newPos = LatLng(lat, lon);

                      // Update local distance for UI
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          final dist = _calculateDistance(lat, lon, _customerLocation!.latitude, _customerLocation!.longitude);
                          if (dist != _distanceInKm) {
                            setState(() {
                              _distanceInKm = dist;
                              _riderLocation = newPos;
                            });
                            _updateRoute();
                          }
                        }
                      });

                      return TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 5), // Smooth interpolation
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, _) {
                          // Rough interpolation logic
                          final currentLat = (_riderLocation?.latitude ?? lat) + (lat - (_riderLocation?.latitude ?? lat)) * value;
                          final currentLon = (_riderLocation?.longitude ?? lon) + (lon - (_riderLocation?.longitude ?? lon)) * value;

                          return MarkerLayer(
                            markers: [
                              markers[0],
                              Marker(
                                point: LatLng(currentLat, currentLon),
                                width: 55, height: 55,
                                child: _buildRiderMarkerIcon(),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    return MarkerLayer(markers: markers);
                  },
                ),
              ],
            ),
            Positioned(
              top: 12, left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Current Status', style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(_getFormattedStatus(status), style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_distanceInKm > 0 ? '${_distanceInKm.toStringAsFixed(1)} km away' : 'Est. Delivery', style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(_distanceInKm > 0 ? _getEta(_distanceInKm) : '25-30 mins', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w800))
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonPass(Map<String, dynamic> order, BusinessModel? business, String status) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Appointment Status', style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(_getFormattedStatus(status, isSalon: true), style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary))]),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))), child: Text('CONFIRMED', style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(15), child: business?.logoUrl != null ? Image.network(business!.logoUrl!, width: 60, height: 60, fit: BoxFit.cover) : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.storefront, color: Colors.grey))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(business?.name ?? 'Salon Name', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w800)), Text(business?.address ?? 'Store Address', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)]))
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: Colors.black12)),
                Row(
                  children: [
                    Expanded(child: _passInfo(Icons.calendar_today_rounded, 'Date', order['appointment_time']?.toString().split(' | ').first ?? 'N/A')),
                    Container(width: 1, height: 40, color: Colors.black12),
                    Expanded(child: _passInfo(Icons.access_time_rounded, 'Arrival Time', order['appointment_time']?.toString().split('|').last.split(',').first.trim() ?? 'N/A')),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(onPressed: () async {
                      final addr = business?.address ?? '';
                      final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
                      if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                    }, icon: const Icon(Icons.directions_rounded, size: 18), label: const Text('GET DIRECTIONS'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 12), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    _passAction(Icons.call_rounded, Colors.green, () => _makeCall(business?.ownerPhone)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: QrImageView(
                    data: widget.orderId,
                    version: QrVersions.auto,
                    size: 140.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.charcoal),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SCAN AT STORE TO COMPLETE',
                  style: GoogleFonts.urbanist(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1
                  )
                )
              ]
            )
          ),
        ],
      ),
    );
  }

  Widget _passInfo(IconData icon, String label, String value) {
    return Column(children: [Icon(icon, size: 16, color: AppColors.primary), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w800))]);
  }

  Widget _passAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.2))), child: Icon(icon, color: color, size: 22)));
  }

  Widget _buildTimelineCard(int currentIndex, {bool isSalon = false}) {
    final stepsToShow = isSalon ? [['placed', 'Booking Received'], ['accepted', 'Booking Confirmed'], ['ready', 'Ready for Service'], ['delivered', 'Service Completed']] : _steps;
    int effectiveIndex = currentIndex;
    if (isSalon) {
      final status = stepsToShow.length > currentIndex ? stepsToShow[currentIndex][0] : 'placed';
      effectiveIndex = stepsToShow.indexWhere((s) => s[0] == status);
      if (effectiveIndex == -1) effectiveIndex = stepsToShow.length - 1;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSalon ? 'Booking Progress' : 'Order Progress', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 20),
          ...List.generate(stepsToShow.length, (index) {
            final isCompleted = index <= effectiveIndex;
            final isCurrent = index == effectiveIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Column(children: [Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: isCompleted ? AppColors.softGreen : Colors.grey.shade200, border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null), child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 12) : null), if (index != stepsToShow.length - 1) Container(width: 2, height: 20, color: isCompleted ? AppColors.softGreen : Colors.grey.shade200)]),
                  const SizedBox(width: 16),
                  Text(stepsToShow[index][1], style: GoogleFonts.urbanist(fontSize: 14, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500, color: isCurrent ? AppColors.charcoal : (isCompleted ? AppColors.charcoal.withValues(alpha: 0.6) : Colors.grey))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(Map<String, dynamic> order, AsyncValue userAsync) {
    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20), const SizedBox(width: 8), Text('Delivery Address', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16))]),
          const SizedBox(height: 15),
          userAsync.when(
            data: (user) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?.name ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(user?.phone ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 10), Text('Village: ${order['village'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)), Text('House No: ${order['house_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)), Text('Landmark: ${order['landmark'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)), if (order['delivery_note'] != null) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)), child: Text('Note: ${order['delivery_note']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)))]]),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Failed to load user info'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> order, {bool isSalon = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSalon ? 'Service Details' : 'Order Items', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 15),
          Consumer(builder: (context, ref, _) {
            final itemsAsync = ref.watch(orderItemsProvider(widget.orderId));
            return itemsAsync.when(
              data: (items) => Column(
                children: [
                  ...items.map((i) => Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [Container(width: 35, height: 35, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(isSalon ? Icons.content_cut_rounded : Icons.fastfood_outlined, size: 18, color: Colors.grey)), const SizedBox(width: 12), Expanded(child: Text('${i['name']} x ${i['quantity']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('₹${(i['subtotal'] ?? 0).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))]))),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                  _priceRow('Subtotal', order['subtotal'] ?? 0),
                  if (!isSalon) _priceRow('Delivery Charge', order['delivery_charge'] ?? 0),
                  _priceRow('Platform Fee', order['platform_fee'] ?? 0),
                  _priceRow('Discount', 0, isDiscount: true),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Grand Total', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 16)), Text('₹${(order['total_amount'] ?? 0).toInt()}', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary))]),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading items'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRiderCard(String riderId) {
    final riderAsync = ref.watch(specificRiderProvider(riderId));
    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: riderAsync.when(
        data: (rider) {
          if (rider == null) return const SizedBox();
          return Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.person_rounded, color: AppColors.primary)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rider['name'] ?? 'Rider Assigned', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.bold)), Text('${rider['vehicle_type']?.toString().toUpperCase() ?? 'Bike'} • 4.8 ★', style: const TextStyle(fontSize: 12, color: Colors.grey))])),
              _actionIcon(Icons.call_rounded, Colors.green, () => _makeCall(rider['phone'])),
              const SizedBox(width: 10),
              _actionIcon(Icons.chat_bubble_rounded, Colors.blue, () {}),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Details', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          _readOnlyRow('Method', order['payment_method']?.toString().toUpperCase() ?? 'N/A'),
          _readOnlyRow('Status', order['payment_status']?.toString().toUpperCase() ?? 'PENDING'),
          if (order['payment_id'] != null) _readOnlyRow('Transaction ID', order['payment_id'].toString()),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BusinessModel? business) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Need Help?', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('Chat Support'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _makeCall(business?.ownerPhone), icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call Shop'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(String status, {bool isSalon = false, BusinessModel? business}) {
    final isDelivered = status == 'delivered';
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () async {
              if (isSalon && !isDelivered) {
                final addr = business?.address ?? '';
                final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
                if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
              }
            },
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(isDelivered ? (isSalon ? 'RATE SERVICE' : 'RATE ORDER') : (isSalon ? 'GET DIRECTIONS TO SHOP' : 'TRACK RIDER ON MAP'), style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, dynamic value, {bool isDiscount = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)), Text('${isDiscount ? "-" : ""}₹${(value ?? 0).toInt()}', style: TextStyle(fontSize: 13, color: isDiscount ? Colors.green : AppColors.charcoal, fontWeight: FontWeight.bold))]));
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(50), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)));
  }

  Widget _buildRiderMarkerIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]
          ),
          child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 26),
        ),
        Positioned(
          top: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Text('z', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
