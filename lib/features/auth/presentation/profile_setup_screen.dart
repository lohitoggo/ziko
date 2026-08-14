import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../data/user_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'area_selection_screen.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _secondaryPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pinCodeCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final sPhone = _secondaryPhoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final pin = _pinCodeCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || address.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সবগুলো প্রয়োজনীয় তথ্য পূরণ করুন')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final repo = ref.read(userRepositoryProvider);
      
      // Update comprehensive profile details including AUTO-EMAIL
      await repo.updateProfileDetails(
        user.id, 
        name: name, 
        phone: phone,
        email: user.email, // CAPTURING EMAIL FROM SESSION
        secondaryPhone: sPhone.isNotEmpty ? sPhone : null,
        address: address,
        pinCode: pin,
      );

      // Force refresh profile
      ref.invalidate(currentUserProvider);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AreaSelectionScreen()));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('প্রোফাইল সেটআপ', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আপনার সঠিক তথ্য দিন',
                style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.charcoal),
              ),
              const SizedBox(height: 8),
              Text(
                'ভালো সেবার জন্য আমাদের এই তথ্যগুলো প্রয়োজন',
                style: GoogleFonts.urbanist(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              
              _buildField('পুরো নাম *', _nameCtrl, Icons.person_outline_rounded),
              _buildField('ফোন নাম্বার *', _phoneCtrl, Icons.phone_android_rounded, type: TextInputType.phone),
              _buildField('বিকল্প ফোন নাম্বার (ঐচ্ছিক)', _secondaryPhoneCtrl, Icons.phone_callback_rounded, type: TextInputType.phone),
              _buildField('পুরো ঠিকানা *', _addressCtrl, Icons.location_on_outlined, maxLines: 2),
              _buildField('পিন কোড *', _pinCodeCtrl, Icons.pin_drop_outlined, type: TextInputType.number),

              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('সেভ করে এগিয়ে যান', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.urbanist(fontSize: 14, color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    );
  }
}
