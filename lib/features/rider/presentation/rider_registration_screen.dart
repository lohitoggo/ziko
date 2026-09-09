import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rider_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../auth/providers/area_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderRegistrationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingData;
  const RiderRegistrationScreen({super.key, this.existingData});

  @override
  ConsumerState<RiderRegistrationScreen> createState() => _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState extends ConsumerState<RiderRegistrationScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _identityCtrl;
  late TextEditingController _bankCtrl;
  String _vehicleType = 'bike';
  List<String> _selectedAreaIds = [];
  bool _isLoading = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    _identityCtrl = TextEditingController(text: data?['identity_no'] ?? '');
    _bankCtrl = TextEditingController(text: data?['bank_details'] ?? '');
    _vehicleType = data?['vehicle_type'] ?? 'bike';
    
    // Support both single and multi-area data
    if (data?['area_ids'] != null) {
      _selectedAreaIds = List<String>.from(data?['area_ids']);
    } else if (data?['area_id'] != null) {
      _selectedAreaIds = [data!['area_id']];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _identityCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _identityCtrl.text.isEmpty || _selectedAreaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সবগুলো তারকাচিহ্নিত (*) ফিল্ড পূরণ করুন')));
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অনুগ্রহ করে Rider Agreement-এ সম্মত হন'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'id': user.uid,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'vehicle_type': _vehicleType,
        'area_ids': _selectedAreaIds,
        'area_id': _selectedAreaIds.first, // Primary area for legacy support
        'identity_no': _identityCtrl.text.trim(),
        'bank_details': _bankCtrl.text.trim(),
        'accepted_terms_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'is_active': true,
      };

      await ref.read(riderRepositoryProvider).registerRider(data);

      // CRITICAL: Refresh providers to ensure AuthWrapper recognizes the new role immediately
      ref.invalidate(currentUserProvider);
      ref.invalidate(myRiderProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('আপনার আবেদন সফলভাবে জমা দেওয়া হয়েছে।')));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
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
    final areasAsync = ref.watch(activeAreasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('রাইডার হিসেবে যোগ দিন')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('আপনার সঠিক তথ্য দিন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'পুরো নাম *')),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর *')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              items: const [
                DropdownMenuItem(value: 'bike', child: Text('মোটরসাইকেল')),
                DropdownMenuItem(value: 'cycle', child: Text('সাইকেল')),
                DropdownMenuItem(value: 'scooter', child: Text('স্কুটার')),
              ],
              onChanged: (val) => setState(() => _vehicleType = val!),
              decoration: const InputDecoration(labelText: 'গাড়ির ধরণ *'),
            ),
            const SizedBox(height: 16),
            const Text('সার্ভিস এরিয়া নির্বাচন করুন *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            areasAsync.when(
              data: (areas) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: areas.map((a) {
                    final isSelected = _selectedAreaIds.contains(a.id);
                    return CheckboxListTile(
                      title: Text(a.name),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedAreaIds.add(a.id);
                          } else {
                            _selectedAreaIds.remove(a.id);
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
            TextField(controller: _identityCtrl, decoration: const InputDecoration(labelText: 'আধার/এনআইডি নম্বর *')),
            const SizedBox(height: 16),
            TextField(controller: _bankCtrl, decoration: const InputDecoration(labelText: 'ব্যাংক ডিটেইলস (Account/UPI)')),
            const SizedBox(height: 20),

            // Rider Legal Agreement Checkbox
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
                          TextSpan(text: 'Rider Agreement', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          TextSpan(text: ' এবং ডেলিভারি নীতিমালায় সম্মত আছি।'),
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
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('আবেদন সম্পন্ন করুন'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
