import 'dart:async';

import 'package:activities/activities.dart';

sealed class ActivitiesEvent {
  const ActivitiesEvent();
}

class FetchActivities extends ActivitiesEvent {
  const FetchActivities();
}

class FetchMoreActivities extends ActivitiesEvent {
  const FetchMoreActivities();
}

class ClearActivitiesFeedback extends ActivitiesEvent {
  const ClearActivitiesFeedback();
}

class UpdateActivityName extends ActivitiesEvent {
  const UpdateActivityName({
    required this.activityId,
    required this.newName,
    this.completion,
  });

  final String activityId;
  final String newName;
  final Completer<void>? completion;
}

class DeleteActivity extends ActivitiesEvent {
  const DeleteActivity({required this.activityId, this.completion});

  final String activityId;
  final Completer<void>? completion;
}

/// Puts a just-deleted activity back, exactly as it was.
///
/// Carries the whole entity rather than an id: by the time this is raised
/// the rows are gone, so there is nothing left to look it up from. The page
/// that deleted it is the only place still holding one.
class RestoreActivity extends ActivitiesEvent {
  const RestoreActivity({required this.activity, this.completion});

  final ActivityEntity activity;
  final Completer<void>? completion;
}

class ImportActivityFromGpx extends ActivitiesEvent {
  const ImportActivityFromGpx({required this.filePath});

  final String filePath;
}
