/// Which basemap style the map should load, in the reader's language, or
/// none at all.
///
/// None is a first-class answer, not a failure. A build compiled without a
/// tile key renders a functional, tileless map, and a user who has turned
/// tiles off gets exactly the same thing from a build that has one: every
/// tile request discloses the viewport, and therefore an approximation of
/// where someone is, to whoever serves it.
library;

export 'src/get_map_style_url_use_case.dart';
