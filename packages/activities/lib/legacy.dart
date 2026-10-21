/// The one-time bridge out of the pre-1.4 storage layout, and nothing else.
///
/// Deleted with the table it reads, in the release after 1.4 — dropping that
/// table is destructive and belongs to a later release than the one that
/// stopped writing to it.
library;

export 'src/legacy_settings.dart';
