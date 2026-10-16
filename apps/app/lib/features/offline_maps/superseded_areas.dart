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
/// deciding what to delete on float equality is not a thing to do. The
/// highest id is the newest and is the one kept.
///
/// An empty key belongs to a region written by a build that did not set one.
/// It matches nothing, so such a region is never swept up by a download of
/// an area that happens to be elsewhere.
List<int> supersededAreaIds(List<OfflineArea> areas, String key) {
  if (key.isEmpty) return const [];
  final mine = [
    for (final area in areas)
      if (area.key == key) area.id,
  ]..sort();
  // Fewer than two means there is nothing superseded — and guards the
  // subtraction below, which would otherwise ask for a negative count.
  if (mine.length < 2) return const [];
  return mine.sublist(0, mine.length - 1);
}
