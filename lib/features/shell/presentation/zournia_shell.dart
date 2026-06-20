import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'dart:convert';
import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/command_processor.dart';
import '../../../core/services/system_prompt_builder.dart';
import '../../../core/update/update_manager.dart';
import '../../chat/chat_service.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../workspace_router/presentation/workspace_canvas.dart';
import '../../ui_components/dropdown_menu.dart';
import '../../automation/data/phone_controller.dart';
import '../../automation/presentation/cursor_overlay.dart';
import 'sidebar.dart';
import 'chat_view.dart';
import 'settings_view.dart';

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

  // ── Services ─────────────────────────────────────────────────────────
  late final CommandProcessor _commandProcessor;

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
    _commandProcessor = CommandProcessor(
      phoneController: _phoneController,
      processRegistry: _processRegistry,
      onStatus: _addBotMessage,
      recordPattern: _phoneController.recordPattern,
      onCursorMove: (x, y, clicking) {
        if (mounted) {
          setState(() {
            _cursorVisible = true;
            _cursorX = x;
            _cursorY = y;
            _cursorClicking = clicking;
          });
        }
      },
      onCursorHide: () {
        if (mounted) {
          setState(() => _cursorVisible = false);
        }
      },
    );
    _loadApiKeys();
    _loadCustomModels();
    _loadSessionState();
    _phoneController.loadPatterns();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────

  Future<void> _loadApiKeys() async {
    try {
      final jsonFile = File(AppConstants.apiKeysFile);
      final legacyFile = File(AppConstants.legacyApiKeyFile);

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
      await File(AppConstants.apiKeysFile).writeAsString(jsonEncode(_apiKeys));
      await File(AppConstants.legacyApiKeyFile).writeAsString(_apiKeys['OpenRouter'] ?? '');
    } catch (e) {
      debugPrint('Error saving API keys: $e');
    }
  }

  Future<void> _loadCustomModels() async {
    try {
      final file = File(AppConstants.customModelsFile);
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
      await File(AppConstants.customModelsFile).writeAsString(jsonEncode(_customModels));
    } catch (e) {
      debugPrint('Error saving custom models: $e');
    }
  }

  Future<void> _loadSessionState() async {
    try {
      final file = File(AppConstants.sessionStateFile);
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
      await File(AppConstants.sessionStateFile).writeAsString(jsonEncode(_sessionState.toJson()));
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
    if (!mounted) return;
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

      // Extract INTENT: line if present
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

      // Process commands via CommandProcessor
      if (_chatMode == 'automation' || _chatMode == 'default' || _chatMode == 'autonomous') {
        cleanResponse = await _commandProcessor.processAll(cleanResponse, userMessage);
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
    return AppConstants.statusPrefixes.any((p) => text.startsWith(p));
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

    final modelUrl = apiKey == _apiKeys['OpenRouter']
        ? 'https://openrouter.ai/api/v1/chat/completions'
        : resolved.url;
    final modelName = apiKey == _apiKeys['OpenRouter'] && AiService.defaultModels.containsKey(_selectedModel)
        ? AiService.defaultModels[_selectedModel]!
        : resolved.modelName;

    final sessionStr = 'Active Session State:\n'
        '- LAST_ACTION: ${_sessionState.lastAction.isEmpty ? "None" : _sessionState.lastAction}\n'
        '- TARGET_PID: ${_sessionState.targetPid ?? "None"}\n'
        '- INTENT_TRACKING: ${_sessionState.intentTracking.isEmpty ? "None" : _sessionState.intentTracking}\n';

    final systemPrompt = SystemPromptBuilder.build(
      chatMode: _chatMode,
      sessionStr: sessionStr,
      sysInfo: SystemPromptBuilder.getSystemInfo(),
      discoveredApps: _phoneController.getDiscoveredAppsSummary(),
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    final historyStart = _messages.length > AppConstants.chatHistoryWindow
        ? _messages.length - AppConstants.chatHistoryWindow
        : 0;
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

  // ── Helpers ───────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
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
                width: AppConstants.sidebarWidth,
                child: ShellSidebar(
                  workspaces: _workspaces,
                  activeWorkspaceIndex: _activeWorkspaceIndex,
                  currentView: _currentView,
                  onViewChanged: _switchView,
                  onWorkspaceChanged: (i) => setState(() => _activeWorkspaceIndex = i),
                  onAddWorkspace: _addWorkspace,
                  onRemoveWorkspace: (i) => setState(() {
                    _workspaces.removeAt(i);
                    if (_activeWorkspaceIndex >= _workspaces.length) {
                      _activeWorkspaceIndex = _workspaces.length - 1;
                    }
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
      width: AppConstants.bottomBarWidth,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                hoverColor: Colors.white.withValues(alpha: 0.05),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.add, color: Colors.white54, size: 20),
                ),
              ),
            ),
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
                  decoration: const InputDecoration(
                    hintText: 'Ask anything...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleSend(_inputController.text),
                borderRadius: BorderRadius.circular(20),
                hoverColor: Colors.white.withValues(alpha: 0.05),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
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
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, color: isClose ? Colors.redAccent.withValues(alpha: 0.9) : Colors.white54, size: 14),
        ),
      ),
    );
  }
}
