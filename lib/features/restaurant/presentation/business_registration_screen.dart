import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/restaurant_owner_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../auth/providers/area_provider.dart';
import '../../../core/services/upload_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessRegistrationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingData;
  const BusinessRegistrationScreen({super.key, this.existingData});

  @override
  ConsumerState<BusinessRegistrationScreen> createState() => _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState extends ConsumerState<BusinessRegistrationScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _upiCtrl;
  late TextEditingController _licenseCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _openingCtrl;
  late TextEditingController _closingCtrl;
  late TextEditingController _opening2Ctrl;
  late TextEditingController _closing2Ctrl;
  late String _category;
  late String _offDay;
  bool _hasDoubleShift = false;
  
  File? _logoFile;
  List<File> _bannerFiles = [];
  List<String> _existingBanners = [];
  List<String> _selectedAreaIds = [];
  bool _isLoading = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _ownerNameCtrl = TextEditingController(text: data?['owner_name'] ?? '');
    _phoneCtrl = TextEditingController(text: data?['owner_phone'] ?? '');
    _upiCtrl = TextEditingController(text: data?['upi_id'] ?? '');
    _licenseCtrl = TextEditingController(text: data?['license_no'] ?? '');
    _descCtrl = TextEditingController(text: data?['description'] ?? '');
    _addressCtrl = TextEditingController(text: data?['address'] ?? '');
    _openingCtrl = TextEditingController(text: data?['opening_time'] ?? '09:00 AM');
    _closingCtrl = TextEditingController(text: data?['closing_time'] ?? '01:00 PM');
    _opening2Ctrl = TextEditingController(text: data?['opening_time_2'] ?? '05:00 PM');
    _closing2Ctrl = TextEditingController(text: data?['closing_time_2'] ?? '09:00 PM');
    _hasDoubleShift = data?['has_double_shift'] ?? false;
    _category = data?['category'] ?? 'restaurant';
    _offDay = data?['off_day'] ?? 'None';
    _existingBanners = List<String>.from(data?['banner_urls'] ?? []);
    _selectedAreaIds = List<String>.from(data?['area_ids'] ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _upiCtrl.dispose();
    _licenseCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _openingCtrl.dispose();
    _closingCtrl.dispose();
    _opening2Ctrl.dispose();
    _closing2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _logoFile = File(image.path));
  }

  Future<void> _pickBanners() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _bannerFiles.addAll(pickedFiles.map((e) => File(e.path)).toList());
        if (_bannerFiles.length > 5) _bannerFiles = _bannerFiles.sublist(0, 5);
      });
    }
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _ownerNameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সবগুলো লাল চিহ্নিত ফিল্ড পূরণ করুন')));
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অনুগ্রহ করে Terms and Conditions এ সম্মত হন'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uploadService = ref.read(uploadServiceProvider);
      
      // 1. Upload Logo
      String? logoUrl = widget.existingData?['logo_url'];
      if (_logoFile != null) {
        logoUrl = await uploadService.uploadImage(_logoFile!, 'logos');
      }

      // 2. Upload Banners
      List<String> bannerUrls = List<String>.from(_existingBanners);
      if (_bannerFiles.isNotEmpty) {
        final newUrls = await uploadService.uploadMultipleImages(_bannerFiles, 'banners');
        bannerUrls.addAll(newUrls);
      }
      if (bannerUrls.length > 5) bannerUrls = bannerUrls.sublist(0, 5);

      final data = {
        'owner_id': user.uid,
        'name': _nameCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'owner_phone': _phoneCtrl.text.trim(),
        'upi_id': _upiCtrl.text.trim(),
        'license_no': _licenseCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'category': _category,
        'area_ids': _selectedAreaIds,
        'area_id': _selectedAreaIds.isNotEmpty ? _selectedAreaIds.first : null,
        'logo_url': logoUrl,
        'banner_urls': bannerUrls,
        'opening_time': _openingCtrl.text.trim(),
        'closing_time': _closingCtrl.text.trim(),
        'opening_time_2': _opening2Ctrl.text.trim(),
        'closing_time_2': _closing2Ctrl.text.trim(),
        'has_double_shift': _hasDoubleShift,
        'off_day': _offDay,
        'accepted_terms_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'is_online': false,
      };

      await ref.read(restaurantOwnerRepositoryProvider).registerBusiness(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('তথ্য সফলভাবে জমা দেওয়া হয়েছে।')));
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ব্যর্থ হয়েছে: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingLogoUrl = widget.existingData?['logo_url'];
    final areasAsync = ref.watch(activeAreasProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.existingData == null ? 'দোকান নিবন্ধন' : 'তথ্য পরিবর্তন')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('দোকানের লোগো এবং ব্যানার', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                // Logo Picker
                InkWell(
                  onTap: _pickLogo,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _logoFile != null 
                        ? FileImage(_logoFile!) 
                        : (existingLogoUrl != null ? NetworkImage(existingLogoUrl) : null) as ImageProvider?,
                    child: _logoFile == null && existingLogoUrl == null ? const Icon(Icons.add_a_photo, size: 30, color: AppColors.primary) : null,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text('দোকানের একটি পরিষ্কার লোগো আপলোড করুন।', style: TextStyle(fontSize: 12, color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 24),
            
            // Banners Picker
            const Text('দোকানের ছবি (সর্বোচ্চ ৫টি)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  InkWell(
                    onTap: _pickBanners,
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                    ),
                  ),
                  ..._bannerFiles.map((file) => Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                    ),
                  )),
                  ..._existingBanners.map((url) => Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                    ),
                  )),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text('মালিকের তথ্য', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _ownerNameCtrl, decoration: const InputDecoration(labelText: 'মালিকের নাম *')),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর *')),
            const SizedBox(height: 12),
            TextField(controller: _upiCtrl, decoration: const InputDecoration(labelText: 'UPI ID (টাকা পাওয়ার জন্য)')),
            
            const SizedBox(height: 30),
            const Text('দোকানের তথ্য', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'দোকানের নাম *')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: const [
                DropdownMenuItem(value: 'restaurant', child: Text('রেস্টুরেন্ট')),
                DropdownMenuItem(value: 'salon', child: Text('সেলুন')),
                DropdownMenuItem(value: 'grocery', child: Text('গ্রোসারি')),
                DropdownMenuItem(value: 'electronics', child: Text('ইলেকট্রনিক্স')),
              ],
              onChanged: (val) => setState(() => _category = val!),
              decoration: const InputDecoration(labelText: 'ক্যাটাগরি'),
            ),
            
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('অপারেটিং আওয়ার্স (Operating Hours)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.muted)),
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
            const SizedBox(height: 12),
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

            const SizedBox(height: 16),
            const Text('সার্ভিস এরিয়া নির্বাচন করুন (ঐচ্ছিক)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            areasAsync.when(
              data: (areas) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: areas.map((a) {
                    final id = a.id;
                    final isSelected = _selectedAreaIds.contains(id);
                    return CheckboxListTile(
                      title: Text(a.name),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedAreaIds.add(id);
                          } else {
                            _selectedAreaIds.remove(id);
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
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            TextField(controller: _licenseCtrl, decoration: const InputDecoration(labelText: 'ট্রেড লাইসেন্স নম্বর')),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'বিবরণ (Shop Description)')),
            const SizedBox(height: 12),
            TextField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'দোকানের পুরো ঠিকানা *')),
            const SizedBox(height: 20),

            // Vendor Legal Agreement Checkbox
            Row(
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://zikoapp.online/terms-and-conditions'), mode: LaunchMode.externalApplication),
                    child: RichText(
                      text: TextSpan(
                        text: 'আমি Ziko-র ',
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                        children: const [
                          TextSpan(text: 'Merchant Agreement', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          TextSpan(text: ' এবং কমিশন পলিসিতে সম্মত আছি।'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('নিবন্ধন সম্পন্ন করুন'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
