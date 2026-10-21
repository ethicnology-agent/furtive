/// What the application has to ask the host operating system for.
///
/// Each of these wraps something Dart cannot do by itself: a platform
/// channel, or a directory whose meaning only the OS knows. They are
/// gathered because they share that contract, not because they are
/// otherwise alike — and each is a no-op on the platforms where the question
/// does not apply, so a caller never has to ask which one it is on.
library;

export 'src/backup_exclusion_facade.dart';
export 'src/file_system_facade.dart';
export 'src/lock_screen_facade.dart';
export 'src/process_exit_facade.dart';
