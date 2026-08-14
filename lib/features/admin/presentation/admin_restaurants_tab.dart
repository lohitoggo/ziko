import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';

class AdminRestaurantsTab extends ConsumerWidget {
  const AdminRestaurantsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(allRestaurantsProvider);
    final repo = ref.read(adminRepositoryProvider);

    return restaurantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('সমস্যা: $e')),
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return const Center(child: Text('এখনো কোনো রেস্টুরেন্ট নেই'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: restaurants.length,
          itemBuilder: (context, index) {
            final r = restaurants[index];
            final status = r['status'] ?? 'pending';
            final isOnline = r['isOnline'] ?? false;
            final category = r['category'] ?? 'restaurant';
            final restaurantId = r['restaurantId'];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(r['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r['address'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status == 'approved'
                                ? Colors.green.withValues(alpha: 0.1)
                                : status == 'suspended'
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status == 'approved'
                                ? 'অনুমোদিত'
                                : status == 'suspended'
                                ? 'স্থগিত'
                                : 'অপেক্ষমান',
                            style: TextStyle(
                              fontSize: 12,
                              color: status == 'approved'
                                  ? Colors.green
                                  : status == 'suspended'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(isOnline ? '🟢 অনলাইন' : '🔴 অফলাইন',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (status != 'approved')
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => repo.updateRestaurantStatus(
                                  restaurantId, 'approved'),
                              child: const Text('অনুমোদন দিন'),
                            ),
                          ),
                        if (status == 'approved') ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => repo
                                  .forceRestaurantOnlineOffline(
                                  restaurantId, !isOnline),
                              child: Text(isOnline
                                  ? 'জোরপূর্বক অফলাইন করুন'
                                  : 'অনলাইন করুন'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red),
                              onPressed: () => repo.updateRestaurantStatus(
                                  restaurantId, 'suspended'),
                              child: const Text('স্থগিত করুন'),
                            ),
                          ),
                        ],
                      ],
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
