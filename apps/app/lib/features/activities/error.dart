import 'package:diagnostics/diagnostics.dart';

class ActivityNotFoundError extends AppError {
  ActivityNotFoundError() : super('Activity not found');
}
