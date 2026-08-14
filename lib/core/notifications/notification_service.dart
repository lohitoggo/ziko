import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../supabase_config.dart';
import 'call_notification_service.dart';

class NotificationService {
  static String get appId => SupabaseConfig.oneSignalAppId;
  static String get restKey => SupabaseConfig.oneSignalRestKey;

  static Future<void> initialize() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(appId);

    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      print('DEBUG: Foreground Notification Received. Action: ${data?['action']}');

      if (data != null && data['action'] == 'incoming_order_call') {
        // Start high-frequency polling on the Flutter side to catch native button actions immediately
        CallNotificationService.startActivePolling();

        // The native NotificationServiceExtension.kt already handles
        // showing the CallKit incoming-call UI for this action - in every
        // app state (foreground, background, killed). Triggering it AGAIN
        // here from Dart used to create a second, duplicate Telecom call
        // (with a different, random call id instead of the orderId),
        // which confused Android's Telecom framework and crashed the app.
        // So here we only suppress the plain OneSignal notification banner
        // and let the native path be the single source of truth for the
        // call UI.
        event.preventDefault();
      }
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['action'] == 'incoming_order_call') {
        // Same reasoning as above: don't re-trigger the call UI here.
        // Nothing to do - the native path already owns this action.
      }
    });
  }

  static Future<void> updateUserSubscriptionId(String userId) async {
    // OneSignal might take a moment to register a Player ID on new devices/installs
    String? subscriptionId = OneSignal.User.pushSubscription.id;

    // RETRY LOGIC: If ID is null, wait and try again up to 3 times
    int retries = 0;
    while (subscriptionId == null && retries < 3) {
      await Future.delayed(const Duration(seconds: 2));
      subscriptionId = OneSignal.User.pushSubscription.id;
      retries++;
    }

    if (subscriptionId == null) {
      print('CRITICAL: OneSignal Subscription ID is STILL NULL after retries.');
      return;
    }

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'notification_id': subscriptionId})
          .eq('id', userId);
      print('SUCCESS: Notification ID synced for user $userId: $subscriptionId');
    } catch (e) {
      print('Error syncing Notification ID: $e');
    }
  }

  static Future<void> sendNotification({
    required String targetNotificationId,
    required String title,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    try {
      final body = {
        'app_id': appId,
        'include_subscription_ids': [targetNotificationId],
        'headings': {'en': title},
        'contents': {'en': content},
        'data': data,
        'priority': 10, // MAX PRIORITY
        'android_visibility': 1, // Public for Lock Screen
        // Removed android_channel_id as it was causing 400 errors
      };

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        print('❌ ONESIGNAL SEND FAILED: ${response.statusCode} - ${response.body}');
      } else {
        print('✅ ONESIGNAL SEND OK: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}