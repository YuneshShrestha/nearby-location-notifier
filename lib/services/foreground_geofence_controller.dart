import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'geofencing_task_handler.dart';

/// Thin controller the UI isolate uses to start/stop the foreground service
/// that hosts geofencing_api's monitoring loop.
///
/// It does NOT push the place list directly into the service — the task
/// handler re-reads places from SharedPreferences itself on every repeat
/// tick (see GeofencingTaskHandler.onRepeatEvent). So from the UI side,
/// saving a place via StorageService is enough; this controller only needs
/// to make sure the service is running whenever there's at least one active
/// place, and stopped otherwise.
class ForegroundGeofenceController {
  ForegroundGeofenceController._();
  static final ForegroundGeofenceController instance =
      ForegroundGeofenceController._();

  bool _initialized = false;

  void _initIfNeeded() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'nearby_notifier_geofence',
        channelName: 'Nearby place monitoring',
        channelDescription:
            'Keeps checking your distance to saved places in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _initialized = true;
  }

  /// Ensures the foreground service is running. Safe to call repeatedly —
  /// no-ops if it's already up, since the handler will pick up any place
  /// list change on its next repeat tick.
  Future<void> ensureRunning() async {
    _initIfNeeded();

    if (await FlutterForegroundTask.isRunningService) return;

    try {
      await FlutterForegroundTask.startService(
      notificationTitle: 'Nearby Notifier is watching your saved places',
      notificationText: 'Tap to open the app',
      callback: startCallback,
    );
    } catch (e) {
      print('Error starting foreground service: $e');
    }
  
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  /// Ask the OS to exempt the app from battery optimization — meaningfully
  /// improves reliability on OEMs (Xiaomi/Huawei/etc.) that aggressively
  /// kill foreground services otherwise. Best triggered from a settings
  /// screen / explicit user action, not silently on launch.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}
