import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/order_provider.dart';
import '../providers/business_provider.dart';
import '../providers/cart_provider.dart';
import '../data/food_item_model.dart';
import '../data/review_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../invoices/data/invoice_model.dart';
import '../../invoices/presentation/customer_invoice_screen.dart';
import '../../../core/theme/app_theme.dart';
import 'order_tracking_screen.dart';
import 'cart_screen.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Active',
    'Appointments',
    'History',
  ];

  String _statusLabel(String status) {
    switch (status) {
      case 'placed': return 'অর্ডার হয়েছে';
      case 'accepted': return 'গৃহীত';
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
      case 'out_for_delivery': return const Color(0xFFF45D27);
      case 'delivered': return Colors.green;
      case 'cancelled':
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  bool _matchesFilter(Map<String, dynamic> order) {
    final status = order['status'] ?? 'placed';
    if (_selectedFilter == 'All') return true;
    
    final isActive = ['placed', 'accepted', 'preparing', 'ready', 'rider_assigned', 'picked_up', 'out_for_delivery'].contains(status);
    final isAppointment = order['appointment_time'] != null;

    if (_selectedFilter == 'Active') return isActive;
    if (_selectedFilter == 'Appointments') return isAppointment;
    if (_selectedFilter == 'History') return !isActive;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Column(
        children: [
          // 1. Restore Premium Gradient Header
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
            child: Row(
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
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Track all your orders',
                      style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
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
                  ),
                );
              },
            ),
          ),

          // 3. Orders List
          Expanded(
            child: ordersAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF45D27))),
              error: (e, stack) => Center(child: Text('Error loading orders: $e')),
              data: (orders) {
                final filteredOrders = orders.where((o) => _matchesFilter(o)).toList();
                if (filteredOrders.isEmpty) {
                  return Center(child: Text('No orders found', style: GoogleFonts.urbanist(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length + 1, // +1 for Bottom Spacing
                  itemBuilder: (context, index) {
                    if (index == filteredOrders.length) {
                      return const SizedBox(height: 100); // 4. Bottom space for navigation bar
                    }
                    return _OrderCardRestored(
                      order: filteredOrders[index],
                      statusLabel: _statusLabel(filteredOrders[index]['status'] ?? 'placed'),
                      statusColor: _statusColor(filteredOrders[index]['status'] ?? 'placed'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCardRestored extends ConsumerWidget {
  final Map<String, dynamic> order;
  final String statusLabel;
  final Color statusColor;

  const _OrderCardRestored({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
  });

  void _showReviewDialog(BuildContext context, WidgetRef ref, String orderId, String businessId) async {
    final orderItems = await ref.read(orderRepositoryProvider).getOrderItems(orderId);
    if (orderItems.isEmpty) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _ReviewDialog(
        orderId: orderId,
        items: orderItems,
      ),
    );
  }

  void _handleReOrder(BuildContext context, WidgetRef ref, String orderId, String businessId) async {
    final orderItems = await ref.read(orderRepositoryProvider).getOrderItems(orderId);
    if (orderItems.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অর্ডারের আইটেম পাওয়া যায়নি')));
      }
      return;
    }

    final cartNotifier = ref.read(cartProvider.notifier);
    final currentCart = ref.read(cartProvider);

    // Check if cart has items from another business
    if (currentCart.isNotEmpty && cartNotifier.restaurantId != null && cartNotifier.restaurantId != businessId) {
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('অন্য দোকানের কার্ট খালি করবেন?', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
          content: Text('কার্টে অন্য প্রতিষ্ঠানের খাবার রয়েছে। রি-অর্ডার করতে কার্ট খালি করা হবে।', style: GoogleFonts.urbanist(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('হ্যাঁ, খালি করুন'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      cartNotifier.clear();
    }

    // Add items to cart
    for (var item in orderItems) {
      final foodItem = FoodItemModel(
        id: item['item_id']?.toString() ?? '',
        restaurantId: businessId,
        name: item['name']?.toString() ?? 'Food Item',
        description: '',
        category: 'food',
        isVeg: true,
        price: ((item['price'] ?? 0) as num).toDouble(),
        discountPrice: 0.0,
        stock: 100,
        isAvailable: true,
        avgRating: 4.5,
      );
      final qty = ((item['quantity'] ?? 1) as num).toInt();
      for (int i = 0; i < qty; i++) {
        cartNotifier.addItem(foodItem);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('খাবারগুলো সফলভাবে কার্টে যোগ করা হয়েছে! 🛒'), backgroundColor: Colors.green),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderId = order['orderId'].toString();
    final businessId = order['business_id'] ?? '';
    final businessAsync = ref.watch(businessProvider(businessId));
    final total = (order['total_amount'] ?? 0).toDouble();
    final isAppointment = order['appointment_time'] != null;
    final status = order['status'] ?? 'placed';
    
    final timeStr = order['placed_at'] != null 
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(order['placed_at'])) 
        : 'Recent';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Store Logo
                  businessAsync.when(
                    data: (b) => Container(
                      width: 65, height: 65,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.grey.shade50),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: b?.logoUrl != null
                            ? CachedNetworkImage(imageUrl: b!.logoUrl!, fit: BoxFit.cover)
                            : const Icon(Icons.storefront_rounded, color: Color(0xFFF45D27), size: 30),
                      ),
                    ),
                    loading: () => Container(width: 65, height: 65, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15))),
                    error: (_, _) => Container(width: 65, height: 65, color: Colors.grey.shade50),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: businessAsync.when(
                                data: (b) => Text(
                                  b?.name ?? 'Store Name',
                                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.charcoal),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                loading: () => Container(width: 80, height: 14, color: Colors.grey.shade50),
                                error: (_, _) => const Text('Unknown Store'),
                              ),
                            ),
                            // 5. Category Indicator (Food/Appointment/etc)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                isAppointment ? 'APPOINTMENT' : 'DELIVERY',
                                style: GoogleFonts.urbanist(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('ID: #${orderId.substring(0, 8).toUpperCase()}', style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(isAppointment ? 'Slot: ${order['appointment_time']}' : timeStr, style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('₹${total.toInt()}', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.charcoal)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.urbanist(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _handleReOrder(context, ref, orderId, businessId),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('RE-ORDER', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.softGreen),
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey.shade200),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final items = await ref.read(orderRepositoryProvider).getOrderItems(orderId);
                        if (!context.mounted) return;
                        final invoice = InvoiceModel.fromOrderMap(
                          order,
                          fetchedItems: items,
                          user: ref.read(currentUserProvider).value != null 
                              ? {'name': ref.read(currentUserProvider).value?.name, 'phone': ref.read(currentUserProvider).value?.phone}
                              : null,
                          merchant: businessAsync.value != null 
                              ? {'name': businessAsync.value?.name, 'address': businessAsync.value?.address}
                              : null,
                        );
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerInvoiceScreen(invoice: invoice)));
                      },
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: Text('INVOICE', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ),
                  if (status == 'delivered') ...[
                    Container(width: 1, height: 20, color: Colors.grey.shade200),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _showReviewDialog(context, ref, orderId, businessId),
                        icon: const Icon(Icons.star_outline_rounded, size: 16),
                        label: Text('REVIEW', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFF45D27)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  final String orderId;
  final List<Map<String, dynamic>> items;

  const _ReviewDialog({required this.orderId, required this.items});

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final Map<String, double> _ratings = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _hasReviewedMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final repo = ref.read(reviewRepositoryProvider);
      for (var item in widget.items) {
        final itemId = item['item_id'].toString();
        _ratings[itemId] = 5.0;
        _controllers[itemId] = TextEditingController();
        // Check if reviewed, wrap in try-catch to avoid hanging on DB errors
        try {
          final reviewed = await repo.hasReviewed(widget.orderId, itemId);
          _hasReviewedMap[itemId] = reviewed;
        } catch (e) {
          _hasReviewedMap[itemId] = false;
        }
      }
    } catch (e) {
      debugPrint('Error initializing review data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submitReview(String itemId, String itemName) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(reviewRepositoryProvider);
      final review = ReviewModel(
        id: '',
        itemId: itemId,
        userId: user.uid,
        orderId: widget.orderId,
        userName: user.name ?? 'Customer',
        rating: _ratings[itemId] ?? 5.0,
        comment: _controllers[itemId]?.text.trim() ?? '',
        timestamp: DateTime.now(),
      );

      await repo.addReview(review);
      
      if (mounted) {
        setState(() {
          _hasReviewedMap[itemId] = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$itemName-এর রিভিউ সফলভাবে জমা দেওয়া হয়েছে!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('রিভিউ দিন', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.charcoal)),
          Text('আপনার অভিজ্ঞতা শেয়ার করুন', style: GoogleFonts.hindSiliguri(fontSize: 14, color: AppColors.muted)),
        ],
      ),
      content: _isLoading && _hasReviewedMap.isEmpty
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final itemId = item['item_id'].toString();
              final itemName = item['name'] ?? 'Item';
              final alreadyReviewed = _hasReviewedMap[itemId] ?? false;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(itemName, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.charcoal)),
                      ),
                      if (alreadyReviewed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('রিভিউ করা হয়েছে', style: GoogleFonts.hindSiliguri(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (!alreadyReviewed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _ratings[itemId] = i + 1.0),
                        child: Icon(
                          i < (_ratings[itemId] ?? 5.0) ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppColors.gold,
                          size: 32,
                        ),
                      )),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controllers[itemId],
                      style: GoogleFonts.hindSiliguri(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'আপনার মন্তব্য লিখুন...',
                        hintStyle: GoogleFonts.hindSiliguri(fontSize: 13, color: Colors.grey),
                        fillColor: Colors.grey.shade50,
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _submitReview(itemId, itemName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('জমা দিন', style: GoogleFonts.hindSiliguri(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('বন্ধ করুন', style: GoogleFonts.hindSiliguri(color: Colors.grey, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
