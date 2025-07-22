import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> getReceivedFilesDir() async {
  if (Platform.isAndroid) {
    String rootPath = '/storage/emulated/0';
    String packageName = 'com.airchat.app';
    String path = '$rootPath/Android/media/$packageName/AirChat';
    final dir = Directory(path);
    final sendDir = Directory('$path/sent');
    if (!await dir.exists()) await dir.create(recursive: true);
    if (!await sendDir.exists()) await sendDir.create(recursive: true);
    // Create .nomedia file in sent directory
    final nomediaFile = File('${sendDir.path}/.nomedia');
    if (!await nomediaFile.exists()) {
      await nomediaFile.create();
    }
    return path;
  } else if (Platform.isIOS) {
    // Use app document directory for mobile
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Use user's home directory for desktop
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return p.join(home, 'airchat');
  } else {
    // Fallback to current directory
    return './received_files';
  }
}
