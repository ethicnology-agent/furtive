import 'package:diagnostics/diagnostics.dart';

class ActivityNotStartedError extends AppError {
  ActivityNotStartedError() : super('Activity not started');
}
