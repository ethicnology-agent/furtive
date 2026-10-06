/// The seam tests drive this module through.
///
/// Production code must not import this library: it exposes the platform
/// datasource, so a test can stand in for a GPS receiver instead of waiting
/// for one. What a recorder needs is in `package:location/location.dart`.
library;

export 'src/location_gps_data_source.dart';
