import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'app_scanner.dart';

class PhoneController {
  final Map<String, int> processRegistry = {};
  final AppScanner appScanner = AppScanner();

  String? _cachedDumpUI;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTTL = Duration(seconds: 3);

  static const String _patternsFile = 'learned_patterns.json';
  Map<String, int> _patternCounts = {};
  Map<String, String> _learnedIntents = {};

  Timer? _periodicScanTimer;

  PhoneController() {
    _initScanner();
  }

  void _initScanner() async {
    await appScanner.loadCache();
    if (appScanner.needsScan) {
      appScanner.scanNow();
    }
    _periodicScanTimer = Timer.periodic(const Duration(hours: 12), (_) {
      appScanner.scanNow();
    });
  }

  void dispose() {
    _periodicScanTimer?.cancel();
  }

  Future<void> loadPatterns() async {
    try {
      final file = File(_patternsFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _patternCounts = Map<String, int>.from(data['counts'] ?? {});
        _learnedIntents = Map<String, String>.from(data['intents'] ?? {});
      }
    } catch (_) {}
  }

  Future<void> _savePatterns() async {
    try {
      final file = File(_patternsFile);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
        'counts': _patternCounts,
        'intents': _learnedIntents,
      }));
    } catch (_) {}
  }

  void recordPattern(String userRequest, String commandUsed) {
    final key = '${userRequest.toLowerCase().trim()}|$commandUsed';
    _patternCounts[key] = (_patternCounts[key] ?? 0) + 1;
    if (_patternCounts[key]! >= 3) {
      _learnedIntents[userRequest.toLowerCase().trim()] = commandUsed;
    }
    _savePatterns();
  }

  String? getLearnedIntent(String userRequest) {
    return _learnedIntents[userRequest.toLowerCase().trim()];
  }

  Map<String, String> getAllLearnedPatterns() {
    return Map.from(_learnedIntents);
  }

  Future<bool> get isMobile async {
    if (kIsWeb) return false;
    return !(Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  }

  Future<String> tap(int x, int y) async {
    if (!await isMobile) {
      return 'TAP: only available on Android/Termux.';
    }
    try {
      final result = await Process.run('input', ['tap', x.toString(), y.toString()]);
      if (result.exitCode == 0) {
        return 'TAP ACK: Tapped at ($x, $y).';
      }
      return 'TAP ERROR: ${result.stderr}';
    } catch (e) {
      return 'TAP ERROR: $e';
    }
  }

  Future<String> swipe(int x1, int y1, int x2, int y2, {int durationMs = 300}) async {
    if (!await isMobile) {
      return 'SWIPE: only available on Android/Termux.';
    }
    try {
      final result = await Process.run('input', [
        'swipe',
        x1.toString(), y1.toString(),
        x2.toString(), y2.toString(),
        durationMs.toString(),
      ]);
      if (result.exitCode == 0) {
        return 'SWIPE ACK: Swiped from ($x1, $y1) to ($x2, $y2) in ${durationMs}ms.';
      }
      return 'SWIPE ERROR: ${result.stderr}';
    } catch (e) {
      return 'SWIPE ERROR: $e';
    }
  }

  Future<String> longPress(int x, int y, {int durationMs = 1000}) async {
    if (!await isMobile) {
      return 'LONGPRESS: only available on Android/Termux.';
    }
    try {
      final result = await Process.run('input', [
        'swipe',
        x.toString(), y.toString(),
        x.toString(), y.toString(),
        durationMs.toString(),
      ]);
      if (result.exitCode == 0) {
        return 'LONGPRESS ACK: Long pressed at ($x, $y) for ${durationMs}ms.';
      }
      return 'LONGPRESS ERROR: ${result.stderr}';
    } catch (e) {
      return 'LONGPRESS ERROR: $e';
    }
  }

  Future<String> typeText(String text) async {
    if (!await isMobile) {
      return 'TYPE: only available on Android/Termux.';
    }
    try {
      final escaped = text.replaceAll(' ', '%s').replaceAll("'", "\\'");
      final result = await Process.run('input', ['text', escaped]);
      if (result.exitCode == 0) {
        return 'TYPE ACK: Typed "$text".';
      }
      return 'TYPE ERROR: ${result.stderr}';
    } catch (e) {
      return 'TYPE ERROR: $e';
    }
  }

  Future<String> navigate(String action) async {
    if (!await isMobile) {
      return 'NAV: only available on Android/Termux.';
    }
    final keyMap = {
      'back': 'KEYCODE_BACK',
      'home': 'KEYCODE_HOME',
      'recents': 'KEYCODE_APP_SWITCH',
      'enter': 'KEYCODE_ENTER',
      'delete': 'KEYCODE_DEL',
      'tab': 'KEYCODE_TAB',
      'escape': 'KEYCODE_ESCAPE',
      'power': 'KEYCODE_POWER',
      'volume_up': 'KEYCODE_VOLUME_UP',
      'volume_down': 'KEYCODE_VOLUME_DOWN',
      'camera': 'KEYCODE_CAMERA',
    };
    final key = keyMap[action.toLowerCase()];
    if (key == null) {
      return 'NAV ERROR: Unknown action "$action". Available: ${keyMap.keys.join(", ")}';
    }
    try {
      final result = await Process.run('input', ['keyevent', key]);
      if (result.exitCode == 0) {
        return 'NAV ACK: Pressed $action ($key).';
      }
      return 'NAV ERROR: ${result.stderr}';
    } catch (e) {
      return 'NAV ERROR: $e';
    }
  }

  Future<String> screenshot() async {
    if (!await isMobile) {
      return 'SCREENSHOT: only available on Android/Termux.';
    }
    const path = '/sdcard/zournia_screenshot.png';
    try {
      final result = await Process.run('screencap', ['-p', path]);
      if (result.exitCode == 0) {
        return 'SCREENSHOT ACK: Saved to $path. Use "cat $path" or open it to view.';
      }
      return 'SCREENSHOT ERROR: ${result.stderr}';
    } catch (e) {
      return 'SCREENSHOT ERROR: $e';
    }
  }

  Future<String> dumpUI() async {
    if (!await isMobile) {
      return 'DUMPUI: only available on Android/Termux.';
    }

    if (_cachedDumpUI != null && _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTTL) {
      return 'DUMPUI ACK (cached): $_cachedDumpUI';
    }

    const path = '/sdcard/zournia_ui.xml';
    try {
      final result = await Process.run('uiautomator', ['dump', path]);
      if (result.exitCode == 0) {
        final catResult = await Process.run('cat', [path]);
        final xml = catResult.stdout.toString();
        final bounds = <Map<String, dynamic>>[];
        final regex = RegExp(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"');
        final textRegex = RegExp(r'text="([^"]*)"');
        final classRegex = RegExp(r'class="([^"]*)"');

        final nodeRegex = RegExp(r'<node[^>]*>');
        for (final match in nodeRegex.allMatches(xml)) {
          final node = match.group(0)!;
          final b = regex.firstMatch(node);
          final t = textRegex.firstMatch(node);
          final c = classRegex.firstMatch(node);
          if (b != null) {
            bounds.add({
              'x1': int.parse(b.group(1)!),
              'y1': int.parse(b.group(2)!),
              'x2': int.parse(b.group(3)!),
              'y2': int.parse(b.group(4)!),
              'text': t?.group(1) ?? '',
              'class': c?.group(1) ?? '',
            });
          }
        }
        final encoded = jsonEncode(bounds);
        _cachedDumpUI = 'Found ${bounds.length} UI elements.\n$encoded';
        _cacheTimestamp = DateTime.now();
        return 'DUMPUI ACK: Found ${bounds.length} UI elements.\n$encoded';
      }
      return 'DUMPUI ERROR: ${result.stderr}';
    } catch (e) {
      return 'DUMPUI ERROR: $e';
    }
  }

  Future<String> openApp(String packageName) async {
    if (!await isMobile) {
      return 'OPENAPP: only available on Android/Termux.';
    }

    final launcher = appScanner.resolveLauncher(packageName);
    if (launcher != null) {
      try {
        final result = await Process.run('sh', ['-c', 'am start -n $launcher']);
        if (result.exitCode == 0) {
          final appName = appScanner.apps[packageName]?.appName ?? packageName;
          return 'OPENAPP ACK: Launched $appName ($packageName).';
        }
      } catch (_) {}
    }

    try {
      final result = await Process.run('monkey', ['-p', packageName, '1']);
      if (result.exitCode == 0) {
        return 'OPENAPP ACK: Launched $packageName.';
      }
      return 'OPENAPP ERROR: ${result.stderr}';
    } catch (e) {
      return 'OPENAPP ERROR: $e';
    }
  }

  String getDiscoveredAppsSummary() {
    return appScanner.getAppsSummary();
  }

  String? findAppPackage(String query) {
    return appScanner.findApp(query);
  }

  Future<String> shell(String command) async {
    try {
      final result = await Process.run('sh', ['-c', command]);
      final out = result.stdout.toString().trim();
      final err = result.stderr.toString().trim();
      String response = 'SHELL ACK: Command executed.';
      if (out.isNotEmpty) response += '\nOutput:\n$out';
      if (err.isNotEmpty) response += '\nError:\n$err';
      return response;
    } catch (e) {
      return 'SHELL ERROR: $e';
    }
  }
}
