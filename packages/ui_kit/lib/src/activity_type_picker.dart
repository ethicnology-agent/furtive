import 'package:activity_profile/activity_profile.dart';
import 'package:flutter/material.dart';

import 'formatting.dart';

/// The icon standing for an activity type.
///
/// A mapping, not a translation: an icon means the same thing in every
/// locale, which is why it lives with the component and the label does not.
IconData activityTypeIcon(ActivityTypeEntity type) => switch (type) {
  ActivityTypeEntity.walk => Icons.directions_walk_rounded,
  ActivityTypeEntity.run => Icons.directions_run_rounded,
  ActivityTypeEntity.bike => Icons.directions_bike_rounded,
  ActivityTypeEntity.car => Icons.directions_car_rounded,
  ActivityTypeEntity.swim => Icons.pool_rounded,
  ActivityTypeEntity.aircraft => Icons.flight_rounded,
  ActivityTypeEntity.other => Icons.explore_rounded,
  ActivityTypeEntity.unknown => Icons.help_outline_rounded,
};

/// Bottom sheet listing every selectable activity, with the current one
/// checked. Returns the chosen type, or null if dismissed.
///
/// A flat list, no grouping: at seven entries the whole set fits on screen and
/// choosing costs a single tap. The categories this used to need were a symptom
/// of the list being too long, not a feature — the previous 25-entry version
/// required a scroll to reach "car".
///
/// [title] and [labelFor] are supplied already translated. The kit owns no
/// localization: what an activity type is called is the caller's knowledge.
Future<ActivityTypeEntity?> showActivityTypePicker(
  BuildContext context, {
  required ActivityTypeEntity selected,
  required String title,
  required String Function(ActivityTypeEntity type) labelFor,
}) {
  return showModalBottomSheet<ActivityTypeEntity>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(horizontal: context.screenPadding),
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          for (final type in selectableActivityTypes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(activityTypeIcon(type)),
              title: Text(labelFor(type)),
              selected: type == selected,
              trailing: type == selected
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    ),
  );
}
