/// Everything the application needs from a map, and nothing else.
///
/// The port's shape was not invented up front: it is what the on-device
/// benchmark had to expose to drive two renderers interchangeably,
/// intersected with what the two screens that show a map actually call.
/// Keeping it means the screens import no rendering library, and a renderer
/// can be measured against another before one is deleted.
///
/// It takes a [MapTrack] rather than a recording. Lines, styles and markers
/// are what a renderer needs; segmenting points by what the recorder was
/// doing, and spacing milestones by distance, belong to whoever owns the
/// recording — and a map module that knew about one could not be shared by
/// two features.
library;

export 'src/geo_circle.dart';
export 'src/km_milestone_chip.dart';
export 'src/offline_tiles.dart';
export 'src/tile_count.dart';
export 'src/map_view.dart';
export 'src/maplibre_map_view.dart';
export 'src/user_location_puck.dart';
