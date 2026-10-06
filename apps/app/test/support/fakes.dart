import 'package:drift/native.dart';
import 'package:activities/testing.dart';

/// Hand-written fakes, deliberately not generated mocks.
///
/// The seams Phase 2 introduced are few and narrow (GPS, clock, database), so
/// explicit fakes read better than generated ones, need no build step, and never
/// silently stub a method the production code started depending on.
///
/// The GPS ones travel with the module that owns that seam; see
/// `package:location/testing.dart`.

/// In-memory database, ready to hand to any datasource's `db:` parameter.
LocalDatabase inMemoryDatabase() =>
    LocalDatabase.forTesting(NativeDatabase.memory());
