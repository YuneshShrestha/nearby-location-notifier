import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geofencing_api/geofencing_api.dart';

import '../models/place.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Entry point the OS uses to spawn/re-attach the background isolate that
/// backs the foreground service. Must stay a top-level function annotated
/// with vm:entry-point.
@pragma('vm:entry-point')
void startCallback() {
  print("Foreground service startedtt");
  FlutterForegroundTask.setTaskHandler(GeofencingTaskHandler());
}

/// Runs inside the foreground service's isolate for as long as its
/// notification is showing. This is what lets monitoring keep working after
/// the app is swiped from recents — geofencing_api itself has no background
/// capability of its own, it only watches location "while alive", so this
/// handler's whole job is to keep it alive and re-sync it with whatever
/// places are currently saved.
///
/// NOTE: flutter_foreground_task's TaskHandler method signatures have
/// changed across major versions (v6/v7 used onStart/onEvent with a
/// SendPort; v8 uses onStart/onRepeatEvent with a TaskStarter and adds
/// notification-interaction callbacks). This targets the v8 shape — check
/// against the version pub resolves and adjust if it doesn't match.
class GeofencingTaskHandler extends TaskHandler {
  List<Place> _activePlaces = [];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    print('GeofencingTaskHandler.onStart: $timestamp');

    await _syncPlaces();

    Geofencing.instance.setup(
      interval: 10000, // how often location is polled, ms
      accuracy: 100, // meters
      statusChangeDelay: 10000,
      allowsMockLocation: true,
      printsDebugLog: false,
    );

    Geofencing.instance.addGeofenceStatusChangedListener(
      _onGeofenceStatusChanged,
    );
    Geofencing.instance.addGeofenceErrorCallbackListener(_onGeofenceError);

    await Geofencing.instance.start(regions: _buildRegions(_activePlaces));
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // The task handler runs in its own isolate with no shared memory, so we
    // re-read the place list from disk on every repeat tick (interval set
    // via ForegroundTaskOptions in ForegroundGeofenceController) to notice
    // additions/removals/toggles made from the UI.
    _syncPlaces();
  }

  Future<void> _syncPlaces() async {
    final all = await StorageService().loadPlaces();
    final active = all.where((p) => p.active).toList();

    final changed = !_sameIds(active, _activePlaces);
    _activePlaces = active;

    if (changed) {
      Geofencing.instance.clearAllRegions();
      if (_activePlaces.isNotEmpty) {
        Geofencing.instance.addRegions(_buildRegions(_activePlaces));
      }
    }
  }

  bool _sameIds(List<Place> a, List<Place> b) {
    final idsA = a.map((p) => p.id).toSet();
    final idsB = b.map((p) => p.id).toSet();
    return idsA.length == idsB.length && idsA.containsAll(idsB);
  }

  Set<GeofenceRegion> _buildRegions(List<Place> places) {
    return places
        .map(
          (p) => GeofenceRegion.circular(
            id: p.id,
            data: {'name': p.name},
            center: LatLng(p.latitude, p.longitude),
            // geofencing_api requires radius >= 10m.
            radius: p.radiusMeters < 10 ? 10 : p.radiusMeters,
          ),
        )
        .toSet();
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion geofenceRegion,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    if (geofenceStatus == GeofenceStatus.enter) {
      final data = geofenceRegion.data;
      final name = data is Map
          ? data['name'] as String? ?? geofenceRegion.id
          : geofenceRegion.id;
      await NotificationService.instance.showNearby(name);
    }
  }

  void _onGeofenceError(Object error, StackTrace stackTrace) {
    // A transient geofencing error shouldn't crash the foreground service —
    // the next onRepeatEvent tick will keep things going.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    Geofencing.instance.removeGeofenceStatusChangedListener(
      _onGeofenceStatusChanged,
    );
    Geofencing.instance.removeGeofenceErrorCallbackListener(_onGeofenceError);
    await Geofencing.instance.stop();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}
}
