import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/restaurant_owner_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../auth/providers/area_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/upload_provider.dart';
import 'business_registration_screen.dart';

class BusinessProfileTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> restaurant;
  const BusinessProfileTab({super.key, required this.restaurant});

  @override
  ConsumerState<BusinessProfileTab> createState() => _BusinessProfileTabState();
}

class _BusinessProfileTabState extends ConsumerState<BusinessProfileTab> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _upiCtrl;
  late TextEditingController _openingCtrl;
  late TextEditingController _closingCtrl;
  late TextEditingController _opening2Ctrl;
  late TextEditingController _closing2Ctrl;
  late String _offDay;
  bool _hasDoubleShift = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.restaurant['name']);
    _descCtrl = TextEditingController(text: widget.restaurant['description']);
    _addressCtrl = TextEditingController(text: widget.restaurant['address']);
    _upiCtrl = TextEditingController(text: widget.restaurant['upi_id']);
    _openingCtrl = TextEditingController(text: widget.restaurant['opening_time'] ?? '09:00 AM');
    _closingCtrl = TextEditingController(text: widget.restaurant['closing_time'] ?? '01:00 PM');
    _opening2Ctrl = TextEditingController(text: widget.restaurant['opening_time_2'] ?? '05:00 PM');
    _closing2Ctrl = TextEditingController(text: widget.restaurant['closing_time_2'] ?? '09:00 PM');
    _hasDoubleShift = widget.restaurant['has_double_shift'] ?? false;
    _offDay = widget.restaurant['off_day'] ?? 'None';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _upiCtrl.dispose();
    _openingCtrl.dispose();
    _closingCtrl.dispose();
    _opening2Ctrl.dispose();
    _closing2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final restaurantId = widget.restaurant['restaurantId'];
    try {
      await ref.read(restaurantOwnerRepositoryProvider).updateBusinessProfile(restaurantId, {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'upi_id': _upiCtrl.text.trim(),
        'opening_time': _openingCtrl.text.trim(),
        'closing_time': _closingCtrl.text.trim(),
        'opening_time_2': _opening2Ctrl.text.trim(),
        'closing_time_2': _closing2Ctrl.text.trim(),
        'has_double_shift': _hasDoubleShift,
        'off_day': _offDay,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('প্রোফাইল আপডেট হয়েছে')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ব্যর্থ হয়েছে: $e')));
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('লগআউট'),
        content: const Text('আপনি কি নিশ্চিত যে আপনি লগআউট করতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () async {
              await ref.read(supabaseAuthControllerProvider).signOut();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => AuthWrapper()),
                  (route) => false,
                );
              }
            },
            child: const Text('হ্যাঁ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লোগো আপলোড হচ্ছে...')));

    try {
      final url = await ref.read(uploadServiceProvider).uploadImage(File(image.path), 'logos');
      if (url != null) {
        final restaurantId = widget.restaurant['restaurantId'];
        await ref.read(restaurantOwnerRepositoryProvider).updateBusinessProfile(restaurantId, {'logoUrl': url});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লোগো আপডেট হয়েছে')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('আপলোড ব্যর্থ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.restaurant['is_online'] ?? false;
    final List<String> banners = List<String>.from(widget.restaurant['banner_urls'] ?? []);
    final List<String> areaIds = List<String>.from(widget.restaurant['area_ids'] ?? []);
    final areasAsync = ref.watch(activeAreasProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Logo
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: widget.restaurant['logo_url'] != null 
                        ? NetworkImage(widget.restaurant['logo_url']) 
                        : null,
                    child: widget.restaurant['logo_url'] == null 
                        ? const Icon(Icons.store, size: 50, color: AppColors.primary) 
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _pickAndUploadLogo,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('লোগো পরিবর্তন করুন'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Online Switch
            _buildSettingCard(
              title: isOnline ? 'আপনার দোকান খোলা আছে' : 'আপনার দোকান বন্ধ',
              subtitle: 'অনলাইন থাকলে কাস্টমাররা অর্ডার করতে পারবে',
              trailing: Switch(
                value: isOnline,
                activeThumbColor: AppColors.softGreen,
                onChanged: (val) {
                  ref.read(restaurantOwnerRepositoryProvider).toggleOnline(widget.restaurant['restaurantId'], val);
                },
              ),
            ),
            const SizedBox(height: 25),

            // FIXED INFO (Read-only for Owner)
            const Text('অফিসিয়াল তথ্য (অ্যাডমিন অনুমোদিত)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _buildReadOnlyRow('মালিকের নাম', widget.restaurant['owner_name'] ?? 'লোড হচ্ছে...'),
                  const Divider(),
                  _buildReadOnlyRow('ফোন নম্বর', widget.restaurant['owner_phone'] ?? 'লোড হচ্ছে...'),
                  const Divider(),
                  _buildReadOnlyRow('ক্যাটাগরি', widget.restaurant['category']?.toString().toUpperCase() ?? 'N/A'),
                  const Divider(),
                  _buildReadOnlyRow('লাইসেন্স নং', widget.restaurant['license_no'] ?? 'দেওয়া হয়নি'),
                  const Divider(),
                  _buildReadOnlyRow('কমিশন হার', '${widget.restaurant['commission_rate'] ?? 10}%'),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // AREAS (Read-only)
            const Text('নির্বাচিত সার্ভিস এলাকা', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            areasAsync.when(
              data: (allAreas) {
                final selectedNames = allAreas
                    .where((a) => areaIds.contains(a.id))
                    .map((a) => a.name)
                    .join(', ');
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(selectedNames.isEmpty ? 'কোনো এলাকা নির্বাচিত নেই' : selectedNames, style: const TextStyle(fontSize: 13)),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('এলাকা লোড করা যায়নি'),
            ),
            const SizedBox(height: 30),

            // EDITABLE INFO
            const Text('দোকানের পরিবর্তনযোগ্য তথ্য', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'দোকানের নাম')),
            const SizedBox(height: 15),
            TextField(controller: _upiCtrl, decoration: const InputDecoration(labelText: 'UPI ID (পেমেন্টের জন্য)')),
            const SizedBox(height: 15),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'বিবরণ'), maxLines: 2),
            const SizedBox(height: 15),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'ঠিকানা'), maxLines: 2),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('অপারেটিং আওয়ার্স এবং ছুটি', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('২য় শিফট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _hasDoubleShift,
                      onChanged: (v) => setState(() => _hasDoubleShift = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Text('১ম শিফট (সকাল/প্রথম ভাগ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 9, minute: 0));
                      if (time != null) setState(() => _openingCtrl.text = time.format(context));
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _openingCtrl,
                        decoration: const InputDecoration(labelText: 'খোলার সময়', prefixIcon: Icon(Icons.access_time)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 13, minute: 0));
                      if (time != null) setState(() => _closingCtrl.text = time.format(context));
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _closingCtrl,
                        decoration: const InputDecoration(labelText: 'বন্ধের সময়', prefixIcon: Icon(Icons.access_time_filled)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (_hasDoubleShift) ...[
              const SizedBox(height: 16),
              const Text('২য় শিফট (বিকাল/দ্বিতীয় ভাগ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 17, minute: 0));
                        if (time != null) setState(() => _opening2Ctrl.text = time.format(context));
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _opening2Ctrl,
                          decoration: const InputDecoration(labelText: 'খোলার সময়', prefixIcon: Icon(Icons.access_time)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 21, minute: 0));
                        if (time != null) setState(() => _closing2Ctrl.text = time.format(context));
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _closing2Ctrl,
                          decoration: const InputDecoration(labelText: 'বন্ধের সময়', prefixIcon: Icon(Icons.access_time_filled)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _offDay,
              items: ['None', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d == 'None' ? 'কোনো ছুটি নেই' : d))).toList(),
              onChanged: (v) => setState(() => _offDay = v!),
              decoration: const InputDecoration(labelText: 'সাপ্তাহিক ছুটির দিন', prefixIcon: Icon(Icons.event_busy)),
            ),
            const SizedBox(height: 30),

            // Banners Section
            const Text('দোকানের ব্যানার ছবি', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (banners.isEmpty)
              const Text('কোনো ব্যানার যোগ করা হয়নি', style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: banners.length,
                  itemBuilder: (ctx, i) => Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(image: NetworkImage(banners[i]), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessRegistrationScreen(existingData: widget.restaurant)));
              }, 
              icon: const Icon(Icons.collections_outlined), 
              label: const Text('ছবি ও এলাকা ম্যানেজ করুন')
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateProfile,
                child: const Text('পরিবর্তন সেভ করুন'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout),
                label: const Text('লগআউট'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
