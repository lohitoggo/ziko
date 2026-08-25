import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PhoneAuthService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // Hanu OTP Credentials from Environment Variables
  final String _apiKey = dotenv.get('HANU_OTP_API_KEY', fallback: '');
  final String _templateId = dotenv.get('HANU_OTP_TEMPLATE_ID', fallback: 'default');

  String? _generatedOtp;
  String? _pendingPhone;

  /// Sends OTP using Hanu OTP API
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      // 1. Generate a random 6-digit OTP
      final random = Random();
      _generatedOtp = (100000 + random.nextInt(900000)).toString();
      _pendingPhone = phoneNumber;

      debugPrint('DEBUG: Attempting to send Hanu OTP $_generatedOtp to $phoneNumber');

      // 2. Prepare Phone Number
      String cleanPhone = phoneNumber.replaceAll('+', '').replaceAll(' ', '');
      
      if (cleanPhone.length == 12 && cleanPhone.startsWith('91')) {
        cleanPhone = cleanPhone.substring(2);
      } else if (cleanPhone.length > 10) {
        // Fallback: if it's more than 10 digits, just take the last 10
        cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
      }

      // 3. Prepare API URL
      final url = Uri.parse('https://api.hanuotp.in/sms-otp.php').replace(
        queryParameters: {
          'number': cleanPhone,
          'OTP': _generatedOtp,
          'apikey': _apiKey,
          'templatesid': _templateId,
        },
      );

      // 4. Make the GET request
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (response.body.toLowerCase().contains('success') || response.body.contains('200')) {
          onCodeSent('hanu_id_$_generatedOtp');
        } else {
          onError('Gateway error: ${response.body}');
        }
      } else {
        onError('SMS Server unreachable');
      }
    } catch (e) {
      onError('Network error occurred while sending SMS');
    }
  }

  /// Verifies the OTP manually entered by user
  Future<bool> verifyOtp(String otp) async {
    if (_generatedOtp == null || _pendingPhone == null) return false;

    if (otp.trim() == _generatedOtp) {
      return await _syncVerifiedPhoneToSupabase(_pendingPhone!);
    } else {
      debugPrint('DEBUG: OTP Mismatch');
      return false;
    }
  }

  Future<bool> _syncVerifiedPhoneToSupabase(String phone) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('profiles').update({
          'is_phone_verified': true,
          'phone': phone,
        }).eq('id', user.id);
        
        _generatedOtp = null;
        _pendingPhone = null;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
