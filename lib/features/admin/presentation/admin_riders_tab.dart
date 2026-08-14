import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';

class AdminRidersTab extends ConsumerWidget {
  const AdminRidersTab({super.key});

  void _showOnboardSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existingRider}) {
    final nameCtrl = TextEditingController(text: existingRider?['name']);
    final phoneCtrl = TextEditingController(text: existingRider?['phone']);
    final identityCtrl = TextEditingController(text: existingRider?['identityNo']);
    final bankCtrl = TextEditingController(text: existingRider?['bankDetails']);
    String vehicleType = existingRider?['vehicleType'] ?? 'bike';
    String? selectedAreaId = existingRider?['areaId'];

    final areasAsync = ref.watch(allAreasProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existingRider == null ? 'নতুন রাইডার অনবোর্ড করুন' : 'রাইডার এডিট করুন', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'রাইডারের নাম')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: vehicleType,
                        items: const [
                          DropdownMenuItem(value: 'bike', child: Text('মোটরসাইকেল')),
                          DropdownMenuItem(value: 'cycle', child: Text('সাইকেল')),
                          DropdownMenuItem(value: 'scooter', child: Text('স্কুটার')),
                        ],
                        onChanged: (val) => setModalState(() => vehicleType = val!),
                        decoration: const InputDecoration(labelText: 'গাড়ির ধরণ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: areasAsync.when(
                        data: (areas) => DropdownButtonFormField<String>(
                          value: selectedAreaId,
                          items: areas.map((a) => DropdownMenuItem(value: a['areaId'] as String, child: Text(a['name']))).toList(),
                          onChanged: (val) => setModalState(() => selectedAreaId = val),
                          decoration: const InputDecoration(labelText: 'এলাকা'),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: identityCtrl, decoration: const InputDecoration(labelText: 'আধার/এনআইডি নম্বর')),
                const SizedBox(height: 12),
                TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'ব্যাংক ডিটেইলস (Acc/UPI)')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || selectedAreaId == null || identityCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অনুগ্রহ করে সব তথ্য দিন')));
                        return;
                      }
                      
                      try {
                        if (existingRider == null) {
                          await ref.read(adminRepositoryProvider).onboardRider(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            areaId: selectedAreaId!,
                            vehicleType: vehicleType,
                            identityNo: identityCtrl.text.trim(),
                            bankDetails: bankCtrl.text.trim(),
                          );
                        } else {
                          await ref.read(adminRepositoryProvider).updateUserDetails(existingRider['uid'], {
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'areaId': selectedAreaId!,
                            'vehicleType': vehicleType,
                            'identityNo': identityCtrl.text.trim(),
                            'bankDetails': bankCtrl.text.trim(),
                          });
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সফলভাবে সম্পন্ন হয়েছে')));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ব্যর্থ হয়েছে: $e')));
                        }
                      }
                    },
                    child: Text(existingRider == null ? 'রাইডার যোগ করুন' : 'আপডেট করুন'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridersAsync = ref.watch(allRidersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOnboardSheet(context, ref),
        label: const Text('নতুন রাইডার'),
        icon: const Icon(Icons.add),
      ),
      body: ridersAsync.when(
        data: (riders) {
          if (riders.isEmpty) return const Center(child: Text('কোনো রাইডার পাওয়া যায়নি'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: riders.length,
            itemBuilder: (context, index) {
              final r = riders[index];
              final isActive = r['isActive'] ?? true;
              final vehicle = r['vehicleType'] ?? 'bike';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(_getVehicleIcon(vehicle), color: AppColors.primary, size: 20),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r['name'] ?? 'রাইডার', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                              onPressed: () => _showOnboardSheet(context, ref, existingRider: r),
                            ),
                          ],
                        ),
                        subtitle: Text(r['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(isActive ? 'সক্রিয়' : 'ব্লকড', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 24,
                              child: Switch(
                                value: isActive,
                                activeTrackColor: Colors.green.withValues(alpha: 0.2),
                                activeColor: Colors.green,
                                onChanged: (val) {
                                  ref.read(adminRepositoryProvider).blockUser(r['uid'], !val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _smallInfo(Icons.verified_user, r['identityNo'] ?? 'No ID'),
                          _smallInfo(Icons.account_balance, r['bankDetails'] != null ? 'Bank Added' : 'No Bank'),
                          _smallInfo(Icons.location_on, 'Area: ${r['areaId']?.toString().substring(0, 4)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    if (type == 'cycle') return Icons.pedal_bike;
    if (type == 'scooter') return Icons.moped;
    return Icons.directions_bike;
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
