import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';

/// Persists the user's list of fixed places entirely on-device.
/// No backend involved: everything lives in SharedPreferences as JSON.
class StorageService {
  static const _placesKey = 'nearby_notifier.places';

  Future<List<Place>> loadPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_placesKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlaces(List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(places.map((p) => p.toJson()).toList());
    await prefs.setString(_placesKey, raw);
  }

  /// Generic string get/set, used by BackgroundTaskService to persist small
  /// bits of state (like "recently notified" bookkeeping) without needing a
  /// dedicated storage key per feature.
  Future<String?> loadRaw(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> saveRaw(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
