import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/restaurant_owner_provider.dart';
import '../../customer/providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';

class RestaurantOrdersTab extends ConsumerWidget {
  final String restaurantId;
  const RestaurantOrdersTab({super.key, required this.restaurantId});

  Color _statusColor(String status) {
    switch (status) {
      case 'placed': return Colors.blue;
      case 'accepted': return Colors.orange;
      case 'preparing': return Colors.purple;
      case 'ready': return Colors.teal;
      case 'out_for_delivery': return Colors.indigo;
      case 'delivered': return AppColors.softGreen;
      case 'rejected':
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status, {bool isSalon = false}) {
    if (isSalon) {
      switch (status) {
        case 'placed': return 'নতুন বুকিং';
        case 'accepted': return 'বুকিং কনফার্ম';
        case 'ready': return 'সার্ভিসের জন্য রেডি';
        case 'delivered': return 'সার্ভিস সম্পন্ন';
        case 'rejected': return 'বাতিলকৃত';
        default: return status.toUpperCase();
      }
    }
    switch (status) {
      case 'placed': return 'নতুন অর্ডার';
      case 'accepted': return 'গৃহীত হয়েছে';
      case 'preparing': return 'প্রস্তুত হচ্ছে';
      case 'ready': return 'অর্ডার তৈরি';
      case 'out_for_delivery': return 'ডেলিভারির পথে';
      case 'delivered': return 'ডেলিভারি সম্পন্ন';
      case 'rejected': return 'বাতিলকৃত';
      case 'cancelled': return 'কাস্টমার বাতিল করেছে';
      default: return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider(restaurantId));
    final repo = ref.read(restaurantOwnerRepositoryProvider);
    final businessAsync = ref.watch(myRestaurantProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: businessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (business) {
          final isSalon = business?['category'] == 'salon';
          
          return ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('সমস্যা: $e')),
            data: (orders) {
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isSalon ? Icons.calendar_month_outlined : Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(isSalon ? 'এখনো কোনো বুকিং আসেনি' : 'এখনো কোনো অর্ডার আসেনি', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final status = order['status'] ?? 'placed';
                  final paymentStatus = order['payment_status'] ?? 'pending';
                  final orderId = order['orderId'];
                  final total = (order['total_amount'] ?? 0).toDouble();
                  final placedAtStr = order['placed_at'];
                  final placedAt = placedAtStr != null 
                      ? DateTime.tryParse(placedAtStr) ?? DateTime.now()
                      : DateTime.now();
                  final timeStr = DateFormat('hh:mm a, dd MMM').format(placedAt);
                  final appointmentTime = order['appointment_time'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: _statusColor(status).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isSalon ? 'বুকিং #${orderId.toString().substring(0, 8).toUpperCase()}' : 'অর্ডার #${orderId.toString().substring(0, 8).toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(timeStr, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _statusLabel(status, isSalon: isSalon),
                                  style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        if (isSalon && appointmentTime != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event_available, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text('বুকিং সময় (Appointment)', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  appointmentTime, 
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.charcoal),
                                ),
                              ],
                            ),
                          ),

                        const Divider(height: 1),
                        _OrderItemsList(orderId: orderId, isSalon: isSalon),
                        const Divider(height: 1),
                        
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('মোট পরিমাণ', style: TextStyle(fontWeight: FontWeight.w500)),
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (paymentStatus == 'paid' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          paymentStatus == 'paid' ? 'অনলাইন পেইড ✅' : 'নগদ সংগ্রহ (COD) 💰',
                                          style: TextStyle(
                                            color: paymentStatus == 'paid' ? Colors.green : Colors.orange.shade900,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text('₹${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildActionButtons(status, orderId, repo, context, isSalon: isSalon),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(String status, String orderId, var repo, BuildContext context, {bool isSalon = false}) {
    if (status == 'placed') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => repo.updateOrderStatus(orderId, 'rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(isSalon ? 'বুকিং বাতিল' : 'বাতিল করুন'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => repo.updateOrderStatus(orderId, 'accepted'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text(isSalon ? 'বুকিং গ্রহণ করুন' : 'অর্ডার গ্রহণ করুন'),
            ),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => repo.updateOrderStatus(orderId, isSalon ? 'ready' : 'preparing'),
          style: ElevatedButton.styleFrom(backgroundColor: isSalon ? Colors.teal : Colors.purple, padding: const EdgeInsets.symmetric(vertical: 12)),
          child: Text(isSalon ? 'সার্ভিসের জন্য রেডি করুন' : 'প্রস্তুত করা শুরু করুন'),
        ),
      );
    } else if (status == 'preparing') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => repo.updateOrderStatus(orderId, 'ready'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
          child: const Text('অর্ডার সম্পূর্ণ তৈরি (Ready)'),
        ),
      );
    } else if (status == 'ready') {
      if (isSalon) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Colors.teal, size: 20),
              SizedBox(width: 10),
              Text('কাস্টমারের QR কোড স্ক্যান করে শেষ করুন', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bike, color: Colors.blue, size: 20),
            SizedBox(width: 10),
            Text('রাইডারের জন্য অপেক্ষা করা হচ্ছে...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _OrderItemsList extends ConsumerWidget {
  final String orderId;
  final bool isSalon;
  const _OrderItemsList({required this.orderId, this.isSalon = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsProvider(orderId));

    return itemsAsync.when(
      data: (items) => Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isSalon ? 'সার্ভিস লিস্ট (${items.length})' : 'আইটেম লিস্ট (${items.length})', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: Text('${item['quantity']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w500))),
                  Text('₹${(item['subtotal'] ?? 0).toInt()}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )),
          ],
        ),
      ),
      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      error: (_, _) => const Padding(padding: EdgeInsets.all(16), child: Text('আইটেম লোড করা যায়নি')),
    );
  }
}
