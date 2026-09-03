import 'dart:math' as math;

/// Great-circle distance between two lat/lng points using the Haversine
/// formula. This is what geofencing libraries (including geofencing_api)
/// use internally — implemented here explicitly so it can be reused for the
/// WorkManager-based background checker and for showing "X m away" in the UI.
class DistanceUtils {
  DistanceUtils._();

  /// Mean Earth radius in meters (6371 km). Earth isn't a perfect sphere
  /// (~6356 km at the poles, ~6378 km at the equator) but 6371 km is the
  /// standard approximation and is accurate enough for a ~50-100 m geofence.
  static const double earthRadiusMeters = 6371000;

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Returns the distance in meters between (latA, lngA) and (latB, lngB).
  ///
  /// hav(Θ) = hav(φB - φA) + cos(φA)·cos(φB)·hav(λB - λA)
  /// d = r × Θ, where Θ = 2·asin(√hav(Θ))
  static double haversineMeters({
    required double latA,
    required double lngA,
    required double latB,
    required double lngB,
  }) {
    final phiA = _degToRad(latA);
    final phiB = _degToRad(latB);
    final deltaPhi = _degToRad(latB - latA);
    final deltaLambda = _degToRad(lngB - lngA);

    // hav(x) = sin²(x/2)
    final havDeltaPhi = math.pow(math.sin(deltaPhi / 2), 2);
    final havDeltaLambda = math.pow(math.sin(deltaLambda / 2), 2);

    final havTheta =
        havDeltaPhi + math.cos(phiA) * math.cos(phiB) * havDeltaLambda;

    // Clamp for floating point safety before sqrt/asin (havTheta should be
    // in [0, 1], but rounding can push it a hair outside).
    final clamped = havTheta.clamp(0.0, 1.0);
    final theta = 2 * math.asin(math.sqrt(clamped));

    return earthRadiusMeters * theta;
  }

  static bool isWithinRadius({
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
  }) {
    final d = haversineMeters(
      latA: currentLat,
      lngA: currentLng,
      latB: targetLat,
      lngB: targetLng,
    );
    return d <= radiusMeters;
  }
}
