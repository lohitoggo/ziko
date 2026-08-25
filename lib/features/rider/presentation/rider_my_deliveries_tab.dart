import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/rider_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/location/location_service.dart';
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
      await NavigationService.launchExternalNavigation(lat, lon);
    } else {
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
                            error: (_, _) => const Text('Error'),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(color: AppColors.softGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    // Pickup Info (Restaurant)
                    businessAsync.when(
                      data: (b) => _ContactCard(
                        title: 'দোকান (Pickup)',
                        name: b?.name ?? 'দোকান',
                        address: b?.address ?? 'ঠিকানা পাওয়া যায়নি',
                        onCall: () => _makeCall(b?.ownerPhone),
                        onMap: () => _openMap({'address': b?.address}),
                        icon: Icons.storefront,
                      ),
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                      error: (_, _) => const Padding(padding: EdgeInsets.all(16), child: Text('দোকান তথ্য লোড করা যায়নি')),
                    ),

                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Customer Info (Delivery)
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
                      error: (_, _) => const Padding(padding: EdgeInsets.all(16), child: Text('কাস্টমার তথ্য লোড করা যায়নি')),
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
                              onPressed: () async {
                                final nextStatus = _nextStatus(status);
                                
                                if (nextStatus == 'picked_up') {
                                  // PRE-PICKUP SAFETY CHECK
                                  final hasPermission = await LocationService.ensureRiderTrackingPermission();
                                  if (!hasPermission) {
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          title: const Row(
                                            children: [
                                              Icon(Icons.location_off_rounded, color: Colors.red),
                                              SizedBox(width: 10),
                                              Text('লোকেশন অন নেই!'),
                                            ],
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('ডেলিভারি ট্র্যাকিংয়ের জন্য আপনাকে নিচের ২ টি কাজ অবশ্যই করতে হবে:'),
                                              const SizedBox(height: 16),
                                              _buildStepItem(Icons.gps_fixed, '১. ফোনের GPS/Location সার্ভিস অন করুন'),
                                              const SizedBox(height: 12),
                                              _buildStepItem(Icons.security, '২. অ্যাপের লোকেশন পারমিশন "Allow" করুন'),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'এই দুটি অন না থাকলে আপনি অর্ডার পিকআপ করতে পারবেন না।',
                                                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                Geolocator.openLocationSettings();
                                                Geolocator.openAppSettings();
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                              child: const Text('সেটিংস ঠিক করুন'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }

                                repo.updateDeliveryStatus(orderId, nextStatus);
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

  Widget _buildStepItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ],
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
