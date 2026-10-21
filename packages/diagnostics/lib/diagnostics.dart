/// Diagnostic logging for the application and its modules.
///
/// Every record is sanitized, written to a single rotating TSV file, and
/// mirrored to the console in debug builds. The file is the only diagnostic
/// surface: the in-app Logs page reads it, so a session can be reconstructed
/// without a computer attached.
library;

export 'src/errors.dart';
export 'src/logs.dart';
