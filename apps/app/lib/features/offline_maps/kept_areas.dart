import 'package:map_view/map_view.dart';

/// One area the user asked for, whatever number of regions the renderer
/// stored it as.
class KeptArea {
  const KeptArea({
    required this.key,
    required this.name,
    required this.regionIds,
  });

  /// The identity the request was made under, or empty for a region kept by
  /// a build that wrote none.
  final String key;

  final String name;

  /// Every region holding part of this area. More than one means the
  /// download was interrupted and asked for again.
  final List<int> regionIds;
}

/// Collapses the renderer's regions into the areas that were asked for.
///
/// There is no resume: each retry of an interrupted download creates another
/// region with the same identity, and the leftovers are only swept when a
/// download finishes. A download that never finishes — a country is larger
/// than the renderer plugin survives today — therefore leaves one region per
/// attempt, and listing regions showed the same area several times over,
/// each row repeating the one cost recorded against that identity.
///
/// A region from a build that wrote no identity cannot be grouped with
/// anything, so each stays its own row rather than being merged with every
/// other unidentified region.
List<KeptArea> keptAreas(List<OfflineArea> areas) {
  final grouped = <String, List<OfflineArea>>{};
  final ungrouped = <OfflineArea>[];
  for (final area in areas) {
    if (area.key.isEmpty) {
      ungrouped.add(area);
    } else {
      grouped.putIfAbsent(area.key, () => []).add(area);
    }
  }
  return [
    for (final entry in grouped.entries)
      KeptArea(
        key: entry.key,
        // They were all asked for under one name; the first is as good as
        // any, and they only differ if an older build named it otherwise.
        name: entry.value.first.name,
        regionIds: [for (final a in entry.value) a.id]..sort(),
      ),
    for (final area in ungrouped)
      KeptArea(key: '', name: area.name, regionIds: [area.id]),
  ];
}
