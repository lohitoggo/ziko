import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rider_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class RiderEarningsTab extends ConsumerWidget {
  const RiderEarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(myCompletedDeliveriesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: completedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('সমস্যা: $e')),
        data: (orders) {
          final totalEarnings = orders.fold<double>(
            0,
            (sum, o) => sum + ((o['delivery_charge'] ?? 0).toDouble()),
          );

          final now = DateTime.now();
          final todayEarnings = orders.where((o) {
            final deliveredAtStr = o['delivered_at'] as String?;
            if (deliveredAtStr == null) return false;
            final deliveredAt = DateTime.tryParse(deliveredAtStr);
            if (deliveredAt == null) return false;
            return deliveredAt.day == now.day && 
                   deliveredAt.month == now.month && 
                   deliveredAt.year == now.year;
          }).fold<double>(0, (sum, o) => sum + ((o['delivery_charge'] ?? 0).toDouble()));

          return Column(
            children: [
              // Earnings Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    const Text('মোট উপার্জন', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('₹${totalEarnings.toInt()}', 
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SmallStat(label: 'আজকের আয়', value: '₹${todayEarnings.toInt()}'),
                        Container(width: 1, height: 30, color: Colors.white24),
                        _SmallStat(label: 'মোট ডেলিভারি', value: '${orders.length}'),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Deliveries List
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('এখনো কোনো ডেলিভারি সম্পন্ন হয়নি', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final o = orders[index];
                          final charge = (o['delivery_charge'] ?? 0).toDouble();
                          final deliveredAtStr = o['delivered_at'] as String?;
                          final deliveredAt = deliveredAtStr != null 
                              ? DateTime.tryParse(deliveredAtStr) ?? DateTime.now()
                              : DateTime.now();
                          final dateStr = DateFormat('dd MMM, hh:mm a').format(deliveredAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.softGreen.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: AppColors.softGreen, size: 18),
                              ),
                              title: Text('অর্ডার #${o['orderId'].toString().substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                              trailing: Text('+₹${charge.toInt()}',
                                  style: const TextStyle(color: AppColors.softGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
