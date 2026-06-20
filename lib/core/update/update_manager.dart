import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String zipUrl;
  final String releaseNotes;
  final bool isUpdateAvailable;

  UpdateInfo({
    required this.version,
    required this.zipUrl,
    required this.releaseNotes,
    required this.isUpdateAvailable,
  });
}

class UpdateManager {
  static const String currentVersion = '1.0.0';

  static const String fallbackUpdateUrl =
      'https://raw.githubusercontent.com/Daksh/zournia_pc/main/releases/latest.json';

  /// Load config from assets and check the update server for a newer version.
  static Future<UpdateInfo> check() async {
    try {
      String updateUrl = fallbackUpdateUrl;

      try {
        final configText = await rootBundle.loadString('assets/app_config.json');
        final Map<String, dynamic> config = jsonDecode(configText);
        updateUrl = config['update_url'] ?? fallbackUpdateUrl;
      } catch (_) {
        updateUrl = fallbackUpdateUrl;
      }

      final response = await http.get(Uri.parse(updateUrl)).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String remoteVersion = data['version'] ?? '1.0.0';
        final String zipUrl = data['url'] ?? '';
        final String releaseNotes = data['notes'] ?? 'No release notes available.';
        final isAvailable = _compareVersions(remoteVersion, currentVersion);

        return UpdateInfo(
          version: remoteVersion,
          zipUrl: zipUrl,
          releaseNotes: releaseNotes,
          isUpdateAvailable: isAvailable,
        );
      }
    } catch (e) {
      return UpdateInfo(
        version: currentVersion,
        zipUrl: '',
        releaseNotes: 'Failed to fetch update metadata: $e',
        isUpdateAvailable: false,
      );
    }

    return UpdateInfo(
      version: currentVersion,
      zipUrl: '',
      releaseNotes: 'No updates found.',
      isUpdateAvailable: false,
    );
  }

  /// Perform download and spawn the updater script.
  static Future<void> apply(String zipUrl, Function(double) onProgress) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(zipUrl));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Server returned code ${response.statusCode}');
    }

    final tempDir = Directory.systemTemp.path;
    final zipPath = Platform.isWindows
        ? '$tempDir\\zournia_update.zip'
        : '$tempDir/zournia_update.zip';
    final zipFile = File(zipPath);
    final iosSink = zipFile.openWrite();

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    await for (final List<int> chunk in response.stream) {
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }
      iosSink.add(chunk);
    }

    await iosSink.close();
    client.close();

    await _launchUpdater(tempDir);
  }

  /// Compare semantic version numbers (returns true if version A > version B).
  static bool _compareVersions(String verA, String verB) {
    try {
      final List<int> aParts = verA.split('.').map((e) => int.parse(e)).toList();
      final List<int> bParts = verB.split('.').map((e) => int.parse(e)).toList();

      for (int i = 0; i < 3; i++) {
        final valA = i < aParts.length ? aParts[i] : 0;
        final valB = i < bParts.length ? bParts[i] : 0;
        if (valA > valB) return true;
        if (valA < valB) return false;
      }
    } catch (_) {
      return verA != verB;
    }
    return false;
  }

  /// Create and launch a detached self-deleting script to execute the update.
  static Future<void> _launchUpdater(String tempDir) async {
    final exePath = Platform.resolvedExecutable;
    final appDir = File(exePath).parent.path;
    final zipPath = Platform.isWindows
        ? '$tempDir\\zournia_update.zip'
        : '$tempDir/zournia_update.zip';

    if (Platform.isWindows) {
      await _launchWindowsUpdater(tempDir, zipPath, appDir, exePath);
    } else if (Platform.isMacOS || Platform.isLinux) {
      await _launchUnixUpdater(tempDir, zipPath, appDir, exePath);
    }
  }

  static Future<void> _launchWindowsUpdater(
      String tempDir, String zipPath, String appDir, String exePath) async {
    final updaterPath = '$tempDir\\zournia_updater.bat';
    final updaterFile = File(updaterPath);

    final String batContent = '''
@echo off
title Zournia OS Auto-Updater
echo ==============================================
echo   ZOURNIA OS - AUTO UPDATE AGENT
echo ==============================================
echo.
echo Waiting for main application process to exit...
timeout /t 2 /nobreak > nul

:wait
tasklist /FI "IMAGENAME eq zournia_pc.exe" 2>NUL | find /I /N "zournia_pc.exe">NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 1 /nobreak > nul
    goto wait
)

echo.
echo Installing Zournia OS update package...
powershell -Command "Expand-Archive -Path '$zipPath' -DestinationPath '$appDir' -Force"

echo.
echo Restarting Zournia OS client...
start "" "$exePath"

echo.
echo Cleaning up setup package...
del "$zipPath"

:: Self delete batch script
(goto) 2>nul & del "%~f0"
''';

    await updaterFile.writeAsString(batContent);

    await Process.start(
      'cmd.exe',
      ['/c', updaterPath],
      runInShell: true,
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  static Future<void> _launchUnixUpdater(
      String tempDir, String zipPath, String appDir, String exePath) async {
    final scriptPath = Platform.isMacOS
        ? '$tempDir/zournia_updater.sh'
        : '$tempDir/zournia_updater.sh';
    final scriptFile = File(scriptPath);

    final String shContent = '''
#!/bin/bash
echo "=============================================="
echo "  ZOURNIA OS - AUTO UPDATE AGENT"
echo "=============================================="
echo ""
echo "Waiting for main application process to exit..."
sleep 2

# Wait for the main process to exit
while pgrep -x "zournia" > /dev/null 2>&1; do
    sleep 1
done

echo ""
echo "Installing Zournia OS update package..."
unzip -o "$zipPath" -d "$appDir"

echo ""
echo "Restarting Zournia OS client..."
"$exePath" &

echo ""
echo "Cleaning up setup package..."
rm -f "$zipPath"
rm -f "$scriptPath"
''';

    await scriptFile.writeAsString(shContent);

    // Make executable and run
    await Process.start('chmod', ['+x', scriptPath]);
    await Process.start(
      'bash',
      [scriptPath],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}
