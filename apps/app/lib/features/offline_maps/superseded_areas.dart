import 'package:map_view/map_view.dart';

/// The ids of the areas a just-finished download has made redundant.
///
/// The renderer has no resume. Asking for an area again creates a second
/// region that reuses the tiles the first one already stored — measured: an
/// interrupted 25 km download followed by the same request again finished in
/// 23 s against 40 s cold, and left two regions. Finishing an interrupted
/// download therefore means asking again, and the leftover has to be
/// recognised afterwards, because no region reports whether it is complete.
///
/// Identity is the [OfflineArea.key] the caller wrote at creation, not the
/// bounds: bounds come back through a platform channel as doubles, and
/// deciding what to delete on float equality is not a thing to do.
///
/// [keepId] is the region the download just finished into, and it is kept
/// explicitly. An earlier version kept the highest id instead, which holds
/// only where ids rise with time: the iOS implementation derives them from a
/// timestamp hash, so the finished download could have been the one deleted.
///
/// An empty key belongs to a region written by a build that did not set one.
/// It matches nothing, so such a region is never swept up by a download of
/// an area that happens to be elsewhere.
List<int> supersededAreaIds(
  List<OfflineArea> areas,
  String key, {
  required int? keepId,
}) {
  if (key.isEmpty) return const [];
  final mine = [
    for (final area in areas)
      if (area.key == key) area.id,
  ];
  // Without a surviving id there is nothing to measure the others against,
  // and deleting all of them would throw away the download that just
  // finished.
  if (keepId == null || !mine.contains(keepId)) return const [];
  return [
    for (final id in mine)
      if (id != keepId) id,
  ]..sort();
}
