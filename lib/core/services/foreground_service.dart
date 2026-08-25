import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Task started
    debugPrint('MyTaskHandler.onStart() started by $starter');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep alive tick
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Task destroyed
    debugPrint('MyTaskHandler.onDestroy(isTimeout: $isTimeout)');
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
        // channelImportance/priority moved to LOW for non-intrusive reliability
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (_starting) return;
    _starting = true;
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      
      // Explicitly request notification permission for Android 13+
      await FlutterForegroundTask.requestNotificationPermission();

      final result = await FlutterForegroundTask.startService(
        serviceId: 101, // Explicit service ID
        notificationTitle: 'ziko super app',
        notificationText: 'Ready for new orders',
        notificationIcon: null,
        callback: startCallback,
      );
      
      if (result is ServiceRequestSuccess) {
        debugPrint('ForegroundService started successfully');
      } else if (result is ServiceRequestFailure) {
        debugPrint('ForegroundService failed to start: ${result.error}');
      }
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
