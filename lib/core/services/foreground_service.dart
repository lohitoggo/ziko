import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    // Task started
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Keep alive tick
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    // Task destroyed
  }
}

class ForegroundService {
  static bool _initialized = false;
  static bool _starting = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Critical Order Monitoring',
        channelDescription: 'Maintains 100% reliability for new order calls',
        // Explicit small icon - missing/invalid icon is a common cause of
        // "Bad notification for startForeground" crashes on some OEM skins
        // (Realme/ColorOS included).
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        // MAX/HIGH made this a heads-up alert competing with the actual
        // call UI, which is likely part of what triggered the crash on
        // return from the CallkitIncomingActivity. This is just a silent
        // "keep alive" notification, so it doesn't need to be loud.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        isSticky: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    // Guard against re-entrant/racy calls (e.g. widget re-mounting right
    // after returning from the native CallkitIncomingActivity).
    if (_starting) return;
    _starting = true;
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        notificationTitle: 'ziko super app',
        notificationText: 'Ready for new orders',
        callback: startCallback,
      );
    } catch (e) {
      debugPrint('ForegroundService.start() failed: $e');
    } finally {
      _starting = false;
    }
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}