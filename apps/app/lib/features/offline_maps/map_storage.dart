import 'dart:io';

import 'package:diagnostics/diagnostics.dart';
import 'package:map_view/map_view.dart';
import 'package:path_provider/path_provider.dart';

/// How much room the renderer may keep for tiles nobody asked to keep.
///
/// Set because it had never been set: the port exposed the call and nothing
/// called it, so the ambient cache ran at the renderer's own default and a
/// route looked at often was evicted like anything else. The point of the
/// ambient cache is exactly the case this budget protects — someone who has
/// run the same loop all month has already paid for those tiles, and should
/// not have to download them again to run it without a signal.
///
/// 1 GB against a measured 7.0 MB for a 10 km radius at z10-15 in open
/// country, 57.0 MB for the same radius over Paris. Generous on purpose: it
/// is a ceiling, not an allocation, and nothing is written until the map is
/// actually looked at. Areas the user chose to keep are not evictable and do
/// not count against it.
///
/// A ceiling at all, rather than none, because the cache fills without ever
/// being asked for: no limit would let a map quietly take the device's last
/// gigabytes. One that is effectively unreachable in ordinary use, paired
/// with a screen that shows the figure and a way to throw it away, leaves
/// the decision with whoever owns the phone.
const ambientCacheBudgetBytes = 1024 * 1024 * 1024;

/// Everything the renderer has stored for the map, in bytes, or null when it
/// has stored nothing yet.
///
/// Read from the database file rather than asked of the renderer, because the
/// renderer will not say: `OfflineRegion` carries no size, and nothing
/// reports the ambient cache at all. The path is MapLibre's own, confirmed on
/// an Android 12 device — a 1,313-tile download that reported 7,026,194 bytes
/// left a 7,766,016-byte file at this path, the difference being the
/// database's own overhead.
///
/// That difference is the reason this returns one number and not a split:
/// subtracting what was deliberately downloaded would charge SQLite's
/// overhead to the browsing cache and report megabytes of it on a device
/// that has never browsed.
Future<int?> mapStorageBytes() async {
  try {
    final support = await getApplicationSupportDirectory();
    final file = File('${support.path}/mbgl-offline.db');
    return await file.exists() ? await file.length() : null;
  } on Object {
    // A monitor that cannot read the file has nothing to say about it. It is
    // not worth failing the screen it is shown on.
    return null;
  }
}

/// Where the record of what each kept area cost is written.
///
/// Beside the renderer's own database rather than in the documents
/// directory: it is bookkeeping about that file, worthless without it, and
/// the two should be cleared together.
Future<File> offlineLedgerFile() async {
  final support = await getApplicationSupportDirectory();
  return File('${support.path}/offline_areas.json');
}

/// Gives the renderer its ambient cache budget for this process.
///
/// At startup rather than when the offline screen opens, because the people
/// this helps are exactly the ones who never open it: the budget has to be
/// in force while they are simply using the map, or the tiles it is meant to
/// keep have already been evicted by the time anyone asks.
///
/// Failure is not reported to the user. There is nothing they could do, and
/// the consequence is only that the renderer falls back to its own smaller
/// default.
Future<void> applyAmbientCacheBudget() async {
  if (!OfflineTiles.isSupported) return;
  OfflineTiles? tiles;
  try {
    tiles = await OfflineTiles.create();
    await tiles.setMaximumCacheSize(ambientCacheBudgetBytes);
    logs.config('Ambient map cache budget: $ambientCacheBudgetBytes B');
  } on Object catch (error, stack) {
    logs.warning('Ambient map cache budget', error: error, trace: stack);
  } finally {
    tiles?.dispose();
  }
}
