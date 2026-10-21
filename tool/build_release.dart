import 'dart:io';

/// Builds the release artefact inside the pinned container.
///
/// Every input that reaches the build is read here rather than passed in by a
/// caller, so a local invocation and a CI one assemble the same command. Pass
/// --dry-run to print that command without running anything.
///
/// Environment:
///   CONTAINER            podman (default) or docker
///   MODE                 release (default) or debug
///   FORMAT               apk (default) or aab
///   GRADLE_HEAP          JVM heap for Gradle inside the container (4g)
///   SOURCE_DATE_EPOCH    pinned timestamp; defaults to the source commit so
///                        Gradle, AGP and the Kotlin compiler emit
///                        deterministic timestamps
///   PROTOMAPS_KEY, PROTOMAPS_URL, SHARE_VIEWER_URL, SHARE_RELAYS
///                        forwarded as --dart-define only when non-empty, so
///                        an unset secret produces the FOSS build rather than
///                        an empty define
Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final environment = Platform.environment;
  final container = _value(environment['CONTAINER']) ?? 'podman';
  final mode = _value(environment['MODE']) ?? 'release';
  final format = _value(environment['FORMAT']) ?? 'apk';
  final heap = _value(environment['GRADLE_HEAP']) ?? '4g';
  if (mode != 'release' && mode != 'debug') {
    stderr.writeln('MODE must be release or debug, got "$mode".');
    exitCode = 64;
    return;
  }
  if (format != 'apk' && format != 'aab') {
    stderr.writeln('FORMAT must be apk or aab, got "$format".');
    exitCode = 64;
    return;
  }

  final flutterVersion = _flutterVersion();
  final gradle = _gradleProperties();
  final epoch = _value(environment['SOURCE_DATE_EPOCH']) ?? _sourceDateEpoch();

  final defines = <String>[
    for (final name in const [
      'PROTOMAPS_KEY',
      'PROTOMAPS_URL',
      'SHARE_VIEWER_URL',
      'SHARE_RELAYS',
    ])
      if (_value(environment[name]) case final value?)
        '--dart-define=$name=$value',
  ];

  final build = format == 'aab'
      ? 'fvm flutter build appbundle --$mode'
      : 'fvm flutter build apk --$mode';
  final containerOutput = format == 'aab'
      ? '/app/apps/app/build/app/outputs/bundle/$mode/app-$mode.aab'
      : '/app/apps/app/build/app/outputs/flutter-apk/app-$mode.apk';
  final hostOutput = './app-$mode.$format';

  final steps = <List<String>>[
    [
      container,
      'build',
      '-f',
      'Containerfile.tools',
      '-t',
      'furtive-tools',
      '--build-arg',
      'FLUTTER_VERSION=$flutterVersion',
      '--build-arg',
      'JVM_TARGET=${gradle['android.jvmTarget']}',
      '--build-arg',
      'ANDROID_API_LEVEL=${gradle['android.compileSdk']}',
      '--build-arg',
      'ANDROID_BUILD_TOOLS=${gradle['android.buildToolsVersion']}',
      '--build-arg',
      'ANDROID_NDK=${gradle['android.ndkVersion']}',
      '.',
    ],
    [
      container,
      'build',
      '-f',
      'Containerfile.app',
      '-t',
      'furtive-app',
      '--build-arg',
      'GRADLE_HEAP=$heap',
      '.',
    ],
    [
      container,
      'run',
      '--name',
      'furtive-build',
      '--ulimit',
      'nofile=65536:65536',
      '-e',
      'SOURCE_DATE_EPOCH=$epoch',
      'furtive-app',
      'bash',
      '-c',
      'cd /app/apps/app && $build ${defines.join(' ')}'.trimRight(),
    ],
    [container, 'cp', 'furtive-build:$containerOutput', hostOutput],
  ];

  if (dryRun) {
    stdout.writeln('$container rm -f furtive-build  # ignoring failure');
    for (final step in steps) {
      stdout.writeln(step.map(_quote).join(' '));
    }
    stdout.writeln('$container rm furtive-build');
    stdout.writeln('sha256 $hostOutput');
    return;
  }

  stdout.writeln('🔨 Building $format ($mode) via $container');
  stdout.writeln('   SOURCE_DATE_EPOCH=$epoch');
  // A container left behind by an interrupted build would make `run --name`
  // fail; removing it is expected to fail when there is none.
  await Process.run(container, ['rm', '-f', 'furtive-build']);
  for (final step in steps) {
    final result = await Process.start(
      step.first,
      step.skip(1).toList(),
      mode: ProcessStartMode.inheritStdio,
    );
    final status = await result.exitCode;
    if (status != 0) {
      exitCode = status;
      return;
    }
  }
  await Process.run(container, ['rm', 'furtive-build']);
  stdout.writeln('✅ Output extracted: $hostOutput');
  stdout.writeln(await sha256(hostOutput));
}

/// The makefile shelled out to sha256sum or shasum; keep that, so the digest
/// printed here is the one a reader can reproduce by hand.
Future<String> sha256(String path) async {
  for (final tool in const ['sha256sum', 'shasum']) {
    final result = await Process.run(tool, [
      if (tool == 'shasum') ...['-a', '256'],
      path,
    ]);
    if (result.exitCode == 0) return (result.stdout as String).trim();
  }
  throw StateError('Neither sha256sum nor shasum is available.');
}

String? _value(String? raw) {
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

String _quote(String argument) =>
    argument.contains(' ') ? "'$argument'" : argument;

String _flutterVersion() {
  final source = File('.fvmrc').readAsStringSync();
  final match = RegExp(r'"flutter"\s*:\s*"([^"]+)"').firstMatch(source);
  if (match == null) throw StateError('.fvmrc declares no Flutter version.');
  return match.group(1)!;
}

Map<String, String> _gradleProperties() {
  final entries = <String, String>{};
  for (final line in File(
    'apps/app/android/gradle.properties',
  ).readAsLinesSync()) {
    final index = line.indexOf('=');
    if (index <= 0 || line.trimLeft().startsWith('#')) continue;
    entries[line.substring(0, index).trim()] = line.substring(index + 1).trim();
  }
  return entries;
}

String _sourceDateEpoch() {
  final result = Process.runSync('git', ['log', '-1', '--format=%ct']);
  if (result.exitCode != 0) return '0';
  return (result.stdout as String).trim();
}
