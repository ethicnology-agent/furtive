import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/database/local_database.dart';
import 'package:furtive/core/locator.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/features/permissions/bloc/permissions_bloc.dart';
import 'package:furtive/features/permissions/pages/permissions_page.dart';
import 'package:furtive/features/permissions/permission_entity.dart';
import 'package:furtive/features/permissions/permission_repository.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class _GrantedPermissions extends PermissionRepository {
  @override
  Future<List<PermissionEntity>> getPermissions() async => [
    PermissionEntity(
      name: 'Location',
      description: '',
      permission: Permission.locationWhenInUse,
      isGranted: true,
      isPermanentlyDenied: false,
      isOptional: false,
    ),
  ];
}

void main() {
  testWidgets('Continue returns to the existing settings route', (
    tester,
  ) async {
    final db = LocalDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<LocalDatabase>(db);
    final bloc = PermissionsBloc(permissions: _GrantedPermissions());
    addTearDown(() async {
      await bloc.close();
      await getIt.unregister<LocalDatabase>();
      await db.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open permissions'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: const PermissionsPage(returnToSettings: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open permissions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Open permissions').hitTestable(), findsOneWidget);
    expect(find.byType(PermissionsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
