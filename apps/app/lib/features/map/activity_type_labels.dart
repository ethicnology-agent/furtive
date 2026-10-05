import 'package:activity_profile/activity_profile.dart';
import 'package:furtive/l10n/app_localizations.dart';

/// What each activity type is called, in the reader's language.
///
/// The picker and the recording controls render the type; naming it is this
/// application's knowledge, so the translation stays here and the component
/// in ui_kit receives the result.
String activityTypeName(AppLocalizations l10n, ActivityTypeEntity type) =>
    switch (type) {
      ActivityTypeEntity.walk => l10n.activityWalk,
      ActivityTypeEntity.run => l10n.activityRun,
      ActivityTypeEntity.bike => l10n.activityBike,
      ActivityTypeEntity.car => l10n.activityCar,
      ActivityTypeEntity.swim => l10n.activitySwim,
      ActivityTypeEntity.aircraft => l10n.activityAircraft,
      ActivityTypeEntity.other => l10n.activityOther,
      ActivityTypeEntity.unknown => l10n.activityUnknown,
    };
