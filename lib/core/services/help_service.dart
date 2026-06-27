import 'dart:io';

import 'package:path/path.dart' as p;

/// Opens bundled user manuals and log folder on Windows.
class HelpService {
  HelpService._();

  static String _exeDir() => File(Platform.resolvedExecutable).parent.path;

  static Future<void> openUserManual({String locale = 'ar'}) async {
    final fileName = switch (locale) {
      'en' => 'Mada_POS_User_Manual_EN.pdf',
      'ku' => 'Mada_POS_User_Manual_KU.pdf',
      _ => 'Mada_POS_User_Manual_AR.pdf',
    };
    final path = p.join(_exeDir(), 'docs', fileName);
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('manual-not-found');
    }
    await _openPath(path);
  }

  static Future<void> openLogsFolder() async {
    final base = Platform.environment['LOCALAPPDATA'] ?? _exeDir();
    final dir = Directory(p.join(base, 'Mada_POS', 'logs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _openPath(dir.path);
  }

  static Future<void> _openPath(String path) async {
    if (!Platform.isWindows) return;
    await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
  }
}
