import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Installs bundled Windows runtimes on first launch (VC++ and .NET 4.8).
class WindowsPrerequisites {
  WindowsPrerequisites._();

  static const _markerVersion = 'v1';
  static const _successExitCodes = {0, 1638, 3010};

  static Future<void> ensureInstalled() async {
    if (!Platform.isWindows) return;

    final marker = await _markerFile();
    if (await marker.exists()) return;

    final redistDir = Directory(p.join(_executableDir(), 'redist'));
    if (!await redistDir.exists()) {
      await _writeMarker(marker);
      return;
    }

    debugPrint('Mada Smart POS: checking Windows prerequisites...');

    final vcRedist = File(p.join(redistDir.path, 'vc_redist.x64.exe'));
    if (await vcRedist.exists()) {
      await _runInstaller(vcRedist.path, const ['/install', '/quiet', '/norestart']);
    }

    final dotNetWeb = File(p.join(redistDir.path, 'ndp48-web.exe'));
    if (await dotNetWeb.exists()) {
      await _runInstaller(dotNetWeb.path, const ['/q', '/norestart']);
    }

    final dotNetOffline = File(p.join(redistDir.path, 'ndp48-x86-x64-allos-enu.exe'));
    if (await dotNetOffline.exists()) {
      await _runInstaller(dotNetOffline.path, const ['/q', '/norestart']);
    }

    await _writeMarker(marker);
  }

  static String _executableDir() {
    return File(Platform.resolvedExecutable).parent.path;
  }

  static Future<File> _markerFile() async {
    final base = Platform.environment['LOCALAPPDATA'] ?? _executableDir();
    return File(p.join(base, 'Mada_POS', 'prerequisites_$_markerVersion.done'));
  }

  static Future<void> _writeMarker(File marker) async {
    await marker.parent.create(recursive: true);
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  static Future<void> _runInstaller(String exePath, List<String> arguments) async {
    debugPrint('Mada Smart POS: running ${p.basename(exePath)} ${arguments.join(' ')}');

    var exitCode = await _runProcess(exePath, arguments);
    if (!_successExitCodes.contains(exitCode)) {
      exitCode = await _runElevated(exePath, arguments);
    }

    if (!_successExitCodes.contains(exitCode)) {
      debugPrint(
        'Mada Smart POS: prerequisite installer exit code $exitCode for ${p.basename(exePath)}',
      );
    }
  }

  static Future<int> _runProcess(String exePath, List<String> arguments) async {
    final result = await Process.run(exePath, arguments, runInShell: true);
    return result.exitCode;
  }

  static Future<int> _runElevated(String exePath, List<String> arguments) async {
    final args = arguments.map((a) => "'${a.replaceAll("'", "''")}'").join(',');
    final command =
        "Start-Process -FilePath '${exePath.replaceAll("'", "''")}' "
        "-ArgumentList $args -Verb RunAs -Wait -PassThru | ForEach-Object { \$_.ExitCode }";

    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command],
      runInShell: true,
    );

    if (result.exitCode != 0) return result.exitCode;
    return int.tryParse(result.stdout.toString().trim()) ?? result.exitCode;
  }
}
