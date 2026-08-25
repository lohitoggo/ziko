import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/upload_provider.dart';

class AdminShopsTab extends ConsumerWidget {
  const AdminShopsTab({super.key});

  void _showOnboardSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existingShop}) {
    final nameCtrl = TextEditingController(text: existingShop?['name']);
    final ownerNameCtrl = TextEditingController(text: existingShop?['owner_name']);
    final phoneCtrl = TextEditingController(text: existingShop?['owner_phone']);
    final addressCtrl = TextEditingController(text: existingShop?['address']);
    final commissionCtrl = TextEditingController(text: existingShop != null ? (existingShop['commission_rate'] ?? 0).toString() : '10');
    final upiCtrl = TextEditingController(text: existingShop?['upi_id']);
    final licenseCtrl = TextEditingController(text: existingShop?['license_no']);
    
    String category = existingShop?['category'] ?? 'restaurant';
    List<String> selectedAreaIds = List<String>.from(existingShop?['area_ids'] ?? []);
    File? selectedLogo;
    String? existingLogoUrl = existingShop?['logo_url'];

    final areasAsync = ref.watch(allAreasProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> pickLogo() async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setModalState(() => selectedLogo = File(image.path));
            }
          }

          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existingShop == null ? 'নতুন দোকান অনবোর্ড করুন' : 'দোকান এডিট করুন', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Logo Picker
                  Center(
                    child: InkWell(
                      onTap: pickLogo,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: selectedLogo != null 
                            ? FileImage(selectedLogo!) 
                            : (existingLogoUrl != null ? NetworkImage(existingLogoUrl) : null) as ImageProvider?,
                        child: selectedLogo == null && existingLogoUrl == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'দোকানের নাম')),
                  const SizedBox(height: 12),
                  TextField(controller: ownerNameCtrl, decoration: const InputDecoration(labelText: 'মালিকের নাম')),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          items: const [
                            DropdownMenuItem(value: 'restaurant', child: Text('রেস্টুরেন্ট')),
                            DropdownMenuItem(value: 'salon', child: Text('সেলুন')),
                            DropdownMenuItem(value: 'grocery', child: Text('গ্রোসারি')),
                            DropdownMenuItem(value: 'electronics', child: Text('ইলেকট্রনিক্স')),
                          ],
                          onChanged: (val) => setModalState(() => category = val!),
                          decoration: const InputDecoration(labelText: 'ক্যাটাগরি'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: commissionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'কমিশন (%)')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Multi-select Area Section
                  const Text('এলাকা নির্বাচন করুন (একাধিক সম্ভব)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  areasAsync.when(
                    data: (areas) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: areas.map((a) {
                          final id = a['areaId'] as String;
                          final isSelected = selectedAreaIds.contains(id);
                          return CheckboxListTile(
                            title: Text(a['name'] ?? ''),
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedAreaIds.add(id);
                                } else {
                                  selectedAreaIds.remove(id);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }).toList(),
                      ),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('এলাকা লোড করা যায়নি'),
                  ),
                  
                  const SizedBox(height: 12),
                  TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: 'UPI ID (টাকা পাঠানোর জন্য)')),
                  const SizedBox(height: 12),
                  TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'ট্রেড লাইসেন্স নম্বর')),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'দোকানের পুরো ঠিকানা')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || selectedAreaIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('দোকানের নাম, ফোন এবং অন্তত একটি এলাকা নির্বাচন করুন')));
                          return;
                        }

                        try {
                          String? logoUrl;
                          if (selectedLogo != null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লোগো আপলোড হচ্ছে...')));
                            logoUrl = await ref.read(uploadServiceProvider).uploadImage(selectedLogo!, 'logos');
                          }

                          final data = {
                            'name': nameCtrl.text.trim(),
                            'owner_name': ownerNameCtrl.text.trim(),
                            'owner_phone': phoneCtrl.text.trim(),
                            'category': category,
                            'area_ids': selectedAreaIds,
                            'area_id': selectedAreaIds.first, // Legacy support
                            'address': addressCtrl.text.trim(),
                            'commission_rate': double.tryParse(commissionCtrl.text) ?? 10.0,
                            'upi_id': upiCtrl.text.trim(),
                            'license_no': licenseCtrl.text.trim(),
                            'logo_url': ?logoUrl,
                          };

                          if (existingShop == null) {
                            await ref.read(adminRepositoryProvider).onboardBusiness(
                              name: data['name'] as String,
                              ownerName: data['owner_name'] as String,
                              ownerPhone: data['owner_phone'] as String,
                              category: category,
                              areaId: selectedAreaIds.first,
                              address: data['address'] as String,
                              commissionRate: data['commission_rate'] as double,
                              upiId: data['upi_id'] as String?,
                              licenseNo: data['license_no'] as String?,
                              logoUrl: logoUrl,
                            );
                            // Need to update area_ids separately if onboardBusiness doesn't support it yet
                            // For now, I'll update the repository to handle the full map
                          } else {
                            await ref.read(adminRepositoryProvider).updateBusinessDetails(existingShop['restaurantId'], data);
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সফলভাবে সম্পন্ন হয়েছে')));
                          }
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ব্যর্থ হয়েছে: $e')));
                        }
                      },
                      child: Text(existingShop == null ? 'অনবোর্ড সম্পন্ন করুন' : 'আপডেট সম্পন্ন করুন'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(allRestaurantsProvider);
    final repo = ref.read(adminRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOnboardSheet(context, ref),
        label: const Text('নতুন দোকান'),
        icon: const Icon(Icons.add),
      ),
      body: shopsAsync.when(
        data: (shops) {
          if (shops.isEmpty) return const Center(child: Text('কোনো দোকান পাওয়া যায়নি'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final s = shops[index];
              final status = s['status'] ?? 'pending';
              final isOnline = s['is_online'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(s['category']?.toString().toUpperCase() ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('কমিশন: ${s['commission_rate'] ?? 0}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _showOnboardSheet(context, ref, existingShop: s),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(s['owner_name'] ?? 'মালিকের নাম নেই', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 12),
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(s['owner_phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(child: Text(s['address'] ?? '', style: TextStyle(color: AppColors.muted, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await repo.updateRestaurantStatus(s['restaurantId'], status == 'approved' ? 'suspended' : 'approved');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: status == 'approved' ? Colors.red : Colors.green,
                                side: BorderSide(color: status == 'approved' ? Colors.red : Colors.green),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(status == 'approved' ? 'স্থগিত করুন' : 'অনুমোদন দিন'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: isOnline ? AppColors.softGreen.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                await repo.forceRestaurantOnlineOffline(s['restaurantId'], !isOnline);
                              },
                              icon: Icon(isOnline ? Icons.flash_on : Icons.flash_off, color: isOnline ? AppColors.softGreen : Colors.grey),
                            ),
                          ),
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

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    String label = 'অপেক্ষমান';
    if (status == 'approved') { color = Colors.green; label = 'অনুমোদিত'; }
    else if (status == 'suspended') { color = Colors.red; label = 'স্থগিত'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
