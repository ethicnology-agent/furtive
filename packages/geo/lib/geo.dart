/// The vocabulary every module speaks about place.
///
/// A [PositionEntity] is one GPS fix together with the uncertainties the
/// platform reported alongside it, and [distanceBetween] measures the ground
/// between two of them. Both sit here, below every capability, because
/// activities, location and the basemap all need them and none of them may
/// depend on another.
library;

export 'src/bounds.dart';
export 'src/distance.dart';
export 'src/position.dart';
