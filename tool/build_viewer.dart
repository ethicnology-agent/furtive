import 'dart:io';

/// Compiles the web viewer and packages it with verified Leaflet assets.
///
/// Same-origin by default, so a self-hosted viewer contacts no third-party
/// tile host. Overriding VIEWER_TILE_URL points the basemap at a public
/// service and discloses the viewed area to it — a deliberate trade,
/// documented in docs/SHARE-TRACKING.md.
Future<void> main(List<String> args) async {
  final tileUrl =
      Platform.environment['VIEWER_TILE_URL'] ?? '/tiles/{z}/{x}/{y}.png';
  final output = args.isNotEmpty ? args.first : 'build/viewer';
  Directory(output).createSync(recursive: true);

  final compiled = await Process.run('dart', [
    'compile',
    'js',
    '-O4',
    '-DTILE_URL=$tileUrl',
    '-o',
    '$output/main.dart.js',
    'apps/viewer/web/main.dart',
  ]);
  stdout.write(compiled.stdout);
  if (compiled.exitCode != 0) {
    stderr.write(compiled.stderr);
    exitCode = compiled.exitCode;
    return;
  }

  final packaged = await Process.run('python3', [
    'tool/package_viewer.py',
    output,
    '--tile-url',
    tileUrl,
  ]);
  stdout.write(packaged.stdout);
  stderr.write(packaged.stderr);
  exitCode = packaged.exitCode;
}
