import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/update/update_manager.dart';
import '../../../core/services/ai_service.dart';
import '../../chat/chat_service.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../workspace_router/presentation/workspace_canvas.dart';
import '../../ui_components/dropdown_menu.dart';
import '../../automation/data/phone_controller.dart';
import '../../automation/presentation/cursor_overlay.dart';

import 'sidebar.dart';
import 'chat_view.dart';
import 'settings_view.dart';

// ── Session State ────────────────────────────────────────────────────────────

class SessionState {
  String lastAction;
  int? targetPid;
  String intentTracking;

  SessionState({this.lastAction = '', this.targetPid, this.intentTracking = ''});

  Map<String, dynamic> toJson() => {
    'lastAction': lastAction,
    'targetPid': targetPid,
    'intentTracking': intentTracking,
  };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
    lastAction: json['lastAction'] ?? '',
    targetPid: json['targetPid'],
    intentTracking: json['intentTracking'] ?? '',
  );
}

// ── Shell State ──────────────────────────────────────────────────────────────

class ZourniaShell extends StatefulWidget {
  const ZourniaShell({super.key});
  @override
  State<ZourniaShell> createState() => _ZourniaShellState();
}

class _ZourniaShellState extends State<ZourniaShell> {
  // ── View state ────────────────────────────────────────────────────────
  AppView _currentView = AppView.workspace;
  String _chatMode = 'default';
  String _selectedModel = 'FreeModel';
  final List<String> _workspaces = ['Workspace'];
  int _activeWorkspaceIndex = 0;

  // ── Chat state ────────────────────────────────────────────────────────
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Settings state ────────────────────────────────────────────────────
  final Map<String, String> _apiKeys = {};
  List<Map<String, dynamic>> _customModels = [];

  // ── Update state ──────────────────────────────────────────────────────
  bool _checkingForUpdates = false;
  bool _updateProgressActive = false;
  double _updateProgress = 0.0;
  UpdateInfo? _updateInfo;
  String _updateStatusMessage = '';

  // ── Session & automation ──────────────────────────────────────────────
  final Map<String, int> _processRegistry = {};
  SessionState _sessionState = SessionState();
  final PhoneController _phoneController = PhoneController();
  bool _cursorVisible = false;
  double _cursorX = 100;
  double _cursorY = 100;
  bool _cursorClicking = false;

  // ── Computed ──────────────────────────────────────────────────────────

  List<String> get _allModelNames {
    final list = <String>['Qwen 3.6 Coder', 'Gemini', 'Dolphin', 'Hermes', 'FreeModel', 'Auto'];
    for (final cm in _customModels) {
      final name = cm['name'] as String?;
      if (name != null && name.isNotEmpty) list.add(name);
    }
    list.add('Settings');
    return list;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
    _loadCustomModels();
    _loadSessionState();
    _phoneController.loadPatterns();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────

  Future<void> _loadApiKeys() async {
    try {
      final jsonFile = File('api_keys.json');
      final legacyFile = File('api_key.txt');

      if (await jsonFile.exists()) {
        final content = await jsonFile.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          setState(() {
            _apiKeys.clear();
            decoded.forEach((k, v) => _apiKeys[k] = v.toString());
          });
        }
      } else if (await legacyFile.exists()) {
        final key = (await legacyFile.readAsString()).trim();
        if (key.isNotEmpty) {
          setState(() => _apiKeys['OpenRouter'] = key);
          await _saveApiKeys();
        }
      }
    } catch (e) {
      debugPrint('Error loading API keys: $e');
    }
  }

  Future<void> _saveApiKeys() async {
    try {
      await File('api_keys.json').writeAsString(jsonEncode(_apiKeys));
      await File('api_key.txt').writeAsString(_apiKeys['OpenRouter'] ?? '');
    } catch (e) {
      debugPrint('Error saving API keys: $e');
    }
  }

  Future<void> _loadCustomModels() async {
    try {
      final file = File('custom_models.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List;
          setState(() {
            _customModels = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading custom models: $e');
    }
  }

  Future<void> _saveCustomModels() async {
    try {
      await File('custom_models.json').writeAsString(jsonEncode(_customModels));
    } catch (e) {
      debugPrint('Error saving custom models: $e');
    }
  }

  Future<void> _loadSessionState() async {
    try {
      final file = File('session_state.json');
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        setState(() => _sessionState = SessionState.fromJson(json));
      }
    } catch (e) {
      debugPrint('Error loading SessionState: $e');
    }
  }

  Future<void> _saveSessionState() async {
    try {
      await File('session_state.json').writeAsString(jsonEncode(_sessionState.toJson()));
    } catch (e) {
      debugPrint('Error saving SessionState: $e');
    }
  }

  // ── Update management ─────────────────────────────────────────────────

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
      _updateStatusMessage = 'Checking update server...';
      _updateInfo = null;
    });
    try {
      final info = await UpdateManager.check();
      setState(() {
        _updateInfo = info;
        _checkingForUpdates = false;
        _updateStatusMessage = info.isUpdateAvailable
            ? 'New version ${info.version} is available!'
            : 'System is up to date.';
      });
    } catch (e) {
      setState(() {
        _checkingForUpdates = false;
        _updateStatusMessage = 'Error checking for updates: $e';
      });
    }
  }

  Future<void> _installUpdate() async {
    if (_updateInfo == null || !_updateInfo!.isUpdateAvailable) return;
    setState(() {
      _updateProgressActive = true;
      _updateProgress = 0.0;
      _updateStatusMessage = 'Downloading update package...';
    });
    try {
      await UpdateManager.apply(_updateInfo!.zipUrl, (p) => setState(() => _updateProgress = p));
    } catch (e) {
      setState(() {
        _updateProgressActive = false;
        _updateStatusMessage = 'Installation failed: $e';
      });
    }
  }

  // ── Chat commands ─────────────────────────────────────────────────────

  void _handleChatCommand(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    final sub = parts.length > 1 ? parts[1].toLowerCase() : 'config';
    final extra = parts.length > 2 ? parts.sublist(2).join(' ') : '';

    String result;
    switch (sub) {
      case 'config':
        result = 'Chat Config:\n  Model: $_selectedModel\n  Mode: $_chatMode\n  Messages: ${_messages.length}\n  Processes: ${_processRegistry.length}';
      case 'clear':
        setState(() => _messages.clear());
        result = 'Chat history cleared.';
      case 'list':
        final names = ChatService.list();
        result = names.isEmpty ? 'No saved chats.' : 'Saved chats:\n${names.map((n) => '  - $n').join('\n')}';
      case 'save':
        final name = extra.isNotEmpty ? extra : 'chat_${DateTime.now().millisecondsSinceEpoch}';
        ChatService.save(name: name, messages: _messages, model: _selectedModel, mode: _chatMode);
        result = 'Chat saved to $name.';
      case 'load':
        if (extra.isEmpty) { result = 'Usage: !chat load <name>'; break; }
        ChatService.load(extra).then((r) {
          if (r == null) {
            setState(() => _addBotMessage('Chat "$extra" not found.'));
          } else {
            setState(() {
              _messages.clear();
              for (final m in r.messages) { _messages.add(m); }
              if (r.model != null) _selectedModel = r.model!;
              if (r.mode != null) _chatMode = r.mode!;
              _addBotMessage('Chat "$extra" loaded (${_messages.length} messages).');
            });
          }
        });
        return;
      case 'export':
        final name = extra.isNotEmpty ? extra : 'export_${DateTime.now().millisecondsSinceEpoch}';
        ChatService.export(name: name, messages: _messages);
        result = 'Chat exported to $name.txt';
      case 'delete':
        if (extra.isEmpty) { result = 'Usage: !chat delete <name>'; break; }
        result = ChatService.delete(extra) ? 'Deleted chat "$extra".' : 'Chat "$extra" not found.';
      case 'continue':
        if (extra.isEmpty) { result = 'Usage: !chat continue <name>'; break; }
        ChatService.load(extra).then((r) {
          if (r == null) {
            setState(() => _addBotMessage('Chat "$extra" not found.'));
          } else {
            setState(() {
              for (final m in r.messages) { _messages.add(m); }
              if (r.model != null) _selectedModel = r.model!;
              if (r.mode != null) _chatMode = r.mode!;
              _addBotMessage('Chat "$extra" continued (${_messages.length} total).');
            });
          }
        });
        return;
      default:
        result = 'Chat Commands:\n  !chat config — Show configuration\n  !chat save [name] — Save chat\n  !chat load <name> — Load chat\n  !chat continue <name> — Continue chat\n  !chat list — List saved chats\n  !chat export [name] — Export as text\n  !chat clear — Clear history\n  !chat delete <name> — Delete chat';
    }
    setState(() => _addBotMessage(result));
  }

  void _addBotMessage(String text) {
    if (_messages.isNotEmpty && _messages.last['text'] == 'Thinking...') {
      _messages.removeLast();
    }
    _messages.add({'sender': _selectedModel, 'text': text});
  }

  // ── AI interaction ────────────────────────────────────────────────────

  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty) return;
    final userMessage = text;
    _inputController.clear();

    if (userMessage.trim().startsWith('!')) {
      setState(() => _messages.add({'sender': 'user', 'text': userMessage}));
      _scrollToBottom();
      _handleChatCommand(userMessage);
      _scrollToBottom();
      return;
    }

    setState(() => _messages.add({'sender': 'user', 'text': userMessage}));
    _scrollToBottom();
    setState(() => _messages.add({'sender': _selectedModel, 'text': 'Thinking...'}));
    _scrollToBottom();

    try {
      final rawResponse = await _getAiResponse(userMessage);
      String cleanResponse = rawResponse.trim();

      final intentRegex = RegExp(r'^INTENT:\s*(.*)$', multiLine: true);
      final intentMatch = intentRegex.firstMatch(rawResponse);
      if (intentMatch != null) {
        final newIntent = intentMatch.group(1)?.trim() ?? '';
        if (newIntent.isNotEmpty) {
          _sessionState.intentTracking = newIntent;
          await _saveSessionState();
        }
        cleanResponse = cleanResponse.replaceAll(intentRegex, '').trim();
      }

      if (_chatMode == 'automation' || _chatMode == 'default') {
        cleanResponse = await _processCommands(cleanResponse, userMessage);
      }

      if (mounted) {
        setState(() {
          _removeThinkingMessage();
          _messages.add({'sender': _selectedModel, 'text': cleanResponse});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _removeThinkingMessage();
          _messages.add({'sender': 'system', 'text': 'Error: $e'});
        });
        _scrollToBottom();
      }
    }
  }

  void _removeThinkingMessage() {
    if (_messages.isNotEmpty) {
      final last = _messages.last['text'] ?? '';
      if (last == 'Thinking...' || _isStatusMessage(last)) {
        _messages.removeLast();
      }
    }
  }

  bool _isStatusMessage(String text) {
    const prefixes = ['Executing', 'Terminating', 'Searching', 'Tapping', 'Swiping', 'Typing', 'Navigation', 'Taking', 'Scanning'];
    return prefixes.any((p) => text.startsWith(p));
  }

  // ── Command processing ────────────────────────────────────────────────

  Future<String> _processCommands(String cleanResponse, String userMessage) async {
    final executeRegex = RegExp(r'^EXECUTE:\s*(.*)$', multiLine: true);
    final closeRegex = RegExp(r'^CLOSE:\s*(.*)$', multiLine: true);
    final searchRegex = RegExp(r'^SEARCH:\s*(.*)$', multiLine: true);
    final tapRegex = RegExp(r'^TAP:\s*(\d+)\s+(\d+)$', multiLine: true);
    final swipeRegex = RegExp(r'^SWIPE:\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)(?:\s+(\d+))?$', multiLine: true);
    final typeRegex = RegExp(r'^TYPE:\s*(.*)$', multiLine: true);
    final navRegex = RegExp(r'^NAV:\s*(\w+)$', multiLine: true);
    final screenshotRegex = RegExp(r'^SCREENSHOT:\s*$', multiLine: true);
    final uiDumpRegex = RegExp(r'^DUMPUI:\s*$', multiLine: true);

    if (executeRegex.hasMatch(cleanResponse)) {
      return await _handleExecute(executeRegex, cleanResponse, userMessage);
    } else if (closeRegex.hasMatch(cleanResponse)) {
      return await _handleClose(closeRegex, cleanResponse);
    } else if (searchRegex.hasMatch(cleanResponse)) {
      return await _handleSearch(searchRegex, cleanResponse);
    } else if (tapRegex.hasMatch(cleanResponse)) {
      return await _handleTap(tapRegex, cleanResponse, userMessage);
    } else if (swipeRegex.hasMatch(cleanResponse)) {
      return await _handleSwipe(swipeRegex, cleanResponse, userMessage);
    } else if (typeRegex.hasMatch(cleanResponse)) {
      return await _handleType(typeRegex, cleanResponse);
    } else if (navRegex.hasMatch(cleanResponse)) {
      return await _handleNav(navRegex, cleanResponse);
    } else if (screenshotRegex.hasMatch(cleanResponse)) {
      return await _handleScreenshot(screenshotRegex, cleanResponse);
    } else if (uiDumpRegex.hasMatch(cleanResponse)) {
      return await _handleDumpUI(uiDumpRegex, cleanResponse);
    }
    return cleanResponse;
  }

  Future<String> _handleExecute(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final command = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() => _addBotMessage('Executing automation command: $command'));
    _scrollToBottom();

    final bool isMobile = !kIsWeb && !(Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    String ackMsg;

    if (isMobile) {
      ackMsg = await _executeMobileCommand(command);
    } else {
      ackMsg = await _executeDesktopCommand(command);
    }

    _sessionState.lastAction = 'EXECUTE: $command';
    await _saveSessionState();

    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _executeMobileCommand(String command) async {
    final urlPattern = RegExp(r'"(https?://[^"]+)"');
    var urlMatch = urlPattern.firstMatch(command);
    urlMatch ??= RegExp(r"'(https?://[^']+)'").firstMatch(command);
    urlMatch ??= RegExp(r'''(https?://[^\s"']+)''').firstMatch(command);
    if (urlMatch != null) {
      return _launchUrl(urlMatch.group(1)!);
    }

    final launchRegex = RegExp(r'(?:am start|monkey -p)\s+([a-zA-Z0-9._]+)(?:\s+1)?$');
    final launchMatch = launchRegex.firstMatch(command.trim());
    if (launchMatch != null) {
      return _launchApp(launchMatch.group(1)!);
    }

    try {
      final process = await Process.start('sh', ['-c', command]);
      _sessionState.targetPid = process.pid;
      await _saveSessionState();

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
      _processRegistry[appName] = process.pid;
      _sessionState.lastAction = 'EXECUTE: $command';
      _sessionState.targetPid = process.pid;
      await _saveSessionState();

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
    final dynamicLauncher = _phoneController.appScanner.resolveLauncher(pkg);

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

    final fallbackUrl = 'https://www.google.com/search?q=${pkg.split('.').last}';
    return _launchUrl(fallbackUrl);
  }

  Future<String> _handleClose(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final appTarget = match.group(1)?.trim().toLowerCase() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() => _addBotMessage('Terminating target: $appTarget'));
    _scrollToBottom();

    String ackMsg;
    final targetPidVal = int.tryParse(appTarget);

    if (targetPidVal != null) {
      ackMsg = await _killPid(targetPidVal);
    } else if (_processRegistry.containsKey(appTarget)) {
      final pid = _processRegistry[appTarget]!;
      ackMsg = await _killPid(pid);
      _processRegistry.remove(appTarget);
    } else if (_sessionState.targetPid != null && ['it', 'process', 'that process'].contains(appTarget)) {
      ackMsg = await _killPid(_sessionState.targetPid!);
      _sessionState.targetPid = null;
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

    _sessionState.lastAction = 'CLOSE: $appTarget';
    await _saveSessionState();

    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _killPid(int pid) async {
    try {
      final result = Platform.isWindows
          ? await Process.run('taskkill', ['/F', '/PID', pid.toString()])
          : await Process.run('kill', ['-9', pid.toString()]);
      _processRegistry.removeWhere((_, v) => v == pid);
      if (_sessionState.targetPid == pid) _sessionState.targetPid = null;
      return 'EXECUTION ACK: Process PID $pid terminated.\n${result.stdout}';
    } catch (e) {
      return 'Failed to terminate PID $pid: $e';
    }
  }

  Future<String> _handleSearch(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final query = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() => _addBotMessage('Searching media: $query'));
    _scrollToBottom();

    final ackMsg = await _searchMedia(query);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleTap(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final x = int.parse(match.group(1)!);
    final y = int.parse(match.group(2)!);
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() {
      _cursorVisible = true;
      _cursorX = x.toDouble();
      _cursorY = y.toDouble();
      _cursorClicking = true;
      _addBotMessage('Tapping at ($x, $y)...');
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 350));
    final ackMsg = await _phoneController.tap(x, y);
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _cursorClicking = false);
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => _cursorVisible = false);

    _phoneController.recordPattern(userMessage, 'TAP: $x $y');
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleSwipe(RegExp regex, String response, String userMessage) async {
    final match = regex.firstMatch(response)!;
    final x1 = int.parse(match.group(1)!);
    final y1 = int.parse(match.group(2)!);
    final x2 = int.parse(match.group(3)!);
    final y2 = int.parse(match.group(4)!);
    final dur = match.group(5) != null ? int.parse(match.group(5)!) : 300;
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() {
      _cursorVisible = true;
      _cursorX = x1.toDouble();
      _cursorY = y1.toDouble();
      _addBotMessage('Swiping from ($x1, $y1) to ($x2, $y2)...');
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 200));
    setState(() { _cursorX = x2.toDouble(); _cursorY = y2.toDouble(); });
    await Future.delayed(const Duration(milliseconds: 350));
    final ackMsg = await _phoneController.swipe(x1, y1, x2, y2, durationMs: dur);
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => _cursorVisible = false);

    _phoneController.recordPattern(userMessage, 'SWIPE: $x1 $y1 $x2 $y2 $dur');
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleType(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final text = match.group(1)?.trim() ?? '';
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() => _addBotMessage('Typing: "$text"'));
    _scrollToBottom();

    final ackMsg = await _phoneController.typeText(text);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleNav(RegExp regex, String response) async {
    final match = regex.firstMatch(response)!;
    final action = match.group(1)!;
    final cleaned = response.replaceAll(regex, '').trim();

    setState(() => _addBotMessage('Navigation: $action'));
    _scrollToBottom();

    final ackMsg = await _phoneController.navigate(action);
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleScreenshot(RegExp regex, String response) async {
    final cleaned = response.replaceAll(regex, '').trim();
    setState(() => _addBotMessage('Taking screenshot...'));
    _scrollToBottom();
    final ackMsg = await _phoneController.screenshot();
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  Future<String> _handleDumpUI(RegExp regex, String response) async {
    final cleaned = response.replaceAll(regex, '').trim();
    setState(() => _addBotMessage('Scanning screen elements...'));
    _scrollToBottom();
    final ackMsg = await _phoneController.dumpUI();
    return cleaned.isNotEmpty ? '$cleaned\n\n$ackMsg' : ackMsg;
  }

  // ── AI response ───────────────────────────────────────────────────────

  Future<String> _getAiResponse(String prompt) async {
    final resolved = AiService.resolve(
      selectedModel: _selectedModel,
      apiKeys: _apiKeys,
      customModels: _customModels,
    );

    String apiKey = _apiKeys[resolved.provider] ?? '';
    if (apiKey.isEmpty) {
      apiKey = _apiKeys['OpenRouter'] ?? '';
    }

    if (apiKey.isEmpty) {
      return 'Error: API key not configured in Settings.';
    }

    final modelUrl = apiKey == _apiKeys['OpenRouter'] ? 'https://openrouter.ai/api/v1/chat/completions' : resolved.url;
    final modelName = apiKey == _apiKeys['OpenRouter'] && AiService.defaultModels.containsKey(_selectedModel)
        ? AiService.defaultModels[_selectedModel]!
        : resolved.modelName;

    final sessionStr = 'Active Session State:\n'
        '- LAST_ACTION: ${_sessionState.lastAction.isEmpty ? "None" : _sessionState.lastAction}\n'
        '- TARGET_PID: ${_sessionState.targetPid ?? "None"}\n'
        '- INTENT_TRACKING: ${_sessionState.intentTracking.isEmpty ? "None" : _sessionState.intentTracking}\n';

    final systemPrompt = _buildSystemPrompt(sessionStr);
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    final historyStart = _messages.length > 10 ? _messages.length - 10 : 0;
    for (var i = historyStart; i < _messages.length; i++) {
      final msg = _messages[i];
      final text = msg['text'];
      if (text != null && text != 'Thinking...' && !_isStatusMessage(text)) {
        final role = msg['sender'] == 'user' ? 'user' : 'assistant';
        messages.add({'role': role, 'content': text});
      }
    }
    messages.add({'role': 'user', 'content': prompt});

    return AiService.chat(model: modelName, url: modelUrl, apiKey: apiKey, messages: messages);
  }

  String _buildSystemPrompt(String sessionStr) {
    final discoveredApps = _phoneController.getDiscoveredAppsSummary();
    final sysInfo = _getSystemInfo();

    if (_chatMode == 'normal') {
      return 'You are Zournia, a friendly assistant. Talk naturally and informally. '
          'Do NOT output any EXECUTE, SEARCH, CLOSE, TAP, SWIPE, TYPE, NAV, SCREENSHOT, or DUMPUI commands. '
          'Just chat normally.\n\n$sessionStr\n\n$sysInfo\n\n$discoveredApps';
    }

    return 'You are a function-calling tool. Given a user request, output the matching function call.\n'
        'Reply with a very short confirmation, then on the next line output the function call.\n'
        'CRITICAL: ALWAYS use Chrome as the default browser.\n'
        'Functions:\n'
        'EXECUTE: <command>\n'
        'SEARCH: <platform> <query> (platforms: youtube, spotify, netflix, tiktok, google, amazon, twitch, soundcloud)\n'
        'CLOSE: <name>\n'
        'TAP: <x> <y>\n'
        'SWIPE: <x1> <y1> <x2> <y2>\n'
        'TYPE: <text>\n'
        'NAV: <action> (back, home, recents, enter, delete, tab, escape, power, volume_up, volume_down)\n'
        'SCREENSHOT:\n'
        'DUMPUI:\n'
        'Multiple functions can be output, one per line.\n\n'
        '$sessionStr\n\n$sysInfo\n\n$discoveredApps';
  }

  String _getSystemInfo() {
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (!isDesktop) {
      final homeDir = Platform.environment['HOME'] ?? '/data/data/com.termux/files/home';
      final user = Platform.environment['USER'] ?? 'u0_a0';
      return 'Environment: Android/Termux\nUSER: $user\nHOME: $homeDir\n'
          'Commands: EXECUTE: <cmd>, TAP: <x> <y>, SWIPE: <x1> <y1> <x2> <y2>, TYPE: <text>, NAV: <action>, SCREENSHOT:, DUMPUI:';
    }

    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Admin';
    final userName = Platform.environment['USERNAME'] ?? 'Admin';
    return 'Environment: Windows Desktop\nUSERNAME: $userName\nUSERPROFILE: $userProfile\n'
        'DESKTOP: $userProfile\\Desktop\nDOCUMENTS: $userProfile\\Documents\nDOWNLOADS: $userProfile\\Downloads';
  }

  // ── Media search ──────────────────────────────────────────────────────

  Future<String> _searchMedia(String query) async {
    final parts = query.trim().split(RegExp(r'\s+'));
    String platform = 'youtube';
    String searchTerm = query.trim();

    const knownPlatforms = ['youtube', 'spotify', 'netflix', 'tiktok', 'google', 'amazon', 'twitch', 'soundcloud'];
    if (parts.isNotEmpty && knownPlatforms.contains(parts.first.toLowerCase())) {
      platform = parts.first.toLowerCase();
      searchTerm = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    if (searchTerm.trim().isEmpty) {
      final homepages = {
        'youtube': 'https://www.youtube.com',
        'spotify': 'https://open.spotify.com',
        'netflix': 'https://www.netflix.com',
        'tiktok': 'https://www.tiktok.com',
        'google': 'https://www.google.com',
        'amazon': 'https://www.amazon.com',
        'twitch': 'https://www.twitch.tv',
        'soundcloud': 'https://soundcloud.com',
      };
      final uri = Uri.parse(homepages[platform] ?? 'https://www.google.com');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened ${platform[0].toUpperCase()}${platform.substring(1)} homepage.';
      }
      return 'Error: Could not open $platform homepage.';
    }

    final encoded = Uri.encodeComponent(searchTerm);
    final deepLinks = {
      'youtube': {'package': 'com.google.android.youtube', 'deepLink': 'intent://search?q=$encoded#Intent;package=com.google.android.youtube;end', 'webUrl': 'https://www.youtube.com/results?search_query=$encoded'},
      'spotify': {'package': 'com.spotify.music', 'deepLink': 'spotify:search:$encoded', 'webUrl': 'https://open.spotify.com/search/$encoded'},
      'netflix': {'package': 'com.netflix.mediaclient', 'deepLink': 'nflx://search?q=$encoded', 'webUrl': 'https://www.netflix.com/search?q=$encoded'},
      'tiktok': {'package': 'com.zhiliaoapp.musically', 'deepLink': 'snssdk1128://search?keyword=$encoded', 'webUrl': 'https://www.tiktok.com/search?q=$encoded'},
      'google': {'webUrl': 'https://www.google.com/search?q=$encoded'},
      'amazon': {'package': 'com.amazon.mShop.android.shopping', 'webUrl': 'https://www.amazon.com/s?k=$encoded'},
      'twitch': {'package': 'tv.twitch.android.app', 'webUrl': 'https://www.twitch.tv/search?term=$encoded'},
      'soundcloud': {'package': 'com.soundcloud.android', 'webUrl': 'https://soundcloud.com/search?q=$encoded'},
    };

    final info = deepLinks[platform] ?? deepLinks['google']!;
    final bool isMobile = !kIsWeb && !(Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isMobile && info.containsKey('package')) {
      final pkg = info['package']!;
      bool isInstalled = false;
      try {
        final res = await Process.run('sh', ['-c', 'pm path $pkg 2>&1 </dev/null']);
        isInstalled = res.exitCode == 0 && res.stdout.toString().contains('package:');
      } catch (_) { isInstalled = true; }

      if (isInstalled && info.containsKey('deepLink')) {
        try {
          final uri = Uri.parse(info['deepLink']!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return 'Searched "$searchTerm" on ${platform[0].toUpperCase()}${platform.substring(1)}.';
          }
        } catch (_) {}
      }

      if (info.containsKey('webUrl')) {
        try {
          final result = await Process.run('sh', ['-c', 'am start -a android.intent.action.VIEW -d "${info['webUrl']}" com.android.chrome']);
          if (result.exitCode == 0) return 'Searched "$searchTerm" on ${platform[0].toUpperCase()}${platform.substring(1)} (via browser).';
        } catch (_) {}
      }
    }

    final webUrl = info['webUrl'] ?? 'https://www.google.com/search?q=$encoded';
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

  // ── Helpers ───────────────────────────────────────────────────────────

  List<String> _parseCommandLine(String commandLine) {
    final args = <String>[];
    var inQuotes = false;
    final current = StringBuffer();

    for (final char in commandLine.split('')) {
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ' ' && !inQuotes) {
        if (current.isNotEmpty) { args.add(current.toString()); current.clear(); }
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) args.add(current.toString());
    return args;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _switchView(AppView view) => setState(() => _currentView = view);

  void _addWorkspace() {
    setState(() {
      _workspaces.add('Workspace ${_workspaces.length + 1}');
      _activeWorkspaceIndex = _workspaces.length - 1;
    });
  }

  Future<void> _toggleMaximize() async {
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (!isDesktop) return;
    final isMax = await windowManager.isMaximized();
    isMax ? await windowManager.unmaximize() : await windowManager.maximize();
  }

  // ── UI Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          Row(
            children: [
              SizedBox(
                width: 260,
                child: ShellSidebar(
                  workspaces: _workspaces,
                  activeWorkspaceIndex: _activeWorkspaceIndex,
                  currentView: _currentView,
                  onViewChanged: _switchView,
                  onWorkspaceChanged: (i) => setState(() => _activeWorkspaceIndex = i),
                  onAddWorkspace: _addWorkspace,
                  onRemoveWorkspace: (i) => setState(() {
                    _workspaces.removeAt(i);
                    if (_activeWorkspaceIndex >= _workspaces.length) _activeWorkspaceIndex = _workspaces.length - 1;
                  }),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildTopZone(),
                        Expanded(child: _buildMiddleZone()),
                      ],
                    ),
                    if (_currentView == AppView.shell)
                      Positioned(bottom: 24, left: 24, right: 24, child: Center(child: _buildBottomZone())),
                  ],
                ),
              ),
            ],
          ),
          CursorOverlay(isVisible: _cursorVisible, targetX: _cursorX, targetY: _cursorY, isClicking: _cursorClicking),
        ],
      ),
    );
  }

  Widget _buildTopZone() {
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (!isDesktop) return const SizedBox.shrink();
    return Container(
      height: 48,
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          _winBtn(Icons.remove, () => windowManager.minimize()),
          const SizedBox(width: 12),
          _winBtn(Icons.crop_square_rounded, _toggleMaximize),
          const SizedBox(width: 12),
          _winBtn(Icons.close, () => windowManager.close(), isClose: true),
        ],
      ),
    );
  }

  Widget _buildMiddleZone() {
    switch (_currentView) {
      case AppView.dashboard:
        return const DashboardView();
      case AppView.workspace:
        return const WorkspaceCanvas();
      case AppView.settings:
        return SettingsView(
          selectedModel: _selectedModel,
          onModelChanged: (v) => setState(() => _selectedModel = v),
          apiKeys: _apiKeys,
          onApiKeysChanged: (keys) async {
            setState(() {
              _apiKeys.clear();
              _apiKeys.addAll(keys);
            });
            await _saveApiKeys();
          },
          customModels: _customModels,
          onCustomModelsChanged: (models) async {
            setState(() => _customModels = models);
            await _saveCustomModels();
          },
          processCount: _processRegistry.length,
          onCheckForUpdates: _checkForUpdates,
          onInstallUpdate: _installUpdate,
          checkingForUpdates: _checkingForUpdates,
          updateProgressActive: _updateProgressActive,
          updateProgress: _updateProgress,
          updateInfo: _updateInfo,
          updateStatusMessage: _updateStatusMessage,
        );
      case AppView.shell:
        return ChatView(
          messages: _messages,
          scrollController: _scrollController,
          chatMode: _chatMode,
          selectedModel: _selectedModel,
          allModelNames: _allModelNames,
          inputController: _inputController,
          onSend: _handleSend,
          onModelChanged: (v) {
            if (v == 'Settings') {
              _switchView(AppView.settings);
            } else {
              setState(() => _selectedModel = v);
            }
          },
          onChatModeChanged: (v) => setState(() => _chatMode = v),
          onNavigateToSettings: () => _switchView(AppView.settings),
        );
    }
  }

  Widget _buildBottomZone() {
    return Container(
      width: 760,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF222222))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(color: Colors.transparent, child: InkWell(onTap: () {}, borderRadius: BorderRadius.circular(20), hoverColor: Colors.white.withValues(alpha: 0.05), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.add, color: Colors.white54, size: 20)))),
            const SizedBox(width: 8),
            CustomDropdownMenu<String>(
              value: _selectedModel,
              items: _allModelNames,
              itemLabel: (v) => v,
              accentColor: Colors.white,
              textStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              onChanged: (v) {
                if (v == 'Settings') {
                  _switchView(AppView.settings);
                } else {
                  setState(() => _selectedModel = v!);
                }
              },
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: const Color(0xFF333333)),
            const SizedBox(width: 12),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
                    _handleSend(_inputController.text);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _inputController,
                  onSubmitted: _handleSend,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: null,
                  decoration: const InputDecoration(hintText: 'Ask anything...', hintStyle: TextStyle(color: Colors.white54, fontSize: 14), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(color: Colors.transparent, child: InkWell(onTap: () => _handleSend(_inputController.text), borderRadius: BorderRadius.circular(20), hoverColor: Colors.white.withValues(alpha: 0.05), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.send_rounded, color: Colors.white, size: 18)))),
          ],
        ),
      ),
    );
  }

  Widget _winBtn(IconData icon, VoidCallback onPressed, {bool isClose = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        hoverColor: isClose ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
        child: Container(
          width: 32, height: 32, alignment: Alignment.center,
          child: Icon(icon, color: isClose ? Colors.redAccent.withValues(alpha: 0.9) : Colors.white54, size: 14),
        ),
      ),
    );
  }
}
