import 'package:activity_profile/activity_profile.dart';
import 'local_database.dart';
import 'activity_points_table.dart';
import 'activities_table.dart';
import 'activity_entity.dart';
import 'package:geo/geo.dart';

class ActivityModel {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final ActivityTypeColumn activityType;

  final List<ActivityPointModel> points;

  ActivityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.createdAt,
    required this.startedAt,
    required this.stoppedAt,
    this.activityType = ActivityTypeColumn.unknown,
  });

  static ActivityModel fromEntity(ActivityEntity entity) {
    return ActivityModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      createdAt: entity.createdAt,
      startedAt: entity.startedAt,
      stoppedAt: entity.stoppedAt,
      activityType: ActivityTypeExtension.fromEntity(entity.activityType),
      points: entity.points
          .map(
            (point) => ActivityPointModel(
              latitude: point.position.latitude,
              longitude: point.position.longitude,
              elevation: point.position.elevation,
              time: point.time,
              status: ActivityPointsStatusColumn.fromEntity(point.status),
              accuracy: point.position.accuracy,
              verticalAccuracy: point.position.verticalAccuracy,
            ),
          )
          .toList(),
    );
  }

  static ActivityEntity toEntity(ActivityModel model) {
    return ActivityEntity(
      id: model.id,
      name: model.name,
      description: model.description,
      createdAt: model.createdAt,
      startedAt: model.startedAt,
      stoppedAt: model.stoppedAt,
      activityType: model.activityType.toEntity(),
      points: model.points
          .map(
            (point) => ActivityPointEntity(
              position: PositionEntity(
                latitude: point.latitude,
                longitude: point.longitude,
                elevation: point.elevation,
                accuracy: point.accuracy,
                verticalAccuracy: point.verticalAccuracy,
              ),
              time: point.time,
              status: point.status.toEntity(),
            ),
          )
          .toList(),
    );
  }

  static ActivityModel fromDatabase(
    ActivitiesRow row,
    List<ActivityPointsRow> points,
  ) {
    return ActivityModel(
      id: row.id,
      name: row.name,
      description: row.description,
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      stoppedAt: row.stoppedAt,
      activityType: row.activityType,
      points: points.map(ActivityPointModel.fromDatabase).toList(),
    );
  }
}

class ActivityPointModel {
  final double latitude;
  final double longitude;
  final double elevation;
  final DateTime time;
  final ActivityPointsStatusColumn status;
  final double? accuracy;
  final double? verticalAccuracy;

  ActivityPointModel({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.time,
    required this.status,
    this.accuracy,
    this.verticalAccuracy,
  });

  static ActivityPointModel fromEntity(ActivityPointEntity entity) {
    return ActivityPointModel(
      latitude: entity.position.latitude,
      longitude: entity.position.longitude,
      elevation: entity.position.elevation,
      time: entity.time,
      status: ActivityPointsStatusColumn.fromEntity(entity.status),
      accuracy: entity.position.accuracy,
      verticalAccuracy: entity.position.verticalAccuracy,
    );
  }

  static ActivityPointEntity toEntity(ActivityPointModel model) {
    return ActivityPointEntity(
      position: PositionEntity(
        latitude: model.latitude,
        longitude: model.longitude,
        elevation: model.elevation,
        accuracy: model.accuracy,
        verticalAccuracy: model.verticalAccuracy,
      ),
      time: model.time,
      status: model.status.toEntity(),
    );
  }

  static ActivityPointModel fromDatabase(ActivityPointsRow row) {
    return ActivityPointModel(
      latitude: row.latitude,
      longitude: row.longitude,
      elevation: row.elevation,
      time: row.time,
      status: row.status,
      accuracy: row.accuracy,
      verticalAccuracy: row.verticalAccuracy,
    );
  }
}

/// Storage <-> domain mapping for the activity taxonomy. Written out rather
/// than matched on `name` so adding a value on one side without the other is a
/// compile error, not a runtime surprise on someone's stored data.
extension ActivityTypeExtension on ActivityTypeColumn {
  static ActivityTypeColumn fromEntity(ActivityTypeEntity type) =>
      switch (type) {
        ActivityTypeEntity.walk => ActivityTypeColumn.walk,
        ActivityTypeEntity.run => ActivityTypeColumn.run,
        ActivityTypeEntity.bike => ActivityTypeColumn.bike,
        ActivityTypeEntity.car => ActivityTypeColumn.car,
        ActivityTypeEntity.swim => ActivityTypeColumn.swim,
        ActivityTypeEntity.aircraft => ActivityTypeColumn.aircraft,
        ActivityTypeEntity.other => ActivityTypeColumn.other,
        ActivityTypeEntity.unknown => ActivityTypeColumn.unknown,
      };

  ActivityTypeEntity toEntity() => switch (this) {
    ActivityTypeColumn.walk => ActivityTypeEntity.walk,
    ActivityTypeColumn.run => ActivityTypeEntity.run,
    ActivityTypeColumn.bike => ActivityTypeEntity.bike,
    ActivityTypeColumn.car => ActivityTypeEntity.car,
    ActivityTypeColumn.swim => ActivityTypeEntity.swim,
    ActivityTypeColumn.aircraft => ActivityTypeEntity.aircraft,
    ActivityTypeColumn.other => ActivityTypeEntity.other,
    ActivityTypeColumn.unknown => ActivityTypeEntity.unknown,
  };
}
