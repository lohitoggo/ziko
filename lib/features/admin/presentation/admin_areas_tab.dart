import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';

class AdminAreasTab extends ConsumerWidget {
  const AdminAreasTab({super.key});

  void _showAddAreaSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existingArea}) {
    final nameCtrl = TextEditingController(text: existingArea?['name']);
    final chargeCtrl = TextEditingController(text: existingArea != null ? (existingArea['deliveryCharge'] ?? 0).toString() : '');
    final minOrderCtrl = TextEditingController(text: existingArea != null ? (existingArea['minimumOrder'] ?? 0).toString() : '');
    final timeCtrl = TextEditingController(text: existingArea != null ? (existingArea['estimatedDeliveryMinutes'] ?? 0).toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existingArea == null ? 'নতুন এলাকা যোগ করুন' : 'এলাকা এডিট করুন',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'এলাকার নাম'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chargeCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                  const InputDecoration(labelText: 'ডেলিভারি চার্জ (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrderCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                  const InputDecoration(labelText: 'ন্যূনতম অর্ডার (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'আনুমানিক ডেলিভারি সময় (মিনিট)'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final charge =
                          double.tryParse(chargeCtrl.text.trim()) ?? 0;
                      final minOrder =
                          double.tryParse(minOrderCtrl.text.trim()) ?? 0;
                      final time = int.tryParse(timeCtrl.text.trim()) ?? 0;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('এলাকার নাম দিন')),
                        );
                        return;
                      }

                      if (existingArea == null) {
                        await ref.read(adminRepositoryProvider).addArea(
                          name: name,
                          deliveryCharge: charge,
                          minimumOrder: minOrder,
                          estimatedDeliveryMinutes: time,
                        );
                      } else {
                        await ref.read(adminRepositoryProvider).updateAreaDetails(existingArea['areaId'], {
                          'name': name,
                          'deliveryCharge': charge,
                          'minimumOrder': minOrder,
                          'estimatedDeliveryMinutes': time,
                        });
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existingArea == null ? 'যোগ করুন' : 'আপডেট করুন'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(allAreasProvider);
    final repo = ref.read(adminRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAreaSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('এলাকা যোগ করুন'),
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('সমস্যা: $e')),
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(child: Text('এখনো কোনো এলাকা যোগ করা হয়নি'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final area = areas[index];
              final isActive = area['status'] == 'active';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(area['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                        onPressed: () => _showAddAreaSheet(context, ref, existingArea: area),
                      ),
                    ],
                  ),
                  subtitle: Text(
                      'চার্জ: ₹${area['delivery_charge']} • ন্যূনতম: ₹${area['min_order_amount']} • ${area['estimated_delivery_minutes']} মিনিট'),
                  trailing: Switch(
                    value: isActive,
                    onChanged: (val) =>
                        repo.toggleAreaStatus(area['areaId'], val),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}