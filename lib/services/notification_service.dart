import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps flutter_local_notifications so the rest of the app can just call
/// NotificationService.showNearby(name).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Android 13+ requires runtime notification permission; this channel
    // must exist before we can post to it.
    const channel = AndroidNotificationChannel(
      'geofence_alerts',
      'Nearby place alerts',
      description: 'Notifies you when you enter a saved place\'s radius',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showNearby(String placeName, {String? body}) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'geofence_alerts',
      'Nearby place alerts',
      channelDescription: 'Notifies you when you enter a saved place\'s radius',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      placeName.hashCode,
      'You\'re near $placeName',
      body ?? 'You\'ve entered the $placeName zone.',
      details,
    );
  }
}
