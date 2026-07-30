import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceService {
  static final _plugin = DeviceInfoPlugin();

  /// Returns a map that is sent to the login API for audit logging.
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        return {
          'device_name':  '${info.manufacturer} ${info.model}',
          'device_model': info.model,
          'os':           'Android ${info.version.release}',
        };
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return {
          'device_name':  info.name,
          'device_model': info.model,
          'os':           'iOS ${info.systemVersion}',
        };
      }
    } catch (_) {}
    return {'device_name': 'flutter_app', 'device_model': 'Unknown', 'os': 'Unknown'};
  }

  /// Requests storage permission and returns whether it was granted.
  /// Shows a rationale dialog before requesting if needed.
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions; Android ≤12 uses storage
      final sdkInt = await _androidSdkVersion();
      if (sdkInt >= 33) {
        final results = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
        return results.values.every((s) => s.isGranted || s.isLimited);
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // iOS handles storage differently (no explicit permission needed for app documents)
  }

  /// Requests location permission for geo-tagging login sessions.
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  static Future<int> _androidSdkVersion() async {
    try {
      final info = await _plugin.androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 0;
    }
  }
}
