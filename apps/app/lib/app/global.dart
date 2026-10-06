import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Global {
  static const maxZoom = 18.0;
  static const defaultZoom = 12.0;

  static late PackageInfo app;
  static AndroidDeviceInfo? android;
  static IosDeviceInfo? ios;

  static Future<void> init() async {
    app = await PackageInfo.fromPlatform();
    if (Platform.isAndroid) {
      android = await DeviceInfoPlugin().androidInfo;
    } else if (Platform.isIOS) {
      ios = await DeviceInfoPlugin().iosInfo;
    }
  }

  /// The environment header the diagnostic log opens with.
  ///
  /// Supplied to the log rather than read by it: the build and device facts
  /// below come from platform plugins, which a diagnostic module has no
  /// business depending on, and deciding what is safe to record belongs with
  /// whoever knows what each field contains.
  static List<String> diagnosticContext() {
    final lines = [
      'Version: ${app.version}+${app.buildNumber}',
      'Signature: ${app.buildSignature}',
    ];
    if (Platform.isAndroid) {
      final a = android!;
      lines.addAll([
        'Manufacturer: ${a.manufacturer}',
        'Brand: ${a.brand}',
        'Model: ${a.model}',
        'Device: ${a.device}',
        'Android: ${a.version.release}',
        'Sdk: ${a.version.sdkInt}',
      ]);
    } else if (Platform.isIOS) {
      final i = ios!;
      lines.addAll([
        'Model: ${i.model}',
        'Model Name: ${i.modelName}',
        // i.name is the user-assigned device name ("Jane's iPhone") — personal
        // data. Deliberately not logged so exported logs carry no PII.
        'System Name: ${i.systemName}',
        'System Version: ${i.systemVersion}',
        'UTS Version: ${i.utsname.version}',
        'UTS Release: ${i.utsname.release}',
        'UTS Machine: ${i.utsname.machine}',
        'iOS App on Mac: ${i.isiOSAppOnMac}',
      ]);
    }
    return lines;
  }
}
