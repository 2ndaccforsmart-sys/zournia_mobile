import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../../features/automation/data/phone_controller.dart';

class CommandProcessor {
  final PhoneController phoneController;
  final Map<String, int> processRegistry;
  final Function(String) onStatus;
  final Function(String, String) recordPattern;
  final Function(double x, double y, bool clicking)? onCursorMove;
  final Function()? onCursorHide;

  CommandProcessor({
    required this.phoneController,
    required this.processRegistry,
    required this.onStatus,
    required this.recordPattern,
    this.onCursorMove,
    this.onCursorHide,
  });

  bool get _isMobile => !kIsWeb && !(Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Process all commands from an AI response, splitting on newlines.
  Future<String> processAll(String response, String userMessage) async {
    final lines = response.split('\n');
    final results = <String>[];
    final nonCommandLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (_isCommand(trimmed)) {
        final cmdResult = await processSingle(trimmed, userMessage);
        if (cmdResult != null) {
          if (nonCommandLines.isNotEmpty) {
            results.add(nonCommandLines.join('\n'));
            nonCommandLines.clear();
          }
          results.add(cmdResult);
        }
      } else {
        nonCommandLines.add(line);
      }
    }
    if (nonCommandLines.isNotEmpty) results.add(nonCommandLines.join('\n'));
    return results.isEmpty ? response : results.join('\n\n');
  }

  bool _isCommand(String line) {
    final upper = line.toUpperCase();
    return AppConstants.commandPrefixes.any((p) => upper.startsWith(p));
  }

  /// Process a single command line. Returns null if not a recognized command.
  Future<String?> processSingle(String trimmed, String userMessage) async {
    // Core
    final executeRegex = RegExp(r'^EXECUTE:\s*(.*)$', caseSensitive: false);
    final closeRegex = RegExp(r'^CLOSE:\s*(.*)$', caseSensitive: false);
    final searchRegex = RegExp(r'^SEARCH:\s*(.*)$', caseSensitive: false);
    final tapRegex = RegExp(r'^TAP:\s*(\d+)\s+(\d+)$', caseSensitive: false);
    final swipeRegex = RegExp(r'^SWIPE:\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)(?:\s+(\d+))?$', caseSensitive: false);
    final typeRegex = RegExp(r'^TYPE:\s*(.*)$', caseSensitive: false);
    final navRegex = RegExp(r'^NAV:\s*(\w+)$', caseSensitive: false);
    final screenshotRegex = RegExp(r'^SCREENSHOT:\s*$', caseSensitive: false);
    final uiDumpRegex = RegExp(r'^DUMPUI:\s*$', caseSensitive: false);
    final visionRegex = RegExp(r'^VISION:\s*(.*)$', caseSensitive: false);

    if (executeRegex.hasMatch(trimmed)) return await _handleExecute(executeRegex, trimmed, userMessage);
    if (closeRegex.hasMatch(trimmed)) return await _handleClose(closeRegex, trimmed);
    if (searchRegex.hasMatch(trimmed)) return await _handleSearch(searchRegex, trimmed, userMessage);
    if (tapRegex.hasMatch(trimmed)) return await _handleTap(tapRegex, trimmed, userMessage);
    if (swipeRegex.hasMatch(trimmed)) return await _handleSwipe(swipeRegex, trimmed, userMessage);
    if (typeRegex.hasMatch(trimmed)) return await _handleType(typeRegex, trimmed);
    if (navRegex.hasMatch(trimmed)) return await _handleNav(navRegex, trimmed);
    if (screenshotRegex.hasMatch(trimmed)) return await _handleScreenshot();
    if (uiDumpRegex.hasMatch(trimmed)) return await _handleDumpUI();
    if (visionRegex.hasMatch(trimmed)) return await _handleVision(visionRegex, trimmed);

    // App management
    final openAppRegex = RegExp(r'^(?:OPENAPP|LAUNCH):\s*(.*)$', caseSensitive: false);
    final listAppsRegex = RegExp(r'^LISTAPPS:\s*$', caseSensitive: false);
    final uninstallRegex = RegExp(r'^UNINSTALL:\s*(.*)$', caseSensitive: false);
    if (openAppRegex.hasMatch(trimmed)) return await _handleOpenApp(openAppRegex, trimmed);
    if (listAppsRegex.hasMatch(trimmed)) return _handleListApps();
    if (uninstallRegex.hasMatch(trimmed)) return await _handleUninstall(uninstallRegex, trimmed);

    // File operations
    final readFileRegex = RegExp(r'^READ_FILE:\s*(.*)$', caseSensitive: false);
    final writeFileRegex = RegExp(r'^WRITE_FILE:\s*(\S+)\s*\|\s*(.*)$', caseSensitive: false);
    final editFileRegex = RegExp(r'^EDIT_FILE:\s*(\S+)\s*\|(.*)\|(.*)\|$', caseSensitive: false);
    final listDirRegex = RegExp(r'^LIST_DIR:\s*(.*)$', caseSensitive: false);
    final deleteFileRegex = RegExp(r'^DELETE_FILE:\s*(.*)$', caseSensitive: false);
    final mkdirRegex = RegExp(r'^MKDIR:\s*(.*)$', caseSensitive: false);
    final copyFileRegex = RegExp(r'^COPY_FILE:\s*(\S+)\s+->\s+(\S+)$', caseSensitive: false);
    final moveFileRegex = RegExp(r'^MOVE_FILE:\s*(\S+)\s+->\s+(\S+)$', caseSensitive: false);
    final appendFileRegex = RegExp(r'^FILE_APPEND:\s*(\S+)\s*\|\s*(.*)$', caseSensitive: false);
    if (readFileRegex.hasMatch(trimmed)) return await _handleReadFile(readFileRegex, trimmed);
    if (writeFileRegex.hasMatch(trimmed)) return await _handleWriteFile(writeFileRegex, trimmed);
    if (editFileRegex.hasMatch(trimmed)) return await _handleEditFile(editFileRegex, trimmed);
    if (listDirRegex.hasMatch(trimmed)) return await _handleListDir(listDirRegex, trimmed);
    if (deleteFileRegex.hasMatch(trimmed)) return await _handleDeleteFile(deleteFileRegex, trimmed);
    if (mkdirRegex.hasMatch(trimmed)) return await _handleMkdir(mkdirRegex, trimmed);
    if (copyFileRegex.hasMatch(trimmed)) return await _handleCopyFile(copyFileRegex, trimmed);
    if (moveFileRegex.hasMatch(trimmed)) return await _handleMoveFile(moveFileRegex, trimmed);
    if (appendFileRegex.hasMatch(trimmed)) return await _handleAppendFile(appendFileRegex, trimmed);

    // Clipboard
    final clipGetRegex = RegExp(r'^CLIPBOARD:\s*$', caseSensitive: false);
    final clipSetRegex = RegExp(r'^(?:CLIP_SET|CLIPBOARD_SET):\s*(.*)$', caseSensitive: false);
    if (clipGetRegex.hasMatch(trimmed)) return await _handleClipboardGet();
    if (clipSetRegex.hasMatch(trimmed)) return await _handleClipboardSet(clipSetRegex, trimmed);

    // Contacts & messaging
    final contactsRegex = RegExp(r'^CONTACTS:\s*$', caseSensitive: false);
    final smsRegex = RegExp(r'^SMS:\s*(\S+)\s*\|\s*(.*)$', caseSensitive: false);
    final callLogRegex = RegExp(r'^CALL_LOG:\s*$', caseSensitive: false);
    final calendarRegex = RegExp(r'^CALENDAR:\s*$', caseSensitive: false);
    if (contactsRegex.hasMatch(trimmed)) return await _handleContacts();
    if (smsRegex.hasMatch(trimmed)) return await _handleSms(smsRegex, trimmed);
    if (callLogRegex.hasMatch(trimmed)) return await _handleCallLog();
    if (calendarRegex.hasMatch(trimmed)) return await _handleCalendar();

    // Media & camera
    final cameraRegex = RegExp(r'^CAMERA:\s*$', caseSensitive: false);
    final recordRegex = RegExp(r'^RECORD:\s*$', caseSensitive: false);
    final galleryRegex = RegExp(r'^GALLERY:\s*$', caseSensitive: false);
    final micRegex = RegExp(r'^MIC:\s*$', caseSensitive: false);
    if (cameraRegex.hasMatch(trimmed)) return await _handleCamera();
    if (recordRegex.hasMatch(trimmed)) return await _handleRecord();
    if (galleryRegex.hasMatch(trimmed)) return await _handleGallery();
    if (micRegex.hasMatch(trimmed)) return await _handleMic();

    // Notifications
    final notifRegex = RegExp(r'^NOTIFICATIONS:\s*$', caseSensitive: false);
    final postNotifRegex = RegExp(r'^POST_NOTIF:\s*(\S+)\s*\|\s*(.*)$', caseSensitive: false);
    if (notifRegex.hasMatch(trimmed)) return await _handleNotifications();
    if (postNotifRegex.hasMatch(trimmed)) return await _handlePostNotif(postNotifRegex, trimmed);

    // System info
    final devInfoRegex = RegExp(r'^DEVICE_INFO:\s*$', caseSensitive: false);
    final batteryRegex = RegExp(r'^BATTERY:\s*$', caseSensitive: false);
    final storageRegex = RegExp(r'^STORAGE:\s*$', caseSensitive: false);
    final ramRegex = RegExp(r'^RAM:\s*$', caseSensitive: false);
    final networkRegex = RegExp(r'^NETWORK:\s*$', caseSensitive: false);
    final envRegex = RegExp(r'^ENV:\s*(.*)$', caseSensitive: false);
    if (devInfoRegex.hasMatch(trimmed)) return await _handleDeviceInfo();
    if (batteryRegex.hasMatch(trimmed)) return await _handleBattery();
    if (storageRegex.hasMatch(trimmed)) return await _handleStorage();
    if (ramRegex.hasMatch(trimmed)) return await _handleRam();
    if (networkRegex.hasMatch(trimmed)) return await _handleNetwork();
    if (envRegex.hasMatch(trimmed)) return await _handleEnv(envRegex, trimmed);

    // Device control
    final wakeRegex = RegExp(r'^WAKE:\s*$', caseSensitive: false);
    final sleepRegex = RegExp(r'^SLEEP:\s*$', caseSensitive: false);
    final unlockRegex = RegExp(r'^UNLOCK:\s*$', caseSensitive: false);
    final doubleTapRegex = RegExp(r'^DOUBLE_TAP:\s*(\d+)\s+(\d+)$', caseSensitive: false);
    final longPressRegex = RegExp(r'^LONGPRESS:\s*(\d+)\s+(\d+)(?:\s+(\d+))?$', caseSensitive: false);
    final pinchRegex = RegExp(r'^PINCH:\s*(\w+)$', caseSensitive: false);
    final selectAllRegex = RegExp(r'^SELECT_ALL:\s*$', caseSensitive: false);
    final copyTextRegex = RegExp(r'^COPY_TEXT:\s*$', caseSensitive: false);
    final pasteTextRegex = RegExp(r'^PASTE_TEXT:\s*$', caseSensitive: false);
    if (wakeRegex.hasMatch(trimmed)) return await phoneController.wake();
    if (sleepRegex.hasMatch(trimmed)) return await phoneController.sleep();
    if (unlockRegex.hasMatch(trimmed)) return await phoneController.unlock();
    if (doubleTapRegex.hasMatch(trimmed)) return await _handleDoubleTap(doubleTapRegex, trimmed);
    if (longPressRegex.hasMatch(trimmed)) return await _handleLongPress(longPressRegex, trimmed);
    if (pinchRegex.hasMatch(trimmed)) return await phoneController.pinch(pinchRegex.firstMatch(trimmed)!.group(1)!);
    if (selectAllRegex.hasMatch(trimmed)) return await phoneController.selectAll();
    if (copyTextRegex.hasMatch(trimmed)) return await phoneController.copyText();
    if (pasteTextRegex.hasMatch(trimmed)) return await phoneController.pasteText();

    // Desktop
    final windowListRegex = RegExp(r'^WINDOW_LIST:\s*$', caseSensitive: false);
    final desktopScreenshotRegex = RegExp(r'^DESKTOP_SCREENSHOT:\s*$', caseSensitive: false);
    if (windowListRegex.hasMatch(trimmed)) return await phoneController.windowList();
    if (desktopScreenshotRegex.hasMatch(trimmed)) return await phoneController.desktopScreenshot();

    // Shell
    final shellRegex = RegExp(r'^SHELL:\s*(.*)$', caseSensitive: false);
    if (shellRegex.hasMatch(trimmed)) return await _handleShell(shellRegex, trimmed);

    return null;
  }

  // ── Command handlers ───────────────────────────────────────────────────

  Future<String> _handleExecute(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final command = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Executing automation command: $command');

    String ackMsg;
    if (_isMobile) {
      ackMsg = await _executeMobileCommand(command);
    } else {
      ackMsg = await _executeDesktopCommand(command);
    }

    recordPattern(userMessage, 'EXECUTE: $command');
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _executeMobileCommand(String command) async {
    final urlPattern = RegExp(r'"(https?://[^"]+)"');
    var urlMatch = urlPattern.firstMatch(command);
    urlMatch ??= RegExp(r"'(https?://[^']+)'").firstMatch(command);
    urlMatch ??= RegExp(r'''(https?://[^\s"']+)''').firstMatch(command);
    if (urlMatch != null) return _launchUrl(urlMatch.group(1)!);

    final launchRegex = RegExp(r'(?:am start|monkey -p)\s+([a-zA-Z0-9._]+)(?:\s+1)?$');
    final launchMatch = launchRegex.firstMatch(command.trim());
    if (launchMatch != null) return _launchApp(launchMatch.group(1)!);

    try {
      final process = await Process.start('sh', ['-c', command]);
      final stdoutBytes = <int>[];
      final stderrBytes = <int>[];
      final stdoutSub = process.stdout.listen((data) => stdoutBytes.addAll(data));
      final stderrSub = process.stderr.listen((data) => stderrBytes.addAll(data));
      await Future.delayed(const Duration(milliseconds: 500));
      await stdoutSub.cancel();
      await stderrSub.cancel();

      final out = const LineSplitter().convert(utf8.decode(stdoutBytes)).where((l) => !l.contains('Starting: Intent {')).join('\n').trim();
      final err = const LineSplitter().convert(utf8.decode(stderrBytes)).where((l) => !l.contains('Warning: Activity not started')).join('\n').trim();

      String output = '';
      if (out.isNotEmpty) output += '\n\nOutput:\n$out';
      if (err.isNotEmpty) output += '\n\nError:\n$err';
      return 'EXECUTION ACK: Command "$command" triggered successfully$output';
    } catch (e) {
      return 'Failed to execute command: $e';
    }
  }

  Future<String> _executeDesktopCommand(String command) async {
    try {
      final tokens = _parseCommandLine(command);
      if (tokens.isEmpty) return 'Error: Empty command.';

      final exec = tokens.first;
      final args = tokens.sublist(1);
      final appName = exec.split(Platform.isWindows ? '\\' : '/').last.replaceAll('.exe', '').toLowerCase();

      final process = await Process.start(exec, args);
      processRegistry[appName] = process.pid;

      return 'EXECUTION ACK: Command "$command" triggered. Process: "$appName" (PID: ${process.pid}).';
    } catch (e) {
      return 'Failed to execute command: $e';
    }
  }

  Future<String> _launchUrl(String rawUrl) async {
    try {
      final urlStr = rawUrl.replaceAll(' ', '%20');
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'EXECUTION ACK: Opened $urlStr in browser.';
      }
      return 'Error: Could not launch URL: $urlStr';
    } catch (e) {
      return 'Error opening URL: $e';
    }
  }

  Future<String> _launchApp(String pkg) async {
    final dynamicLauncher = phoneController.appScanner.resolveLauncher(pkg);

    bool isInstalled = false;
    try {
      final pmPathRes = await Process.run('sh', ['-c', 'pm path $pkg 2>&1 </dev/null']);
      isInstalled = pmPathRes.exitCode == 0 && pmPathRes.stdout.toString().contains('package:');
      if (!isInstalled) {
        final pmListRes = await Process.run('sh', ['-c', 'pm list packages 2>&1 </dev/null']);
        isInstalled = pmListRes.exitCode == 0 && pmListRes.stdout.toString().contains('package:$pkg');
      }
    } catch (_) {
      isInstalled = true;
    }

    if (isInstalled) {
      final cmd = dynamicLauncher != null ? 'am start -n $dynamicLauncher' : 'am start -n $pkg/.MainActivity';
      try {
        await Process.run('sh', ['-c', cmd]);
        return 'EXECUTION ACK: Launched $pkg.';
      } catch (e) {
        return 'Failed to launch $pkg: $e';
      }
    }
    return 'EXECUTION ACK: $pkg is not installed on this device.';
  }

  Future<String> _handleClose(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final appTarget = match.group(1)?.trim().toLowerCase() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Terminating target: $appTarget');

    String ackMsg;
    final targetPidVal = int.tryParse(appTarget);

    if (targetPidVal != null) {
      ackMsg = await _killPid(targetPidVal);
    } else if (processRegistry.containsKey(appTarget)) {
      final pid = processRegistry[appTarget]!;
      ackMsg = await _killPid(pid);
      processRegistry.remove(appTarget);
    } else {
      try {
        final result = Platform.isWindows
            ? await Process.run('taskkill', ['/F', '/IM', '$appTarget.exe'])
            : await Process.run('pkill', ['-f', appTarget]);
        ackMsg = 'EXECUTION ACK: "$appTarget" termination attempted.\n${result.stdout}';
      } catch (e) {
        ackMsg = 'Error: "$appTarget" is not running or not found.';
      }
    }

    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _killPid(int pid) async {
    try {
      final result = Platform.isWindows
          ? await Process.run('taskkill', ['/F', '/PID', pid.toString()])
          : await Process.run('kill', ['-9', pid.toString()]);
      processRegistry.removeWhere((_, v) => v == pid);
      return 'EXECUTION ACK: Process PID $pid terminated.\n${result.stdout}';
    } catch (e) {
      return 'Failed to terminate PID $pid: $e';
    }
  }

  Future<String> _handleSearch(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final query = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Searching media: $query');
    final ackMsg = await _searchMedia(query);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleTap(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final x = int.parse(match.group(1)!);
    final y = int.parse(match.group(2)!);
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Tapping at ($x, $y)...');
    onCursorMove?.call(x.toDouble(), y.toDouble(), true);
    await Future.delayed(const Duration(milliseconds: 350));
    final ackMsg = await phoneController.tap(x, y);
    await Future.delayed(const Duration(milliseconds: 150));
    onCursorMove?.call(x.toDouble(), y.toDouble(), false);
    await Future.delayed(const Duration(milliseconds: 200));
    onCursorHide?.call();
    recordPattern(userMessage, 'TAP: $x $y');
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleSwipe(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final x1 = int.parse(match.group(1)!);
    final y1 = int.parse(match.group(2)!);
    final x2 = int.parse(match.group(3)!);
    final y2 = int.parse(match.group(4)!);
    final dur = match.group(5) != null ? int.parse(match.group(5)!) : AppConstants.defaultSwipeDuration;
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Swiping from ($x1, $y1) to ($x2, $y2)...');
    onCursorMove?.call(x1.toDouble(), y1.toDouble(), false);
    await Future.delayed(const Duration(milliseconds: 200));
    onCursorMove?.call(x2.toDouble(), y2.toDouble(), false);
    await Future.delayed(const Duration(milliseconds: 350));
    final ackMsg = await phoneController.swipe(x1, y1, x2, y2, durationMs: dur);
    await Future.delayed(const Duration(milliseconds: 200));
    onCursorHide?.call();
    recordPattern(userMessage, 'SWIPE: $x1 $y1 $x2 $y2 $dur');
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleType(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final text = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Typing: "$text"');
    final ackMsg = await phoneController.typeText(text);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleNav(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final action = match.group(1)!;
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Navigation: $action');
    final ackMsg = await phoneController.navigate(action);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleScreenshot() async {
    onStatus('Taking screenshot...');
    return await phoneController.screenshot();
  }

  Future<String> _handleDumpUI() async {
    onStatus('Scanning screen elements...');
    return await phoneController.dumpUI();
  }

  Future<String> _handleVision(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final query = match.group(1)?.trim() ?? 'Describe what you see';
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Analyzing screen...');
    final ssResult = await phoneController.screenshot();
    final ackMsg = 'VISION: Screen analyzed. $ssResult\nQuery: $query';
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleOpenApp(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final query = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    onStatus('Opening app: $query');
    final pkg = phoneController.findAppPackage(query);
    final ackMsg = await phoneController.openApp(pkg ?? query);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleListApps() async {
    onStatus('Listing installed apps...');
    return phoneController.listApps();
  }

  Future<String> _handleUninstall(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final query = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();
    final pkg = phoneController.findAppPackage(query);
    final ackMsg = await phoneController.uninstallApp(pkg ?? query);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleReadFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '';
    return phoneController.readFile(path);
  }

  Future<String> _handleWriteFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '';
    final content = match.group(2)?.trim() ?? '';
    return phoneController.writeFile(path, content);
  }

  Future<String> _handleEditFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '';
    final oldStr = match.group(2)?.trim() ?? '';
    final newStr = match.group(3)?.trim() ?? '';
    return phoneController.editFile(path, oldStr, newStr);
  }

  Future<String> _handleListDir(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '.';
    return phoneController.listDir(path);
  }

  Future<String> _handleDeleteFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '';
    return phoneController.deleteFile(path);
  }

  Future<String> _handleMkdir(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '';
    return phoneController.mkdir(path);
  }

  Future<String> _handleCopyFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    return phoneController.copyFile(match.group(1)!, match.group(2)!);
  }

  Future<String> _handleMoveFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    return phoneController.moveFile(match.group(1)!, match.group(2)!);
  }

  Future<String> _handleAppendFile(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final path = match.group(1)?.trim() ?? '';
    final content = match.group(2)?.trim() ?? '';
    return phoneController.appendFile(path, content);
  }

  Future<String> _handleClipboardGet() async {
    onStatus('Reading clipboard...');
    return phoneController.clipboardGet();
  }

  Future<String> _handleClipboardSet(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final text = match.group(1)?.trim() ?? '';
    return phoneController.clipboardSet(text);
  }

  Future<String> _handleContacts() async {
    onStatus('Loading contacts...');
    return phoneController.contacts();
  }

  Future<String> _handleSms(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    return phoneController.sendSms(match.group(1)?.trim() ?? '', match.group(2)?.trim() ?? '');
  }

  Future<String> _handleCallLog() async {
    onStatus('Loading call log...');
    return phoneController.callLog();
  }

  Future<String> _handleCalendar() async {
    onStatus('Loading calendar events...');
    return phoneController.calendarEvents();
  }

  Future<String> _handleCamera() async {
    onStatus('Opening camera...');
    return phoneController.camera();
  }

  Future<String> _handleRecord() async {
    onStatus('Opening video recorder...');
    return phoneController.record();
  }

  Future<String> _handleGallery() async {
    onStatus('Loading gallery...');
    return phoneController.gallery();
  }

  Future<String> _handleMic() async {
    onStatus('Opening audio recorder...');
    return phoneController.mic();
  }

  Future<String> _handleNotifications() async {
    onStatus('Loading notifications...');
    return phoneController.notifications();
  }

  Future<String> _handlePostNotif(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    return phoneController.postNotification(match.group(1)?.trim() ?? 'Zournia', match.group(2)?.trim() ?? '');
  }

  Future<String> _handleDeviceInfo() async {
    onStatus('Gathering device info...');
    return phoneController.deviceInfo();
  }

  Future<String> _handleBattery() => phoneController.battery();
  Future<String> _handleStorage() => phoneController.storage();
  Future<String> _handleRam() => phoneController.ram();

  Future<String> _handleNetwork() async {
    onStatus('Checking network...');
    return phoneController.network();
  }

  Future<String> _handleEnv(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    return phoneController.env(match.group(1)?.trim() ?? '');
  }

  Future<String> _handleDoubleTap(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final x = int.parse(match.group(1)!);
    final y = int.parse(match.group(2)!);
    onCursorMove?.call(x.toDouble(), y.toDouble(), true);
    await Future.delayed(const Duration(milliseconds: 350));
    final ackMsg = await phoneController.doubleTap(x, y);
    await Future.delayed(const Duration(milliseconds: 150));
    onCursorMove?.call(x.toDouble(), y.toDouble(), false);
    await Future.delayed(const Duration(milliseconds: 200));
    onCursorHide?.call();
    return ackMsg;
  }

  Future<String> _handleLongPress(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final x = int.parse(match.group(1)!);
    final y = int.parse(match.group(2)!);
    final dur = match.group(3) != null ? int.parse(match.group(3)!) : AppConstants.defaultLongPressDuration;
    onCursorMove?.call(x.toDouble(), y.toDouble(), false);
    await Future.delayed(const Duration(milliseconds: 200));
    final ackMsg = await phoneController.longPress(x, y, durationMs: dur);
    await Future.delayed(const Duration(milliseconds: 200));
    onCursorHide?.call();
    return ackMsg;
  }

  Future<String> _handleShell(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final command = match.group(1)?.trim() ?? '';
    onStatus('Running shell: $command');
    return phoneController.shell(command);
  }

  // ── Media search ────────────────────────────────────────────────────────

  Future<String> _searchMedia(String query) async {
    final parts = query.trim().split(RegExp(r'\s+'));
    String platform = 'youtube';
    String searchTerm = query.trim();

    if (parts.isNotEmpty && AppConstants.knownPlatforms.contains(parts.first.toLowerCase())) {
      platform = parts.first.toLowerCase();
      searchTerm = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    if (searchTerm.trim().isEmpty) {
      final uri = Uri.parse(AppConstants.platformHomepages[platform] ?? 'https://www.google.com');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened ${platform[0].toUpperCase()}${platform.substring(1)} homepage.';
      }
      return 'Error: Could not open $platform homepage.';
    }

    final encoded = Uri.encodeComponent(searchTerm);
    final deepLinks = AppConstants.platformDeepLinks[platform] ?? AppConstants.platformDeepLinks['google']!;
    final bool isMobileLocal = _isMobile;

    if (isMobileLocal && deepLinks.containsKey('package')) {
      final pkg = deepLinks['package']!;
      bool isInstalled = false;
      try {
        final res = await Process.run('sh', ['-c', 'pm path $pkg 2>&1 </dev/null']);
        isInstalled = res.exitCode == 0 && res.stdout.toString().contains('package:');
      } catch (_) {
        isInstalled = true;
      }

      if (isInstalled && deepLinks.containsKey('deepLink')) {
        try {
          final uri = Uri.parse(deepLinks['deepLink']!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return 'Searched "$searchTerm" on ${platform[0].toUpperCase()}${platform.substring(1)}.';
          }
        } catch (_) {}
      }

      if (deepLinks.containsKey('webUrl')) {
        try {
          final result = await Process.run('sh', ['-c', 'am start -a android.intent.action.VIEW -d "${deepLinks['webUrl']}" com.android.chrome']);
          if (result.exitCode == 0) return 'Searched "$searchTerm" on ${platform[0].toUpperCase()}${platform.substring(1)} (via browser).';
        } catch (_) {}
      }
    }

    final webUrl = deepLinks['webUrl'] ?? 'https://www.google.com/search?q=$encoded';
    try {
      final uri = Uri.parse(webUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Searched "$searchTerm" on ${platform[0].toUpperCase()}${platform.substring(1)}.';
      }
      return 'Error: Could not launch search URL.';
    } catch (e) {
      return 'Error searching media: $e';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  List<String> _parseCommandLine(String commandLine) {
    final args = <String>[];
    var inQuotes = false;
    final current = StringBuffer();

    for (final char in commandLine.split('')) {
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ' ' && !inQuotes) {
        if (current.isNotEmpty) {
          args.add(current.toString());
          current.clear();
        }
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) args.add(current.toString());
    return args;
  }
}
