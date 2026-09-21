import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:convert/convert.dart';

class DeviceFingerprint {
  static Future<String> generate() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final parts = <String>[];

    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      parts.add(info.brand);
      parts.add(info.model);
      parts.add(info.board);
      parts.add(info.version.release);
      parts.add(info.version.sdkInt.toString());
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      parts.add(info.name);
      parts.add(info.systemName);
      parts.add(info.systemVersion);
      parts.add(info.model);
      parts.add(info.identifierForVendor ?? '');
    }

    final concatenated = parts.join('|');
    final bytes = utf8.encode(concatenated);
    final hashBytes = sha256.convert(bytes).bytes;
    return hex.encode(hashBytes); // 64-char hex
  }
}
