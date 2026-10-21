import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reasons the OS recorded for the app's previous process going away.
/// Mirrors a subset of `android.app.ApplicationExitInfo` (API 30+); the
/// numeric [reason] is Android's own constant so it can be cross-referenced
/// against
/// https://developer.android.com/reference/android/app/ApplicationExitInfo
/// without a lookup table on this side.
class ProcessExitReason {
  final int reason;
  final String description;
  final DateTime timestamp;
  final int importance;

  const ProcessExitReason({
    required this.reason,
    required this.description,
    required this.timestamp,
    required this.importance,
  });

  /// Reasons that plausibly explain a recording being cut off without the
  /// user asking for it — the OS/OEM killed the process outright rather than
  /// it exiting cleanly. Used to decide whether this is worth a WARNING
  /// (persisted to the shareable log) instead of routine INFO noise.
  static const _unexpectedReasons = {
    4, // REASON_LOW_MEMORY
    6, // REASON_SIGNALED (native OOM killer / SIGKILL)
    12, // REASON_EXCESSIVE_RESOURCE_USAGE
    11, // REASON_FREEZER (killed while frozen/cached)
    2, // REASON_ANR
  };

  bool get isUnexpectedKill => _unexpectedReasons.contains(reason);

  @override
  String toString() =>
      'ProcessExitReason($description, importance=$importance, '
      'at=${timestamp.toIso8601String()})';
}

/// Diagnostic-only bridge to MainActivity.kt's ApplicationExitInfo lookup.
/// Purely informational: knowing the OS killed the previous process for
/// memory pressure (vs. the user stopping it via the Android 13+ foreground-
/// service Task Manager) cannot bring a lost recording back, but it turns a
/// "my run randomly died" bug report into something diagnosable from the
/// shared log file. See docs/AUDIT-2026-07.md §1.2 [P2-e].
class ProcessExitFacade {
  static const _channel = MethodChannel('app.furtive/diagnostics');

  /// Returns null on any non-Android platform, on API < 30, or if the OS
  /// hasn't recorded an exit reason yet (e.g. first launch after install).
  /// Never throws — a missing/failing platform channel is not worth
  /// surfacing as an app error, this is best-effort diagnostics only.
  Future<ProcessExitReason?> lastExitReason() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'lastExitReason',
      );
      if (result == null) return null;
      return ProcessExitReason(
        reason: result['reason'] as int,
        description: result['description'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          result['timestampMillis'] as int,
        ),
        importance: result['importance'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// What the platform says about location availability, read through both the
/// legacy per-provider API and the modern one.
///
/// `geolocator` decides a device has "location services disabled" with
/// `isProviderEnabled(GPS_PROVIDER) || isProviderEnabled(NETWORK_PROVIDER)`
/// — the question Android has been migrating away from for several releases,
/// towards `FUSED_PROVIDER` and `isLocationEnabled()`. When a user sees the
/// system toggle on and every app still reports location off, those two
/// answers are the only thing that separates "the toggle really is off" from
/// "the library is asking the wrong question".
class LocationProviderDiagnostics {
  static const _channel = MethodChannel('app.furtive/diagnostics');

  /// Opens the system screen holding the location toggle.
  ///
  /// Returns false when the platform refused or there is nothing to open, so
  /// a caller can keep its message on screen rather than pretend it acted.
  static Future<bool> openSettings() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('openLocationSettings') ?? false;
    } on Object {
      return false;
    }
  }

  /// Never throws: this exists to make a log line, not to gate behaviour.
  static Future<String> describe() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return 'not Android';
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'locationProviders',
      );
      if (raw == null) return 'unavailable';
      String flag(Object? v) => v == null ? '?' : '$v';
      return 'isLocationEnabled=${flag(raw['isLocationEnabled'])} '
          'gps=${flag(raw['gps'])} '
          'network=${flag(raw['network'])} '
          'fused=${flag(raw['fused'])} '
          'enabled=${raw['enabledProviders']} '
          'all=${raw['allProviders']}';
    } on Object catch (error) {
      return 'probe failed: $error';
    }
  }
}
