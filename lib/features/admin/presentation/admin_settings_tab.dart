import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/upload_provider.dart';

class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  final _platformFeeCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _announcementCtrl = TextEditingController();

  @override
  void dispose() {
    _platformFeeCtrl.dispose();
    _gstCtrl.dispose();
    _announcementCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    try {
      await ref.read(adminRepositoryProvider).updateSystemSettings({
        'platformFee': double.tryParse(_platformFeeCtrl.text) ?? 0.0,
        'gstPercentage': double.tryParse(_gstCtrl.text) ?? 0.0,
        'announcement': _announcementCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সেটিংস সফলভাবে আপডেট হয়েছে')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('সেটিংস আপডেট ব্যর্থ: $e')));
      }
    }
  }

  Future<void> _addBanner(List<String> currentUrls) async {
    if (currentUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সর্বোচ্চ ৫টি ব্যানার রাখা সম্ভব')));
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ব্যানার আপলোড হচ্ছে...')));
    }

    final url = await ref.read(uploadServiceProvider).uploadImage(File(image.path), 'banners');
    
    if (url != null) {
      final updatedList = [...currentUrls, url];
      await ref.read(adminRepositoryProvider).updateSystemSettings({'banner_urls': updatedList});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ব্যানার যোগ করা হয়েছে')));
      }
    }
  }

  Future<void> _removeBanner(List<String> currentUrls, int index) async {
    final updatedList = List<String>.from(currentUrls);
    updatedList.removeAt(index);
    await ref.read(adminRepositoryProvider).updateSystemSettings({'banner_urls': updatedList});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ব্যানার মুছে ফেলা হয়েছে')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(systemSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: settingsAsync.when(
        data: (settings) {
          final isMaintenance = settings?['is_maintenance_mode'] ?? false;
          final isAutoAssign = settings?['is_auto_assign_enabled'] ?? true;
          _platformFeeCtrl.text = (settings?['platform_fee'] ?? 0.0).toString();
          _gstCtrl.text = (settings?['gst_percentage'] ?? 0.0).toString();
          _announcementCtrl.text = settings?['announcement'] ?? '';
          final List<String> bannerUrls = List<String>.from(settings?['banner_urls'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('সিস্টেম সেটিংস', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),

                // 1. Banner Management
                _buildBannerSection(bannerUrls),
                const SizedBox(height: 25),

                // 1.1 AUTO ASSIGN CONTROL
                _buildSettingCard(
                  title: 'অটো-অ্যাসাইন (Rider Call)',
                  subtitle: 'এটি চালু থাকলে রাইডারদের কাছে অটোমেটিক কল যাবে।',
                  trailing: Switch(
                    value: isAutoAssign,
                    activeColor: AppColors.softGreen,
                    onChanged: (val) => ref.read(adminRepositoryProvider).updateSystemSettings({'is_auto_assign_enabled': val}),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Maintenance Mode
                _buildSettingCard(
                  title: 'মেইনটেইনেন্স মোড',
                  subtitle: 'এটি চালু করলে কাস্টমাররা অর্ডার করতে পারবে না।',
                  trailing: Switch(
                    value: isMaintenance,
                    activeThumbColor: Colors.red,
                    onChanged: (val) => ref.read(adminRepositoryProvider).toggleMaintenanceMode(val),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Global Fees
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('সার্ভিস ফি এবং ট্যাক্স', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _platformFeeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'প্ল্যাটফর্ম ফি (₹)'))),
                          const SizedBox(width: 15),
                          Expanded(child: TextField(controller: _gstCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GST (%)'))),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Broadcast Announcement
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('সিস্টেম অ্যানাউন্সমেন্ট', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _announcementCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(hintText: 'মেসেজ এখানে লিখুন...'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('সব পরিবর্তন সেভ করুন'),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBannerSection(List<String> urls) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('প্রোমো ব্যানার (${urls.length}/5)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (urls.length < 5)
                IconButton(
                  onPressed: () => _addBanner(urls),
                  icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 15),
          if (urls.isEmpty)
            const Center(child: Text('কোনো ব্যানার আপলোড করা নেই', style: TextStyle(color: Colors.grey, fontSize: 13))),
          if (urls.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: urls.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: NetworkImage(urls[index]), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 5, right: 17,
                        child: InkWell(
                          onTap: () => _removeBanner(urls, index),
                          child: CircleAvatar(
                            radius: 12, backgroundColor: Colors.red.withValues(alpha: 0.8),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required String title, required String subtitle, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
