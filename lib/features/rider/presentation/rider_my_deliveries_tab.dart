import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rider_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/location/navigation_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderMyDeliveriesTab extends ConsumerWidget {
  const RiderMyDeliveriesTab({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case 'rider_assigned':
        return 'দোকানে যান';
      case 'picked_up':
        return 'সংগ্রহ করা হয়েছে';
      case 'out_for_delivery':
        return 'ডেলিভারির পথে';
      default:
        return status;
    }
  }

  String _nextAction(String status) {
    switch (status) {
      case 'rider_assigned':
        return 'দোকান থেকে আইটেম নিয়েছি';
      case 'picked_up':
        return 'কাস্টমারের উদ্দেশ্যে রওনা হলাম';
      case 'out_for_delivery':
        return 'ডেলিভারি সম্পন্ন করেছি';
      default:
        return '';
    }
  }

  String _nextStatus(String status) {
    switch (status) {
      case 'rider_assigned':
        return 'picked_up';
      case 'picked_up':
        return 'out_for_delivery';
      case 'out_for_delivery':
        return 'delivered';
      default:
        return status;
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openMap(Map<String, dynamic> order) async {
    final lat = order['customer_lat'] as double?;
    final lon = order['customer_lon'] as double?;

    if (lat != null && lon != null) {
      // Professional way: Navigate using external Google Maps with Lat/Lon
      await NavigationService.launchExternalNavigation(lat, lon);
    } else {
      // Legacy Fallback: Search using address string
      final address = order['address'] as String?;
      if (address == null || address.isEmpty) return;
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(myDeliveriesProvider);
    final repo = ref.read(riderRepositoryProvider);

    return deliveriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('সমস্যা: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('এই মুহূর্তে কোনো ডেলিভারি চলছে না', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status'] ?? 'rider_assigned';
            final paymentStatus = order['payment_status'] ?? 'pending';
            final orderId = order['orderId'];
            final total = (order['total_amount'] ?? 0).toDouble();
            final commission = (order['delivery_charge'] ?? 0).toDouble();
            final paymentMethod = order['payment_method'] ?? 'cod';
            final businessId = order['business_id'] ?? '';
            final customerUid = order['customer_id'] ?? '';

            final businessAsync = ref.watch(businessProvider(businessId));
            final customerAsync = ref.watch(userDetailsProvider(customerUid));

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: #${orderId.toString().substring(0, 8).toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          businessAsync.when(
                            data: (b) => Text(b?.name ?? 'দোকান', 
                                style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                            loading: () => const SizedBox(height: 12, width: 60, child: LinearProgressIndicator()),
                            error: (_, __) => const Text('Error'),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('₹${commission.toInt()}', 
                            style: const TextStyle(color: AppColors.softGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(order['address'] ?? 'লোকেশন পাওয়া যায়নি', 
                              style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_statusLabel(status), 
                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    const Divider(height: 1),
                    
                    // Business Info
                    businessAsync.when(
                      data: (b) => _ContactCard(
                        title: 'দোকান (Pickup)',
                        name: b?.name ?? 'অজানা দোকান',
                        address: b?.address ?? 'ঠিকানা পাওয়া যায়নি',
                        onCall: () => _makeCall(null), // Need shop phone in model
                        onMap: () => _openMap({'address': b?.address}),
                        icon: Icons.storefront,
                      ),
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                      error: (_, __) => const Padding(padding: EdgeInsets.all(16), child: Text('দোকান তথ্য লোড করা যায়নি')),
                    ),

                    const Divider(height: 1),

                    // Customer Info
                    customerAsync.when(
                      data: (u) => _ContactCard(
                        title: 'কাস্টমার (Delivery)',
                        name: u?.name ?? 'কাস্টমার',
                        address: order['address'] ?? 'ঠিকানা পাওয়া যায়নি',
                        onCall: () => _makeCall(u?.phone),
                        onMap: () => _openMap(order),
                        icon: Icons.person,
                      ),
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                      error: (_, __) => const Padding(padding: EdgeInsets.all(16), child: Text('কাস্টমার তথ্য লোড করা যায়নি')),
                    ),

                    const Divider(height: 1),

                    // Payment & Action
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
                                  Text(
                                    paymentMethod == 'cod' ? '💰 কাস্টমার থেকে সংগ্রহ করুন' : '✅ অনলাইন পেইড (প্রি-পেইড)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (paymentMethod == 'cod')
                                    const Text('নগদ টাকা বুঝে নিন', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text('₹${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                repo.updateDeliveryStatus(orderId, _nextStatus(status));
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_nextAction(status), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String title;
  final String name;
  final String address;
  final VoidCallback onCall;
  final VoidCallback onMap;
  final IconData icon;

  const _ContactCard({
    required this.title,
    required this.name,
    required this.address,
    required this.onCall,
    required this.onMap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(address, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(onPressed: onCall, icon: const Icon(Icons.call, color: Colors.green, size: 20)),
              IconButton(onPressed: onMap, icon: const Icon(Icons.map, color: Colors.blue, size: 20)),
            ],
          ),
        ],
      ),
    );
  }
}
