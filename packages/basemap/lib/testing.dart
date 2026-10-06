/// The seam tests drive this module through.
///
/// Production code must not import this library: it exposes the remote
/// datasource so a test can answer for the tile host instead of reaching it.
library;

export 'src/map_remote_data_source.dart';
