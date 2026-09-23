import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'order_tracking_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  static const String currentAppVersion = '1.0.2';

  const NotificationsScreen({super.key});

  Future<void> _launchUpdateUrl(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString.isNotEmpty ? urlString : 'https://zikoapp.online');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open update link: $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching update: $e')),
        );
      }
    }
  }

  bool _isUpdateAvailable(String? latestVersion) {
    if (latestVersion == null || latestVersion.trim().isEmpty) return false;
    final trimmedLatest = latestVersion.trim();
    if (trimmedLatest == currentAppVersion) return false;

    try {
      final currentParts = currentAppVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = trimmedLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(systemSettingsProvider);
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, color: AppColors.charcoal),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error loading notifications: $e')),
        data: (settings) {
          final latestVersion = settings?['latest_app_version'] ?? settings?['latestAppVersion'] ?? currentAppVersion;
          final updateUrl = settings?['app_update_url'] ?? settings?['updateUrl'] ?? 'https://zikoapp.online';
          final updateNotes = settings?['app_update_notes'] ?? 'A new version with performance improvements and new features is available.';
          final hasUpdate = _isUpdateAvailable(latestVersion);

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // 1. APP UPDATE NOTIFICATION CARD (Only shown if a newer version is available)
              if (hasUpdate) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6448FE).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'App Update Available! 🚀',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Version $latestVersion is now ready',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        updateNotes,
                        style: GoogleFonts.urbanist(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchUpdateUrl(context, updateUrl),
                          icon: const Icon(Icons.download_rounded, color: Color(0xFF6448FE)),
                          label: Text(
                            'UPDATE NOW',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: const Color(0xFF6448FE),
                              letterSpacing: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. LIVE ORDERS / APPOINTMENT NOTIFICATIONS
              Text(
                'Recent Updates & Alerts',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 12),

              ordersAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading orders: $e'),
                data: (orders) {
                  if (orders.isEmpty && !hasUpdate) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: GoogleFonts.urbanist(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final status = order['status'] ?? 'placed';
                      final orderId = order['orderId'].toString();
                      final isAppointment = order['appointment_time'] != null;
                      final dateStr = order['placed_at'] != null 
                          ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(order['placed_at']))
                          : 'Recent';

                      final String notifTitle = _getNotificationTitle(status, isAppointment);
                      final String notifBody = _getNotificationBody(status, orderId, isAppointment);
                      final IconData notifIcon = _getNotificationIcon(status);
                      final Color notifColor = _getNotificationColor(status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: notifColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(notifIcon, color: notifColor, size: 22),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notifTitle,
                                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              notifBody,
                              style: GoogleFonts.urbanist(fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackingScreen(orderId: orderId),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _getNotificationTitle(String status, bool isAppointment) {
    if (isAppointment) {
      if (status == 'placed') return 'Appointment Booking Requested 📅';
      if (status == 'accepted') return 'Appointment Confirmed! 🎉';
      if (status == 'delivered') return 'Appointment Service Completed! ✂️';
      if (status == 'cancelled') return 'Appointment Cancelled ❌';
      return 'Appointment Updated 📅';
    }

    switch (status) {
      case 'placed': return 'Order Placed Successfully! 🛒';
      case 'accepted': return 'Order Accepted by Store! 🍳';
      case 'preparing': return 'Food / Items Being Prepared 👨‍🍳';
      case 'ready': return 'Order Ready for Pickup! 📦';
      case 'rider_assigned': return 'Rider Assigned to Your Order 🛵';
      case 'picked_up': return 'Order Picked Up! 🛵';
      case 'out_for_delivery': return 'Out for Delivery! 🛵';
      case 'delivered': return 'Order Delivered! Enjoy 😋';
      case 'cancelled':
      case 'rejected': return 'Order Cancelled ❌';
      default: return 'Order Status Updated';
    }
  }

  String _getNotificationBody(String status, String orderId, bool isAppointment) {
    final shortId = '#${orderId.substring(0, 8).toUpperCase()}';
    if (isAppointment) {
      return 'Booking $shortId status is now $status. Tap to view appointment details.';
    }
    return 'Your order $shortId status is currently: ${status.replaceAll('_', ' ')}. Tap to track.';
  }

  IconData _getNotificationIcon(String status) {
    switch (status) {
      case 'placed': return Icons.shopping_bag_outlined;
      case 'accepted': return Icons.thumb_up_outlined;
      case 'preparing': return Icons.soup_kitchen_outlined;
      case 'ready': return Icons.inventory_2_outlined;
      case 'rider_assigned':
      case 'picked_up':
      case 'out_for_delivery': return Icons.delivery_dining_rounded;
      case 'delivered': return Icons.check_circle_outline_rounded;
      case 'cancelled':
      case 'rejected': return Icons.cancel_outlined;
      default: return Icons.notifications_none_rounded;
    }
  }

  Color _getNotificationColor(String status) {
    switch (status) {
      case 'placed': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'preparing': return Colors.purple;
      case 'ready':
      case 'rider_assigned':
      case 'picked_up':
      case 'out_for_delivery': return AppColors.primary;
      case 'delivered': return Colors.green;
      case 'cancelled':
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}
