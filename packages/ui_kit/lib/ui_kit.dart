/// The application's theme and the components more than one screen renders.
///
/// A component belongs here when it carries a product decision — the two
/// densities of [StatBlock] and its rule of one emphasised value per group,
/// the deliberate override [LabeledDropdown] makes to the global input
/// theme — rather than merely because it is reusable. The kit sits below
/// every feature so a styling decision is made once.
library;

export 'src/activity_stats.dart';
export 'src/activity_type_picker.dart';
export 'src/formatting.dart';
export 'src/labeled_dropdown.dart';
export 'src/snack_bar.dart';
export 'src/stat_block.dart';
export 'src/theme.dart';
