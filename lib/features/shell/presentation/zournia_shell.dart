import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/zournia_theme.dart';
import '../../core/security/security_jail.dart';
import '../../core/update/update_manager.dart';
import '../../core/services/ai_service.dart';
import '../../features/chat/chat_service.dart';
import '../../features/dashboard/presentation/dashboard_view.dart';
import '../../features/workspace_router/presentation/workspace_canvas.dart';
import '../../features/ui_components/dropdown_menu.dart';
import '../../features/automation/data/phone_controller.dart';
import '../../features/automation/presentation/cursor_overlay.dart';

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

enum AppView { shell, dashboard, workspace, settings }

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
  String _selectedProvider = 'OpenRouter';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customModelNameController = TextEditingController();
  final TextEditingController _customModelIdController = TextEditingController();
  List<Map<String, dynamic>> _customModels = [];
  bool _obscureApiKey = true;
  bool _apiKeySavedFeedback = false;
  bool _keysExpanded = false;
  String _providerSearchQuery = '';

  // ── Update state ──────────────────────────────────────────────────────
  bool _checkingForUpdates = false;
  bool _updateProgressActive = false;
  double _updateProgress = 0.0;
  UpdateInfo? _updateInfo;
  String _updateStatusMessage = '';

  // ── Session & automation ──────────────────────────────────────────────
  late final SecurityJail _securityJail;
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

  static const _providers = [
    'OpenRouter', 'OpenAI', 'Anthropic', 'Google Gemini', 'Groq', 'Cerebras',
    'Mistral AI', 'DeepSeek', 'Together AI', 'Perplexity', 'Hugging Face',
    'Fireworks AI', 'DeepInfra', 'Replicate', 'Ollama (Local)', 'LM Studio',
    'WaveSpeed AI', 'AI/ML API', 'SiliconFlow', 'Cohere', 'Voyage AI',
    'AI21 Labs', 'OctoAI', 'Anyscale', 'OpenWebUI',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _securityJail = SecurityJail(
      allowedDirectory: Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Admin',
    );
    _loadApiKeys();
    _loadCustomModels();
    _loadSessionState();
    _phoneController.loadPatterns();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _apiKeyController.dispose();
    _searchController.dispose();
    _customModelNameController.dispose();
    _customModelIdController.dispose();
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

      setState(() => _apiKeyController.text = _apiKeys[_selectedProvider] ?? '');
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
              for (final m in r.messages) _messages.add(m);
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
        ChatService.delete(extra) ? 'Deleted chat "$extra".' : 'Chat "$extra" not found.';
        result = ChatService.delete(extra) ? 'Deleted chat "$extra".' : 'Chat "$extra" not found.';
      case 'continue':
        if (extra.isEmpty) { result = 'Usage: !chat continue <name>'; break; }
        ChatService.load(extra).then((r) {
          if (r == null) {
            setState(() => _addBotMessage('Chat "$extra" not found.'));
          } else {
            setState(() {
              for (final m in r.messages) _messages.add(m);
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

      // Parse INTENT: line
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

      // Process automation commands
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
    // URL detection
    final urlPattern = RegExp(r'"(https?://[^"]+)"');
    var urlMatch = urlPattern.firstMatch(command);
    if (urlMatch == null) {
      urlMatch = RegExp(r"'(https?://[^']+)'").firstMatch(command);
    }
    if (urlMatch == null) {
      urlMatch = RegExp(r'''(https?://[^\s"']+)''').firstMatch(command);
    }
    if (urlMatch != null) {
      return _launchUrl(urlMatch.group(1)!);
    }

    // App launch detection
    final launchRegex = RegExp(r'(?:am start|monkey -p)\s+([a-zA-Z0-9._]+)(?:\s+1)?$');
    final launchMatch = launchRegex.firstMatch(command.trim());
    if (launchMatch != null) {
      return _launchApp(launchMatch.group(1)!);
    }

    // Shell command
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
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final platformName = isDesktop ? 'Windows PC' : 'Android/Termux environment';
    final shellName = isDesktop ? 'Windows shell' : 'Android shell';
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
              SizedBox(width: 260, child: _buildSidebar()),
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

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF141414), border: Border(right: BorderSide(color: Color(0xFF222222)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset('assets/z_logo.png', width: 20, height: 20, fit: BoxFit.cover)),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _workspaces.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final name = entry.value;
                        final isActive = idx == _activeWorkspaceIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _activeWorkspaceIndex = idx),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF222222) : Colors.transparent,
                                border: Border.all(color: isActive ? const Color(0xFF333333) : Colors.transparent),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(children: [
                                Text(name, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                                if (_workspaces.length > 1) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => setState(() {
                                      _workspaces.removeAt(idx);
                                      if (_activeWorkspaceIndex >= _workspaces.length) _activeWorkspaceIndex = _workspaces.length - 1;
                                    }),
                                    child: Icon(Icons.close, color: isActive ? Colors.white54 : Colors.white30, size: 12),
                                  ),
                                ],
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(onTap: _addWorkspace, borderRadius: BorderRadius.circular(4), child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.add, color: Colors.white54, size: 16))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('NAVIGATION', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const Spacer(),
              const Icon(Icons.grid_view_rounded, color: Colors.white54, size: 12),
            ]),
          ),
          const SizedBox(height: 12),
          _sidebarItem(Icons.dashboard_outlined, 'Dashboard', () => _switchView(AppView.dashboard), isActive: _currentView == AppView.dashboard),
          _sidebarItem(Icons.category_outlined, 'Workspace Canvas', () => _switchView(AppView.workspace), isActive: _currentView == AppView.workspace),
          _sidebarItem(Icons.chat_bubble_outline, 'Chat Shell', () => _switchView(AppView.shell), isActive: _currentView == AppView.shell),
          const Spacer(),
          _sidebarItem(Icons.settings_outlined, 'Settings', () => _switchView(AppView.settings), isActive: _currentView == AppView.settings),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, VoidCallback onTap, {required bool isActive}) {
    return _SidebarNavItem(icon: icon, label: label, onTap: onTap, isActive: isActive);
  }

  Widget _buildMiddleZone() {
    switch (_currentView) {
      case AppView.dashboard:
        return const DashboardView();
      case AppView.workspace:
        return const WorkspaceCanvas();
      case AppView.settings:
        return _buildSettingsView();
      case AppView.shell:
        return _buildChatView();
    }
  }

  Widget _buildChatView() {
    return Stack(
      children: [
        Positioned.fill(
          child: _messages.isEmpty
              ? _buildChatEmptyState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBubble = constraints.maxWidth * 0.72;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth > 900 ? (constraints.maxWidth - 800) / 2 : 28,
                        80,
                        constraints.maxWidth > 900 ? (constraints.maxWidth - 800) / 2 : 28,
                        100,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _ChatBubble(text: msg['text']!, isUser: msg['sender'] == 'user', maxWidth: maxBubble);
                      },
                    );
                  },
                ),
        ),
        Positioned(
          top: 16,
          right: 20,
          child: CustomDropdownMenu<String>(
            value: _chatMode,
            items: const ['default', 'normal', 'automation'],
            itemLabel: (v) => v,
            accentColor: Colors.white,
            onChanged: (v) => setState(() => _chatMode = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Zournia Chat Shell', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          SizedBox(height: 8),
          Text('Your minimalist AI orchestration interface.', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
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

  // ── Settings View ─────────────────────────────────────────────────────

  Widget _buildSettingsView() {
    final filteredProviders = _providers.where((p) => p.toLowerCase().contains(_providerSearchQuery.toLowerCase())).toList();

    return Container(
      color: const Color(0xFF070709),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.settings_rounded, color: ZourniaTheme.shellAccent, size: 20),
            const SizedBox(width: 10),
            const Text('SETTINGS // CONTROL_PANEL', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 8),
          Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [ZourniaTheme.shellAccent.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.05), Colors.transparent]))),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Keys + Custom Models
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKeysPanel(filteredProviders),
                        const SizedBox(height: 16),
                        _buildCustomModelsCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Right: Updates & Diagnostics
                Expanded(flex: 2, child: _buildUpdatesPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeysPanel(List<String> filteredProviders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ZourniaTheme.shellSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ZourniaTheme.shellBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.vpn_key_rounded, color: ZourniaTheme.shellAccent, size: 16),
          const SizedBox(width: 8),
          const Text('KEYS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 16),
        const Text('AI MODEL SELECTOR', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildRadioOption(label: 'Qwen 2.5 Coder 32B', value: 'Qwen 3.6 Coder', groupValue: _selectedModel, icon: Icons.code_rounded, onChanged: (v) => setState(() => _selectedModel = v!))),
          const SizedBox(width: 12),
          Expanded(child: _buildRadioOption(label: 'Google Gemini 2.5 Flash', value: 'Gemini', groupValue: _selectedModel, icon: Icons.auto_awesome_rounded, onChanged: (v) => setState(() => _selectedModel = v!))),
          const SizedBox(width: 12),
          Expanded(child: _buildRadioOption(label: 'Auto-Routing Engine', value: 'Auto', groupValue: _selectedModel, icon: Icons.router_rounded, onChanged: (v) => setState(() => _selectedModel = v!))),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: ZourniaTheme.shellBorder),
        const SizedBox(height: 16),
        // Collapsible keys
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _keysExpanded = !_keysExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(children: [
                    const Text('API PROVIDERS & KEYS', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Spacer(),
                    AnimatedRotation(turns: _keysExpanded ? 0.5 : 0.0, duration: const Duration(milliseconds: 220), curve: Curves.easeInOut, child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 16)),
                  ]),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 160),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _keysExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: SizedBox(
              height: 340,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Provider list
                Container(
                  width: 220,
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: ZourniaTheme.shellBorder))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _providerSearchQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search providers...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 16),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.01),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ZourniaTheme.shellAccent.withValues(alpha: 0.5))),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: ZourniaTheme.shellBorder),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredProviders.length,
                        itemBuilder: (context, index) {
                          final provider = filteredProviders[index];
                          final isSelected = provider == _selectedProvider;
                          final hasKey = _apiKeys.containsKey(provider) && _apiKeys[provider]!.isNotEmpty;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() {
                                _selectedProvider = provider;
                                _apiKeyController.text = _apiKeys[provider] ?? '';
                                _apiKeySavedFeedback = false;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? ZourniaTheme.shellBorder.withValues(alpha: 0.5) : Colors.transparent,
                                  border: Border(left: BorderSide(color: isSelected ? ZourniaTheme.shellAccent : Colors.transparent, width: 2.5)),
                                ),
                                child: Row(children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: hasKey ? ZourniaTheme.shellAccent : Colors.white10)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(provider, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                                  if (hasKey) const Icon(Icons.check_rounded, color: ZourniaTheme.shellAccent, size: 14),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
                // Key editor
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 24, top: 12, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.vpn_key_rounded, color: ZourniaTheme.shellAccent, size: 14),
                          const SizedBox(width: 8),
                          Text(_selectedProvider.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.2)),
                        ]),
                        const SizedBox(height: 20),
                        const Text('API Connection Key', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _apiKeyController,
                              obscureText: _obscureApiKey,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                hintText: _getProviderHint(_selectedProvider),
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.01),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZourniaTheme.shellAccent)),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54, size: 18),
                                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _apiKeySavedFeedback ? ZourniaTheme.accentGreen : ZourniaTheme.shellAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final newKey = _apiKeyController.text.trim();
                              setState(() {
                                if (newKey.isEmpty) { _apiKeys.remove(_selectedProvider); } else { _apiKeys[_selectedProvider] = newKey; }
                                _apiKeySavedFeedback = true;
                              });
                              await _saveApiKeys();
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) setState(() => _apiKeySavedFeedback = false);
                              });
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _apiKeySavedFeedback
                                  ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_rounded, size: 16, color: Colors.black), SizedBox(width: 4), Text('SAVED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))])
                                  : const Text('SAVE KEY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        if (_apiKeys.containsKey(_selectedProvider) && _apiKeys[_selectedProvider]!.isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent, width: 0.5), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: const Text('REMOVE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            onPressed: () async {
                              setState(() { _apiKeys.remove(_selectedProvider); _apiKeyController.clear(); _apiKeySavedFeedback = false; });
                              await _saveApiKeys();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ]),
      ]),
    );
  }

  Widget _buildCustomModelsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ZourniaTheme.shellSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ZourniaTheme.shellBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.smart_toy_outlined, color: ZourniaTheme.shellAccent, size: 16),
          const SizedBox(width: 8),
          const Text('CUSTOM MODELS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 16),
        if (_customModels.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.01), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
            child: const Text('No custom models added yet.', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _customModels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final model = _customModels[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                child: Row(children: [
                  const Icon(Icons.smart_toy_outlined, color: Colors.white54, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(model['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(model['identifier'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontFamily: 'monospace')),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                    onPressed: () async {
                      setState(() {
                        if (_selectedModel == model['name']) _selectedModel = 'Gemini';
                        _customModels.removeAt(index);
                      });
                      await _saveCustomModels();
                    },
                  ),
                ]),
              );
            },
          ),
        const SizedBox(height: 20),
        Container(height: 1, color: ZourniaTheme.shellBorder),
        const SizedBox(height: 16),
        const Text('ADD NEW CUSTOM MODEL', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Model Name', style: TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            TextField(controller: _customModelNameController, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(hintText: 'e.g. Claude 3.5 Sonnet', hintStyle: const TextStyle(color: Colors.white24, fontSize: 11), filled: true, fillColor: Colors.white.withValues(alpha: 0.01), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZourniaTheme.shellAccent)))),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('API Identifier', style: TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            TextField(controller: _customModelIdController, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(hintText: 'e.g. anthropic/claude-3.5-sonnet', hintStyle: const TextStyle(color: Colors.white24, fontSize: 11), filled: true, fillColor: Colors.white.withValues(alpha: 0.01), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ZourniaTheme.shellAccent)))),
          ])),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: ZourniaTheme.shellAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('ADD MODEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            onPressed: () async {
              final name = _customModelNameController.text.trim();
              final id = _customModelIdController.text.trim();
              if (name.isEmpty || id.isEmpty) return;
              if (_customModels.any((m) => m['name'] == name)) return;
              setState(() {
                _customModels.add({'name': name, 'identifier': id, 'provider': 'OpenRouter'});
                _customModelNameController.clear();
                _customModelIdController.clear();
              });
              await _saveCustomModels();
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildUpdatesPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ZourniaTheme.shellSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ZourniaTheme.shellBorder)),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.system_update_rounded, color: ZourniaTheme.shellAccent, size: 16),
            const SizedBox(width: 8),
            const Text('UPDATES', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 16),
          const Text('CLIENT VERSION INFO', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF161A1F), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZourniaTheme.shellBorder)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Current version:', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('v${UpdateManager.currentVersion}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ]),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: ZourniaTheme.shellBorder),
          const SizedBox(height: 16),
          if (_updateStatusMessage.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_updateInfo?.isUpdateAvailable ?? false) ? ZourniaTheme.shellAccent.withValues(alpha: 0.05) : ZourniaTheme.shellBorder.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_updateInfo?.isUpdateAvailable ?? false) ? ZourniaTheme.shellAccent.withValues(alpha: 0.2) : ZourniaTheme.shellBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_updateStatusMessage, style: TextStyle(color: (_updateInfo?.isUpdateAvailable ?? false) ? ZourniaTheme.shellAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                if (_updateInfo != null && _updateInfo!.isUpdateAvailable) ...[
                  const SizedBox(height: 6),
                  Text('Release Notes: ${_updateInfo!.releaseNotes}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ]),
            ),
            const SizedBox(height: 16),
          ],
          if (_updateProgressActive) ...[
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _updateProgress, color: ZourniaTheme.shellAccent, backgroundColor: const Color(0xFF161A1F), minHeight: 6))),
              const SizedBox(width: 12),
              Text('${(_updateProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: ZourniaTheme.shellAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
          ],
          Row(children: [
            if (_updateInfo == null || !_updateInfo!.isUpdateAvailable)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ZourniaTheme.shellAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: _checkingForUpdates ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.refresh_rounded, size: 14),
                label: Text(_checkingForUpdates ? 'CHECKING...' : 'CHECK FOR UPDATES', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: _checkingForUpdates ? null : _checkForUpdates,
              ),
            if (_updateInfo != null && _updateInfo!.isUpdateAvailable && !_updateProgressActive)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ZourniaTheme.shellGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('INSTALL UPDATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: _installUpdate,
              ),
          ]),
          const SizedBox(height: 24),
          Container(height: 1, color: ZourniaTheme.shellBorder),
          const SizedBox(height: 20),
          Row(children: [
            const Icon(Icons.analytics_outlined, color: ZourniaTheme.shellAccent, size: 16),
            const SizedBox(width: 8),
            const Text('SYSTEM TELEMETRY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 16),
          _telemetryItem('Platform', '${Platform.operatingSystem} Desktop'),
          const SizedBox(height: 8),
          _telemetryItem('Sandbox', Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Admin'),
          const SizedBox(height: 8),
          _telemetryItem('Runtime', 'Dart VM v${Platform.version.split(' ').first}'),
          const SizedBox(height: 8),
          _telemetryItem('Processes', '${_processRegistry.length} active'),
          const SizedBox(height: 8),
          _telemetryItem('CPU Threads', '${Platform.numberOfProcessors}'),
        ]),
      ),
    );
  }

  Widget _telemetryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF161A1F), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZourniaTheme.shellBorder)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _buildRadioOption<T>({required String label, required T value, required T groupValue, required IconData icon, required ValueChanged<T?> onChanged}) {
    final isSelected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? ZourniaTheme.shellAccent.withValues(alpha: 0.04) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? ZourniaTheme.shellAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: isSelected ? ZourniaTheme.shellAccent : Colors.white38),
            const SizedBox(width: 10),
            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? ZourniaTheme.shellAccent : Colors.white24, width: 1.5)), child: isSelected ? Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: ZourniaTheme.shellAccent))) : null),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
          ]),
        ),
      ),
    );
  }

  String _getProviderHint(String provider) {
    switch (provider) {
      case 'OpenRouter': return 'sk-or-v1-...';
      case 'OpenAI': return 'sk-proj-...';
      case 'Anthropic': return 'sk-ant-api03-...';
      case 'Ollama (Local)': return 'No key needed or custom endpoint';
      case 'LM Studio': return 'No key needed or custom endpoint';
      default: return 'Enter API connection key...';
    }
  }
}

// ── Sidebar Nav Item ─────────────────────────────────────────────────────────

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _SidebarNavItem({required this.icon, required this.label, required this.onTap, required this.isActive});

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;
  Color get _fgColor => widget.isActive || _hovered ? Colors.white : Colors.white54;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isActive ? const Color(0xFF2B2B2B) : _hovered ? const Color(0xFF1A1A1A) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(widget.icon, size: 16, color: _fgColor),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _fgColor, fontSize: 12, fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final double maxWidth;

  const _ChatBubble({required this.text, required this.isUser, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF262626) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isUser ? null : Border.all(color: const Color(0xFF333333)),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
        ),
      ),
    );
  }
}
