/// The vocabulary every module speaks about place.
///
/// A [PositionEntity] is one GPS fix together with the uncertainties the
/// platform reported alongside it. It sits here, below every capability,
/// because activities, location and the basemap all need it and none of them
/// may depend on another.
library;

export 'src/position.dart';
