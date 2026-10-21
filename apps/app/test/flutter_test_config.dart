import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Flutter's test binding renders text with a placeholder "Ahem" font
/// (deterministic boxes instead of real glyphs) by default — fine for
/// widget assertions, but useless for visually reviewing a design via
/// golden-file screenshots. This loads the app's real bundled font once for
/// every test file in this directory (Flutter auto-discovers
/// flutter_test_config.dart), so golden PNGs show actual Space Grotesk
/// glyphs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final defaultComparator = goldenFileComparator;
  if (defaultComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      defaultComparator.basedir.resolve('flutter_test_config.dart'),
      precisionTolerance: 0.001,
    );
  }
  await _loadFont('SpaceGrotesk', 'assets/fonts/SpaceGrotesk-Variable.ttf');
  await testMain();
}

/// Ignores sub-pixel renderer differences while keeping real layout changes
/// visible.
///
/// The tolerance absorbs antialiasing noise between runs on the same
/// platform. It does **not** absorb the gap between platforms: measured on
/// 2026-10-06, macOS renders this card 0.68% (9930 pixels) away from the
/// committed images for the LTR card and 1.14% for the RTL one, against a
/// 0.1% tolerance. An earlier version of this comment claimed 0.02% (237
/// pixels), which has not been true since the Flutter 3.47 bump.
///
/// The consequence is the part worth keeping: **these goldens are Linux
/// artefacts and the CI is their oracle.** Regenerating them on a
/// development machine replaces a correct image with one that fails there,
/// so `--update-goldens` belongs on a runner, not here.
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         precisionTolerance >= 0 && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> _loadFont(String family, String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}
