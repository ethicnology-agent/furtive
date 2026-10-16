import 'package:diagnostics/diagnostics.dart';
import 'package:map_view/map_view.dart';

/// How much room the renderer may keep for tiles nobody asked to keep.
///
/// Set because it had never been set: the port exposed the call and nothing
/// called it, so the ambient cache ran at the renderer's own default and a
/// route looked at often was evicted like anything else. The point of the
/// ambient cache is exactly the case this budget protects — someone who has
/// run the same loop all month has already paid for those tiles, and should
/// not have to download them again to run it without a signal.
///
/// 512 MB against a measured 7.0 MB for a 10 km radius at z10-15 in open
/// country, 57.0 MB for the same radius over Paris. Generous on purpose: it
/// is a ceiling, not an allocation, and nothing is written until the map is
/// actually looked at. Areas the user chose to keep are not evictable and do
/// not count against it.
const ambientCacheBudgetBytes = 512 * 1024 * 1024;

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
