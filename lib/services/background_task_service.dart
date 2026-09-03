import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';

import 'storage_service.dart';
import 'notification_service.dart';
import '../utils/distance_utils.dart';

const String kNearbyCheckTask = 'nearbyCheckTask';
const String kNearbyCheckTaskUniqueName = 'nearby-notifier-periodic-check';

/// This runs in a separate background isolate, so it cannot see any state
/// from the main app (no shared memory) — everything it needs (places,
/// "already notified" bookkeeping) is re-loaded from SharedPreferences here.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kNearbyCheckTask) return Future.value(true);

    try {
      await _checkNearbyPlaces();
    } catch (_) {
      // Swallow errors — a failed background check shouldn't crash the
      // scheduler or prevent the next scheduled run.
    }
    return Future.value(true);
  });
}

Future<void> _checkNearbyPlaces() async {
  final storage = StorageService();
  final places = await storage.loadPlaces();
  final activePlaces = places.where((p) => p.active).toList();
  if (activePlaces.isEmpty) return;

  final hasPermission = await _hasLocationPermission();
  if (!hasPermission) return;

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: .medium),
  );
  final notifiedRecently = await _RecentNotifications.load();

  for (final place in activePlaces) {
    final within = DistanceUtils.isWithinRadius(
      currentLat: position.latitude,
      currentLng: position.longitude,
      targetLat: place.latitude,
      targetLng: place.longitude,
      radiusMeters: place.radiusMeters,
    );

    if (!within) {
      // Left the zone (or was never in it) — clear so a future re-entry
      // notifies again.
      notifiedRecently.clear(place.id);
      continue;
    }

    // Avoid re-notifying every 15 minutes while the user just sits inside
    // the zone — only notify again after they've been away for a while.
    if (notifiedRecently.wasNotifiedRecently(place.id)) continue;

    await NotificationService.instance.showNearby(place.name);
    notifiedRecently.markNotified(place.id);
  }

  await notifiedRecently.save();
}

Future<bool> _hasLocationPermission() async {
  final permission = await Geolocator.checkPermission();
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

/// Tiny on-device dedupe so the periodic task doesn't re-fire a notification
/// every single run while the user is still standing inside a zone.
class _RecentNotifications {
  static const _key = 'nearby_notifier.recent_notifications';
  static const _cooldown = Duration(hours: 1);

  final Map<String, DateTime> _notifiedAt;

  _RecentNotifications(this._notifiedAt);

  static Future<_RecentNotifications> load() async {
    final storage = StorageService();
    final raw = await storage.loadRaw(_key);
    if (raw == null) return _RecentNotifications({});
    final map = <String, DateTime>{};
    for (final entry in raw.split(';')) {
      if (entry.isEmpty) continue;
      final parts = entry.split(',');
      if (parts.length != 2) continue;
      final ms = int.tryParse(parts[1]);
      if (ms == null) continue;
      map[parts[0]] = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return _RecentNotifications(map);
  }

  bool wasNotifiedRecently(String placeId) {
    final at = _notifiedAt[placeId];
    if (at == null) return false;
    return DateTime.now().difference(at) < _cooldown;
  }

  void markNotified(String placeId) {
    _notifiedAt[placeId] = DateTime.now();
  }

  void clear(String placeId) {
    _notifiedAt.remove(placeId);
  }

  Future<void> save() async {
    final raw = _notifiedAt.entries
        .map((e) => '${e.key},${e.value.millisecondsSinceEpoch}')
        .join(';');
    await StorageService().saveRaw(_key, raw);
  }
}

/// Public helpers used by the main isolate to (un)register the periodic task.
class BackgroundTaskService {
  BackgroundTaskService._();

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      kNearbyCheckTaskUniqueName,
      kNearbyCheckTask,
      frequency: const Duration(minutes: 15), // Android's enforced minimum
      constraints: Constraints(
        networkType: .notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: .keep,
    );
  }

  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(kNearbyCheckTaskUniqueName);
  }
}
