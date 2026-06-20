import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import 'app_scanner.dart';

class PhoneController {
  final Map<String, int> processRegistry = {};
  final AppScanner appScanner = AppScanner();

  String? _cachedDumpUI;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTTL = AppConstants.uiDumpCacheTTL;

  static const String _patternsFile = AppConstants.learnedPatternsFile;
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

  // ── Platform detection ────────────────────────────────────────────────

  bool _isDesktop() => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  bool _isMobile() => !kIsWeb && !(Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // ══════════════════════════════════════════════════════════════════════
  // CORE INPUT (Mobile)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> tap(int x, int y) async {
    if (!_isMobile()) return 'TAP: only available on Android/Termux.';
    try {
      final result = await Process.run('input', ['tap', x.toString(), y.toString()]);
      if (result.exitCode == 0) return 'TAP ACK: Tapped at ($x, $y).';
      return 'TAP ERROR: ${result.stderr}';
    } catch (e) {
      return 'TAP ERROR: $e';
    }
  }

  Future<String> doubleTap(int x, int y) async {
    if (!_isMobile()) return 'DOUBLE_TAP: only available on Android/Termux.';
    try {
      await Process.run('input', ['tap', x.toString(), y.toString()]);
      await Future.delayed(const Duration(milliseconds: 80));
      final result = await Process.run('input', ['tap', x.toString(), y.toString()]);
      if (result.exitCode == 0) return 'DOUBLE_TAP ACK: Double tapped at ($x, $y).';
      return 'DOUBLE_TAP ERROR: ${result.stderr}';
    } catch (e) {
      return 'DOUBLE_TAP ERROR: $e';
    }
  }

  Future<String> longPress(int x, int y, {int durationMs = 1000}) async {
    if (!_isMobile()) return 'LONGPRESS: only available on Android/Termux.';
    try {
      final result = await Process.run('input', [
        'swipe', x.toString(), y.toString(), x.toString(), y.toString(), durationMs.toString(),
      ]);
      if (result.exitCode == 0) return 'LONGPRESS ACK: Long pressed at ($x, $y) for ${durationMs}ms.';
      return 'LONGPRESS ERROR: ${result.stderr}';
    } catch (e) {
      return 'LONGPRESS ERROR: $e';
    }
  }

  Future<String> swipe(int x1, int y1, int x2, int y2, {int durationMs = 300}) async {
    if (!_isMobile()) return 'SWIPE: only available on Android/Termux.';
    try {
      final result = await Process.run('input', [
        'swipe', x1.toString(), y1.toString(), x2.toString(), y2.toString(), durationMs.toString(),
      ]);
      if (result.exitCode == 0) return 'SWIPE ACK: Swiped from ($x1, $y1) to ($x2, $y2) in ${durationMs}ms.';
      return 'SWIPE ERROR: ${result.stderr}';
    } catch (e) {
      return 'SWIPE ERROR: $e';
    }
  }

  Future<String> pinch(String direction) async {
    if (!_isMobile()) return 'PINCH: only available on Android/Termux.';
    try {
      if (direction == 'out' || direction == 'zoom_in') {
        await Process.run('sh', ['-c', 'input swipe 400 800 200 600 300 & input swipe 600 800 800 600 300 & wait']);
      } else {
        await Process.run('sh', ['-c', 'input swipe 200 600 400 800 300 & input swipe 800 600 600 800 300 & wait']);
      }
      return 'PINCH ACK: Pinch $direction executed.';
    } catch (e) {
      return 'PINCH ERROR: $e';
    }
  }

  Future<String> typeText(String text) async {
    if (!_isMobile()) return 'TYPE: only available on Android/Termux.';
    try {
      final escaped = text.replaceAll(' ', '%s').replaceAll("'", "\\'");
      final result = await Process.run('input', ['text', escaped]);
      if (result.exitCode == 0) return 'TYPE ACK: Typed "$text".';
      return 'TYPE ERROR: ${result.stderr}';
    } catch (e) {
      return 'TYPE ERROR: $e';
    }
  }

  Future<String> navigate(String action) async {
    if (!_isMobile()) return 'NAV: only available on Android/Termux.';
    final keyMap = {
      'back': 'KEYCODE_BACK', 'home': 'KEYCODE_HOME', 'recents': 'KEYCODE_APP_SWITCH',
      'enter': 'KEYCODE_ENTER', 'delete': 'KEYCODE_DEL', 'tab': 'KEYCODE_TAB',
      'escape': 'KEYCODE_ESCAPE', 'power': 'KEYCODE_POWER', 'camera': 'KEYCODE_CAMERA',
      'volume_up': 'KEYCODE_VOLUME_UP', 'volume_down': 'KEYCODE_VOLUME_DOWN',
      'media_play_pause': 'KEYCODE_MEDIA_PLAY_PAUSE', 'media_next': 'KEYCODE_MEDIA_NEXT',
      'media_previous': 'KEYCODE_MEDIA_PREVIOUS', 'brightness_up': 'KEYCODE_BRIGHTNESS_UP',
      'brightness_down': 'KEYCODE_BRIGHTNESS_DOWN',
    };
    final key = keyMap[action.toLowerCase()];
    if (key == null) return 'NAV ERROR: Unknown action "$action". Available: ${keyMap.keys.join(", ")}';
    try {
      final result = await Process.run('input', ['keyevent', key]);
      if (result.exitCode == 0) return 'NAV ACK: Pressed $action ($key).';
      return 'NAV ERROR: ${result.stderr}';
    } catch (e) {
      return 'NAV ERROR: $e';
    }
  }

  Future<String> selectAll() async {
    if (!_isMobile()) return 'SELECT_ALL: only available on Android/Termux.';
    return _shellCommand('input keyevent --longpress KEYCODE_A');
  }

  Future<String> copyText() async {
    if (!_isMobile()) return 'COPY_TEXT: only available on Android/Termux.';
    return _shellCommand('input keyevent --longpress KEYCODE_C');
  }

  Future<String> pasteText() async {
    if (!_isMobile()) return 'PASTE_TEXT: only available on Android/Termux.';
    return _shellCommand('input keyevent KEYCODE_PASTE');
  }

  Future<String> wake() async {
    if (!_isMobile()) return 'WAKE: only available on Android/Termux.';
    await Process.run('input', ['keyevent', 'KEYCODE_WAKEUP']);
    await Future.delayed(const Duration(milliseconds: 200));
    return _shellCommand('input swipe 540 1800 540 800 200');
  }

  Future<String> sleep() async {
    if (!_isMobile()) return 'SLEEP: only available on Android/Termux.';
    return _shellCommand('input keyevent KEYCODE_SLEEP');
  }

  Future<String> unlock() async {
    if (!_isMobile()) return 'UNLOCK: only available on Android/Termux.';
    await _shellCommand('input keyevent KEYCODE_WAKEUP');
    await Future.delayed(const Duration(milliseconds: 300));
    return _shellCommand('input swipe 540 1800 540 800 200');
  }

  // ══════════════════════════════════════════════════════════════════════
  // SCREEN & UI (Mobile)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> screenshot() async {
    if (!_isMobile()) return 'SCREENSHOT: only available on Android/Termux.';
    const path = AppConstants.screenshotPath;
    try {
      final result = await Process.run('screencap', ['-p', path]);
      if (result.exitCode == 0) return 'SCREENSHOT ACK: Saved to $path.';
      return 'SCREENSHOT ERROR: ${result.stderr}';
    } catch (e) {
      return 'SCREENSHOT ERROR: $e';
    }
  }

  Future<String> dumpUI() async {
    if (!_isMobile()) return 'DUMPUI: only available on Android/Termux.';
    if (_cachedDumpUI != null && _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTTL) {
      return 'DUMPUI ACK (cached): $_cachedDumpUI';
    }
    const path = AppConstants.uiDumpPath;
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
              'x1': int.parse(b.group(1)!), 'y1': int.parse(b.group(2)!),
              'x2': int.parse(b.group(3)!), 'y2': int.parse(b.group(4)!),
              'text': t?.group(1) ?? '', 'class': c?.group(1) ?? '',
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

  // ══════════════════════════════════════════════════════════════════════
  // CLIPBOARD (Mobile + Desktop)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> clipboardGet() async {
    if (_isDesktop()) return _clipboardGetDesktop();
    try {
      final result = await Process.run('sh', ['-c', 'termux-clipboard-get 2>&1']);
      if (result.exitCode == 0) {
        final text = result.stdout.toString().trim();
        return 'CLIPBOARD ACK: "$text"';
      }
      return 'CLIPBOARD ACK (raw): ${result.stdout}';
    } catch (e) {
      return 'CLIPBOARD ERROR: $e';
    }
  }

  Future<String> clipboardSet(String text) async {
    if (_isDesktop()) return _clipboardSetDesktop(text);
    try {
      final result = await Process.run('sh', ['-c', "termux-clipboard-set '${text.replaceAll("'", "\\'")}' 2>&1"]);
      if (result.exitCode == 0) return 'CLIPBOARD SET ACK: Clipboard set.';
      return 'CLIPBOARD SET ERROR: ${result.stderr}';
    } catch (e) {
      return 'CLIPBOARD SET ERROR: $e';
    }
  }

  Future<String> _clipboardGetDesktop() async {
    try {
      if (Platform.isWindows) {
        final r = await Process.run('powershell', ['-command', 'Get-Clipboard']);
        return 'CLIPBOARD ACK: "${r.stdout.toString().trim()}"';
      } else if (Platform.isMacOS) {
        final r = await Process.run('pbpaste', []);
        return 'CLIPBOARD ACK: "${r.stdout.toString().trim()}"';
      } else {
        final r = await Process.run('xclip', ['-selection', 'clipboard', '-o']);
        return 'CLIPBOARD ACK: "${r.stdout.toString().trim()}"';
      }
    } catch (e) {
      return 'CLIPBOARD ERROR: $e';
    }
  }

  Future<String> _clipboardSetDesktop(String text) async {
    try {
      if (Platform.isWindows) {
        await Process.run('powershell', ['-command', 'Set-Clipboard -Value "$text"']);
      } else if (Platform.isMacOS) {
        final p = await Process.start('pbcopy', []);
        p.stdin.write(text);
        await p.stdin.close();
      } else {
        final p = await Process.start('xclip', ['-selection', 'clipboard']);
        p.stdin.write(text);
        await p.stdin.close();
      }
      return 'CLIPBOARD SET ACK: Clipboard set.';
    } catch (e) {
      return 'CLIPBOARD SET ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // FILE OPERATIONS (Both platforms)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> readFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 'READ_FILE ERROR: File not found: $path';
      final content = await file.readAsString();
      if (content.length > AppConstants.fileReadTruncationLimit) {
        return 'READ_FILE ACK: ${content.substring(0, AppConstants.fileReadTruncationLimit)}\n\n[...truncated, ${content.length} total chars]';
      }
      return 'READ_FILE ACK:\n$content';
    } catch (e) {
      return 'READ_FILE ERROR: $e';
    }
  }

  Future<String> writeFile(String path, String content) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return 'WRITE_FILE ACK: Wrote ${content.length} chars to $path';
    } catch (e) {
      return 'WRITE_FILE ERROR: $e';
    }
  }

  Future<String> editFile(String path, String oldString, String newString) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 'EDIT_FILE ERROR: File not found: $path';
      var content = await file.readAsString();
      if (!content.contains(oldString)) {
        return 'EDIT_FILE ERROR: Old text not found in $path';
      }
      content = content.replaceAll(oldString, newString);
      await file.writeAsString(content);
      return 'EDIT_FILE ACK: Replaced text in $path';
    } catch (e) {
      return 'EDIT_FILE ERROR: $e';
    }
  }

  Future<String> listDir(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return 'LIST_DIR ERROR: Directory not found: $path';
      final entries = <String>[];
      await for (final entity in dir.list()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final type = entity is File ? '[F]' : entity is Directory ? '[D]' : '[L]';
        entries.add('$type $name');
      }
      entries.sort();
      if (entries.length > 100) {
        return 'LIST_DIR ACK (${entries.length} entries, showing first 100):\n${entries.take(100).join("\n")}';
      }
      return 'LIST_DIR ACK (${entries.length} entries):\n${entries.join("\n")}';
    } catch (e) {
      return 'LIST_DIR ERROR: $e';
    }
  }

  Future<String> deleteFile(String path) async {
    try {
      final entity = FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound
          ? (File(path).existsSync() ? File(path) : Directory(path).existsSync() ? Directory(path) : null)
          : null;
      if (entity == null) return 'DELETE_FILE ERROR: Not found: $path';
      await entity.delete(recursive: true);
      return 'DELETE_FILE ACK: Deleted $path';
    } catch (e) {
      return 'DELETE_FILE ERROR: $e';
    }
  }

  Future<String> mkdir(String path) async {
    try {
      await Directory(path).create(recursive: true);
      return 'MKDIR ACK: Created $path';
    } catch (e) {
      return 'MKDIR ERROR: $e';
    }
  }

  Future<String> copyFile(String src, String dest) async {
    try {
      await File(src).copy(dest);
      return 'COPY_FILE ACK: Copied $src -> $dest';
    } catch (e) {
      return 'COPY_FILE ERROR: $e';
    }
  }

  Future<String> moveFile(String src, String dest) async {
    try {
      await File(src).rename(dest);
      return 'MOVE_FILE ACK: Moved $src -> $dest';
    } catch (e) {
      return 'MOVE_FILE ERROR: $e';
    }
  }

  Future<String> appendFile(String path, String content) async {
    try {
      final file = File(path);
      final sink = file.openWrite(mode: FileMode.append);
      sink.write(content);
      await sink.close();
      return 'FILE_APPEND ACK: Appended ${content.length} chars to $path';
    } catch (e) {
      return 'FILE_APPEND ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // SYSTEM INFO (Both platforms)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> deviceInfo() async {
    final info = <String, String>{};
    try {
      if (_isMobile()) {
        final model = await _shellCommand('getprop ro.product.model');
        final android = await _shellCommand('getprop ro.build.version.release');
        final brand = await _shellCommand('getprop ro.product.brand');
        final mfr = await _shellCommand('getprop ro.product.manufacturer');
        info['Model'] = model;
        info['Android'] = android;
        info['Brand'] = brand;
        info['Manufacturer'] = mfr;
      } else if (Platform.isWindows) {
        final r = await Process.run('powershell', ['-command',
          'Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model | ConvertTo-Json'
        ]);
        info['System'] = r.stdout.toString().trim();
        final r2 = await Process.run('powershell', ['-command', '[System.Environment]::OSVersion.VersionString']);
        info['OS'] = r2.stdout.toString().trim();
        final r3 = await Process.run('hostname', []);
        info['Hostname'] = r3.stdout.toString().trim();
      } else if (Platform.isMacOS) {
        final r = await Process.run('uname', ['-a']);
        info['System'] = r.stdout.toString().trim();
      } else {
        final r = await Process.run('uname', ['-a']);
        info['System'] = r.stdout.toString().trim();
      }
    } catch (_) {}
    final output = info.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    return 'DEVICE_INFO ACK:\n$output';
  }

  Future<String> battery() async {
    try {
      if (_isMobile()) {
        final r = await Process.run('dumpsys', ['battery']);
        final text = r.stdout.toString();
        final level = RegExp(r'level: (\d+)').firstMatch(text)?.group(1) ?? '?';
        final status = RegExp(r'status: (\d+)').firstMatch(text)?.group(1) ?? '?';
        final temp = RegExp(r'temperature: (\d+)').firstMatch(text)?.group(1) ?? '?';
        final statusMap = {'1': 'Unknown', '2': 'Charging', '3': 'Discharging', '4': 'Full', '5': 'Not charging'};
        return 'BATTERY ACK: Level: $level% | Status: ${statusMap[status] ?? status} | Temp: ${temp}0C';
      } else if (Platform.isWindows) {
        final r = await Process.run('powershell', ['-command', '(Get-WmiObject Win32_Battery).EstimatedChargeRemaining']);
        return 'BATTERY ACK: ${r.stdout.toString().trim()}%';
      }
      return 'BATTERY ACK: No battery info available on this platform.';
    } catch (e) {
      return 'BATTERY ERROR: $e';
    }
  }

  Future<String> storage() async {
    try {
      if (_isMobile()) {
        final r = await Process.run('df', ['-h', '/sdcard']);
        return 'STORAGE ACK:\n${r.stdout.toString().trim()}';
      } else if (Platform.isWindows) {
        final r = await Process.run('wmic', ['logicaldisk', 'get', 'size,freespace,caption']);
        return 'STORAGE ACK:\n${r.stdout.toString().trim()}';
      } else {
        final r = await Process.run('df', ['-h']);
        return 'STORAGE ACK:\n${r.stdout.toString().trim()}';
      }
    } catch (e) {
      return 'STORAGE ERROR: $e';
    }
  }

  Future<String> ram() async {
    try {
      if (_isMobile()) {
        final r = await Process.run('cat', ['/proc/meminfo']);
        final text = r.stdout.toString();
        final total = RegExp(r'MemTotal:\s+(\d+) kB').firstMatch(text)?.group(1) ?? '?';
        final free = RegExp(r'MemAvailable:\s+(\d+) kB').firstMatch(text)?.group(1) ?? '?';
        final totalMb = total != '?' ? (int.parse(total) / 1024).round() : '?';
        final freeMb = free != '?' ? (int.parse(free) / 1024).round() : '?';
        return 'RAM ACK: Total: ${totalMb}MB | Available: ${freeMb}MB';
      } else if (Platform.isWindows) {
        final r = await Process.run('systeminfo', []);
        final text = r.stdout.toString();
        final match = RegExp(r'Total Physical Memory:\s+(.*)').firstMatch(text);
        return 'RAM ACK: ${match?.group(1) ?? "unknown"}';
      } else {
        final r = await Process.run('free', ['-h']);
        return 'RAM ACK:\n${r.stdout.toString().trim()}';
      }
    } catch (e) {
      return 'RAM ERROR: $e';
    }
  }

  Future<String> network() async {
    try {
      final info = <String, String>{};
      if (_isMobile()) {
        final ip = await _shellCommand("ifconfig wlan0 2>/dev/null | grep 'inet ' | head -1");
        info['WiFi IP'] = ip;
        final wifi = await _shellCommand('dumpsys wifi | grep "mWifiInfo" | head -1');
        info['WiFi Info'] = wifi;
      } else if (Platform.isWindows) {
        final r = await Process.run('ipconfig', []);
        final lines = r.stdout.toString().split('\n');
        final relevant = lines.where((l) => l.contains('IPv4') || l.contains('Wireless') || l.contains('Ethernet')).toList();
        info['Network'] = relevant.join('\n');
      } else {
        final r = await Process.run('hostname', ['-I']);
        info['IPs'] = r.stdout.toString().trim();
      }
      final output = info.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      return 'NETWORK ACK:\n$output';
    } catch (e) {
      return 'NETWORK ERROR: $e';
    }
  }

  Future<String> env(String varName) async {
    if (varName.isEmpty) {
      final env = Platform.environment;
      final output = env.entries.take(30).map((e) => '${e.key}=${e.value}').join('\n');
      return 'ENV ACK (first 30 vars):\n$output';
    }
    return 'ENV ACK: $varName=${Platform.environment[varName] ?? '(not set)'}';
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTACTS & MESSAGING (Mobile)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> contacts() async {
    if (!_isMobile()) return 'CONTACTS: only available on Android/Termux.';
    try {
      final r = await Process.run('content', [
        'query', '--uri', 'content://com.android.contacts/contacts',
        '--projection', '_display_name:data1',
        '--sort', '_display_name ASC',
      ]);
      if (r.exitCode == 0) {
        final text = r.stdout.toString().trim();
        if (text.length > 6000) {
          return 'CONTACTS ACK (truncated):\n${text.substring(0, 6000)}';
        }
        return 'CONTACTS ACK:\n$text';
      }
      // Fallback: sqlite
      final r2 = await Process.run('sh', ['-c',
        'sqlite3 /data/data/com.android.providers.contacts/databases/contacts2.db "SELECT display_name FROM contacts WHERE display_name IS NOT NULL ORDER BY display_name LIMIT 100;" 2>&1'
      ]);
      return 'CONTACTS ACK:\n${r2.stdout.toString().trim()}';
    } catch (e) {
      return 'CONTACTS ERROR: $e';
    }
  }

  Future<String> sendSms(String number, String message) async {
    if (!_isMobile()) return 'SMS: only available on Android/Termux.';
    try {
      final r = await Process.run('am', [
        'start', '-a', 'android.intent.action.SENDTO',
        '-d', 'smsto:$number',
        '--es', 'sms_body', message,
      ]);
      if (r.exitCode == 0) return 'SMS ACK: Opened SMS to $number with message.';
      return 'SMS ERROR: ${r.stderr}';
    } catch (e) {
      return 'SMS ERROR: $e';
    }
  }

  Future<String> callLog() async {
    if (!_isMobile()) return 'CALL_LOG: only available on Android/Termux.';
    try {
      final r = await Process.run('content', [
        'query', '--uri', 'content://call_log/calls',
        '--projection', 'number:name:date:type',
        '--sort', 'date DESC',
        '--limit', '20',
      ]);
      return 'CALL_LOG ACK:\n${r.stdout.toString().trim()}';
    } catch (e) {
      return 'CALL_LOG ERROR: $e';
    }
  }

  Future<String> calendarEvents() async {
    if (!_isMobile()) return 'CALENDAR: only available on Android/Termux.';
    try {
      final r = await Process.run('content', [
        'query', '--uri', 'content://com.android.calendar/events',
        '--projection', 'title:dtstart:dtend:eventLocation:description',
        '--sort', 'dtstart DESC',
        '--limit', '20',
      ]);
      return 'CALENDAR ACK:\n${r.stdout.toString().trim()}';
    } catch (e) {
      return 'CALENDAR ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // APP MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════

  Future<String> openApp(String packageName) async {
    if (_isMobile()) {
      final launcher = appScanner.resolveLauncher(packageName);
      if (launcher != null) {
        try {
          final r = await Process.run('sh', ['-c', 'am start -n $launcher']);
          if (r.exitCode == 0) {
            final appName = appScanner.apps[packageName]?.appName ?? packageName;
            return 'OPENAPP ACK: Launched $appName ($packageName).';
          }
        } catch (_) {}
      }
      try {
        final r = await Process.run('monkey', ['-p', packageName, '1']);
        if (r.exitCode == 0) return 'OPENAPP ACK: Launched $packageName.';
        return 'OPENAPP ERROR: ${r.stderr}';
      } catch (e) {
        return 'OPENAPP ERROR: $e';
      }
    } else {
      try {
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', packageName]);
          return 'OPENAPP ACK: Launched $packageName.';
        } else if (Platform.isMacOS) {
          await Process.run('open', ['-a', packageName]);
          return 'OPENAPP ACK: Launched $packageName.';
        } else {
          await Process.run(packageName, []);
          return 'OPENAPP ACK: Launched $packageName.';
        }
      } catch (e) {
        return 'OPENAPP ERROR: $e';
      }
    }
  }

  Future<String> listApps() async {
    if (_isMobile()) {
      return getDiscoveredAppsSummary();
    } else {
      try {
        if (Platform.isWindows) {
          final r = await Process.run('wmic', ['product', 'get', 'name']);
          return 'APPS ACK:\n${r.stdout.toString().trim()}';
        }
        return 'APPS ACK: Use OPEN_APP with app name on desktop.';
      } catch (e) {
        return 'APPS ERROR: $e';
      }
    }
  }

  Future<String> uninstallApp(String packageName) async {
    if (!_isMobile()) return 'UNINSTALL_APP: only available on Android.';
    try {
      final r = await Process.run('am', ['start', '-a', 'android.intent.action.DELETE', '-d', 'package:$packageName']);
      if (r.exitCode == 0) return 'UNINSTALL_APP ACK: Uninstall prompt opened for $packageName.';
      return 'UNINSTALL_APP ERROR: ${r.stderr}';
    } catch (e) {
      return 'UNINSTALL_APP ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MEDIA & CAMERA (Mobile)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> camera() async {
    if (!_isMobile()) return 'CAMERA: only available on Android/Termux.';
    try {
      await Process.run('am', [
        'start', '-a', 'android.media.action.IMAGE_CAPTURE',
      ]);
      return 'CAMERA ACK: Camera opened.';
    } catch (e) {
      return 'CAMERA ERROR: $e';
    }
  }

  Future<String> record() async {
    if (!_isMobile()) return 'RECORD: only available on Android/Termux.';
    try {
      await Process.run('am', [
        'start', '-a', 'android.media.action.VIDEO_CAPTURE',
      ]);
      return 'RECORD ACK: Video recorder opened.';
    } catch (e) {
      return 'RECORD ERROR: $e';
    }
  }

  Future<String> gallery() async {
    if (!_isMobile()) return 'GALLERY: only available on Android/Termux.';
    try {
      final r = await Process.run('sh', ['-c',
        'ls -lt /sdcard/DCIM/ /sdcard/Pictures/ /sdcard/Download/ 2>/dev/null | head -30'
      ]);
      return 'GALLERY ACK:\n${r.stdout.toString().trim()}';
    } catch (e) {
      return 'GALLERY ERROR: $e';
    }
  }

  Future<String> mic() async {
    if (!_isMobile()) return 'MIC: only available on Android/Termux.';
    try {
      await Process.run('am', [
        'start', '-a', 'android.provider.MediaStore.RECORD_SOUND',
      ]);
      return 'MIC ACK: Audio recorder launched.';
    } catch (e) {
      return 'MIC ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS (Mobile)
  // ══════════════════════════════════════════════════════════════════════

  Future<String> notifications() async {
    if (!_isMobile()) return 'NOTIFICATIONS: only available on Android/Termux.';
    try {
      final r = await Process.run('dumpsys', ['notification', '--noredact']);
      final text = r.stdout.toString();
      if (text.length > 5000) {
        return 'NOTIFICATIONS ACK (truncated):\n${text.substring(0, 5000)}';
      }
      return 'NOTIFICATIONS ACK:\n$text';
    } catch (e) {
      return 'NOTIFICATIONS ERROR: $e';
    }
  }

  Future<String> postNotification(String title, String body) async {
    if (!_isMobile()) return 'POST_NOTIFICATION: only available on Android/Termux.';
    try {
      final r = await Process.run('sh', ['-c',
        "termux-notification --title '${title.replaceAll("'", "\\'")}' --content '${body.replaceAll("'", "\\'")}' --id zournia_\$(date +%s) 2>&1"
      ]);
      if (r.exitCode == 0) return 'POST_NOTIFICATION ACK: Posted "$title".';
      return 'POST_NOTIFICATION ACK: Notification sent (fallback).';
    } catch (e) {
      return 'POST_NOTIFICATION ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DESKTOP-SPECIFIC
  // ══════════════════════════════════════════════════════════════════════

  Future<String> windowList() async {
    if (!_isDesktop()) return 'WINDOW_LIST: only available on desktop.';
    try {
      if (Platform.isWindows) {
        final r = await Process.run('tasklist', []);
        return 'WINDOW_LIST ACK:\n${r.stdout.toString().trim()}';
      } else if (Platform.isMacOS) {
        final r = await Process.run('osascript', ['-e', 'tell application "System Events" to get name of every window of every process']);
        return 'WINDOW_LIST ACK:\n${r.stdout.toString().trim()}';
      } else {
        final r = await Process.run('wmctrl', ['-l']);
        return 'WINDOW_LIST ACK:\n${r.stdout.toString().trim()}';
      }
    } catch (e) {
      return 'WINDOW_LIST ERROR: $e';
    }
  }

  Future<String> desktopScreenshot() async {
    if (!_isDesktop()) return 'DESKTOP_SCREENSHOT: only available on desktop.';
    try {
      if (Platform.isWindows) {
        await Process.run('snippingtool', []);
        return 'DESKTOP_SCREENSHOT ACK: Screenshot tool opened.';
      } else if (Platform.isMacOS) {
        final path = '${Platform.environment['HOME']}/Desktop/zournia_screenshot.png';
        await Process.run('screencapture', ['-x', path]);
        return 'DESKTOP_SCREENSHOT ACK: Saved to $path';
      }
      return 'DESKTOP_SCREENSHOT ERROR: Unsupported Linux.';
    } catch (e) {
      return 'DESKTOP_SCREENSHOT ERROR: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // APP DISCOVERY & PATTERNS
  // ══════════════════════════════════════════════════════════════════════

  String getDiscoveredAppsSummary() => appScanner.getAppsSummary();
  String? findAppPackage(String query) => appScanner.findApp(query);

  // ══════════════════════════════════════════════════════════════════════
  // RAW SHELL (Both platforms)
  // ══════════════════════════════════════════════════════════════════════

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

  Future<String> _shellCommand(String command) async {
    try {
      final result = await Process.run('sh', ['-c', command]);
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
