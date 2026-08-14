import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the decision (Accept / Reject / View) that the native
/// OrderAlertActivity or NotificationActionReceiver wrote to 
/// SharedPreferences, and applies it to Supabase. This is the 
/// single source of truth for the new 100% native calling system.
class CallNotificationService {
  static const _prefsKey = 'pending_order_action';
  static const _channel = MethodChannel('com.ziko/order_actions');
  
  static bool _isListenerInitialized = false;
  static Function()? _onGlobalViewRequested;
  static Timer? _pollingTimer;

  /// Call once at app start. Safe to call multiple times.
  static void initGlobalListeners() {
    if (_isListenerInitialized) return;
    _isListenerInitialized = true;
    
    // Listen for real-time actions via MethodChannel
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOrderAction') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
        debugPrint('🔔 RECEIVED REAL-TIME NATIVE ACTION: ${data['action']}');
        _processAction(data);
      }
    });

    // Also check on startup/resume (fallback for SharedPreferences)
    checkPendingOrderAction();
  }

  /// Starts a high-frequency polling when an order call is active
  /// to ensure the Flutter side catches the native button click immediately.
  static void startActivePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      checkPendingOrderAction();
    });
    // Auto-stop polling after 60 seconds (failsafe for native timeout)
    Timer(const Duration(seconds: 60), () => stopActivePolling());
  }

  static void stopActivePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Call whenever the app resumes to catch decisions made 
  /// while the app was backgrounded or closed.
  static Future<void> checkPendingOrderAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // RELOAD prefs to ensure we see native writes
      await prefs.reload(); 
      
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;

      debugPrint('🔔 FOUND PENDING ACTION IN PREFS: $raw');

      // Consume the action immediately
      await prefs.remove(_prefsKey);
      stopActivePolling();

      final data = jsonDecode(raw) as Map<String, dynamic>;
      _processAction(data);
    } catch (e) {
      debugPrint('❌ Native action check error: $e');
    }
  }

  static Future<void> _processAction(Map<String, dynamic> data) async {
    final orderId = data['orderId']?.toString();
    final type = data['type']?.toString() ?? 'owner';
    final action = data['action']?.toString();

    if (orderId == null || orderId.isEmpty || action == null) return;

    debugPrint('🚀 EXECUTING ACTION: $action for Order $orderId ($type)');

    switch (action) {
      case 'accept':
        await _performSupabaseUpdate(orderId, type, 'accepted');
        break;
      case 'reject':
        await _performSupabaseUpdate(orderId, type, 'rejected');
        break;
      case 'view':
        if (_onGlobalViewRequested != null) _onGlobalViewRequested!();
        break;
    }
  }

  /// UI hook to switch to the Orders tab
  static void setViewCallback(Function() onView) {
    _onGlobalViewRequested = onView;
  }

  /// Legacy cleanup - no-op for the new native system
  static void stopCall() {}

  static Future<void> _performSupabaseUpdate(String orderId, String type, String status) async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      debugPrint('❌ DB Update Failed: No active session');
      return;
    }

    try {
      if (type == 'owner' || type == 'restaurant') {
        await supabase.from('orders').update({'status': status}).eq('id', orderId);
      } else if (type == 'rider') {
        if (status == 'accepted') {
          await supabase.from('orders').update({
            'rider_id': supabase.auth.currentUser!.id,
            'status': 'rider_assigned',
          }).eq('id', orderId);
        } else if (status == 'rejected') {
          // Optional: Add local rejection logic if needed
          debugPrint('ℹ️ Rider rejected order $orderId locally');
        }
      }
      debugPrint('✅ DB SYNC SUCCESS: Order $orderId -> $status');
    } catch (e) {
      debugPrint('❌ DB SYNC ERROR for Order $orderId: $e');
    }
  }
}
