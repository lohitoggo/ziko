import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/order_provider.dart';
import '../../rider/providers/rider_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Accepted',
    'Preparing',
    'On The Way',
    'Delivered',
    'Cancelled'
  ];

  String _statusLabel(String status) {
    switch (status) {
      case 'placed': return 'অর্ডার হয়েছে';
      case 'accepted': return 'গ্রহণ করা হয়েছে';
      case 'preparing': return 'তৈরি হচ্ছে';
      case 'ready': return 'প্রস্তুত';
      case 'rider_assigned': return 'রাইডার নির্ধারিত';
      case 'picked_up': return 'পিকআপ হয়েছে';
      case 'out_for_delivery': return 'ডেলিভারির পথে';
      case 'delivered': return 'ডেলিভার হয়েছে';
      case 'cancelled':
      case 'rejected': return 'বাতিল হয়েছে';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'placed': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'preparing': return Colors.purple;
      case 'ready':
      case 'rider_assigned':
      case 'picked_up':
      case 'out_for_delivery': return Colors.green;
      case 'delivered': return AppColors.softGreen;
      case 'cancelled':
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  bool _matchesFilter(String status) {
    if (_selectedFilter == 'All') return true;
    if (_selectedFilter == 'Pending' && status == 'placed') return true;
    if (_selectedFilter == 'Accepted' && status == 'accepted') return true;
    if (_selectedFilter == 'Preparing' && status == 'preparing') return true;
    if (_selectedFilter == 'On The Way' && (status == 'picked_up' || status == 'out_for_delivery' || status == 'ready')) return true;
    if (_selectedFilter == 'Delivered' && status == 'delivered') return true;
    if (_selectedFilter == 'Cancelled' && (status == 'cancelled' || status == 'rejected')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Column(
        children: [
          // 1. Premium Gradient Header
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 16, right: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Orders',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Track all your orders',
                          style: GoogleFonts.urbanist(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Filter Chips
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedFilter = filter),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFF45D27),
                    labelStyle: GoogleFonts.urbanist(
                      color: isSelected ? Colors.white : AppColors.charcoal,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                    ),
                    showCheckmark: false,
                    elevation: 0,
                    pressElevation: 2,
                  ),
                );
              },
            ),
          ),

          // 3. Orders List
          Expanded(
            child: ordersAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) {
                if (ordersAsync.hasValue) return _buildOrdersList(ordersAsync.value!);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text('Connecting...', style: GoogleFonts.urbanist(color: Colors.grey)),
                    ],
                  ),
                );
              },
              data: (orders) => _buildOrdersList(orders),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
    final filteredOrders = orders.where((o) => _matchesFilter(o['status'] ?? 'placed')).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.muted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        final status = order['status'] ?? 'placed';
        final orderId = order['orderId'].toString();
        final isSalon = order['appointment_time'] != null;
        final total = (order['total_amount'] ?? 0).toDouble();
        final timeStr = order['placed_at'] != null 
            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['placed_at'])) 
            : 'Unknown Date';
        
        return _OrderCard(
          orderId: orderId,
          status: status,
          total: total,
          timeStr: isSalon ? 'Slot: ${order['appointment_time']}' : timeStr,
          businessId: order['business_id'] ?? '',
          statusLabel: _statusLabel(status),
          statusColor: _statusColor(status),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final String orderId;
  final String status;
  final double total;
  final String timeStr;
  final String businessId;
  final String statusLabel;
  final Color statusColor;

  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.total,
    required this.timeStr,
    required this.businessId,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(businessProvider(businessId));

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(orderId: orderId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Store Logo
                businessAsync.when(
                  data: (b) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: b?.logoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: b!.logoUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: Colors.grey.shade100),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
                          ),
                  ),
                  loading: () => Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14))),
                  error: (_, __) => Container(width: 60, height: 60, color: Colors.grey.shade100),
                ),
                const SizedBox(width: 14),

                // Order Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      businessAsync.when(
                        data: (b) => Text(
                          b?.name ?? 'Store Name',
                          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.charcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        loading: () => Container(width: 100, height: 14, color: Colors.grey.shade100),
                        error: (_, __) => const Text('Unknown Store'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: #${orderId.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${total.toInt()}',
                            style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.charcoal),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'delivered' ? statusColor : statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.urbanist(
                                color: status == 'delivered' ? Colors.white : statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
