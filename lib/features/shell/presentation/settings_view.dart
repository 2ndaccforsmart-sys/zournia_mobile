import 'package:flutter/material.dart';
import 'dart:io';

import '../../../core/theme/zournia_theme.dart';
import '../../../core/update/update_manager.dart';

class SettingsView extends StatefulWidget {
  final String selectedModel;
  final ValueChanged<String> onModelChanged;
  final Map<String, String> apiKeys;
  final ValueChanged<Map<String, String>> onApiKeysChanged;
  final List<Map<String, dynamic>> customModels;
  final ValueChanged<List<Map<String, dynamic>>> onCustomModelsChanged;
  final int processCount;
  final Future<void> Function() onCheckForUpdates;
  final Future<void> Function() onInstallUpdate;
  final bool checkingForUpdates;
  final bool updateProgressActive;
  final double updateProgress;
  final UpdateInfo? updateInfo;
  final String updateStatusMessage;

  const SettingsView({
    super.key,
    required this.selectedModel,
    required this.onModelChanged,
    required this.apiKeys,
    required this.onApiKeysChanged,
    required this.customModels,
    required this.onCustomModelsChanged,
    required this.processCount,
    required this.onCheckForUpdates,
    required this.onInstallUpdate,
    required this.checkingForUpdates,
    required this.updateProgressActive,
    required this.updateProgress,
    required this.updateInfo,
    required this.updateStatusMessage,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _selectedProvider = 'OpenRouter';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customModelNameController = TextEditingController();
  final TextEditingController _customModelIdController = TextEditingController();
  bool _obscureApiKey = true;
  bool _apiKeySavedFeedback = false;
  bool _keysExpanded = false;
  String _providerSearchQuery = '';

  static const _providers = [
    'OpenRouter', 'OpenAI', 'Anthropic', 'Google Gemini', 'Groq', 'Cerebras',
    'Mistral AI', 'DeepSeek', 'Together AI', 'Perplexity', 'Hugging Face',
    'Fireworks AI', 'DeepInfra', 'Replicate', 'Ollama (Local)', 'LM Studio',
    'WaveSpeed AI', 'AI/ML API', 'SiliconFlow', 'Cohere', 'Voyage AI',
    'AI21 Labs', 'OctoAI', 'Anyscale', 'OpenWebUI',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.apiKeys[_selectedProvider] ?? '';
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiKeys != widget.apiKeys) {
      _apiKeyController.text = widget.apiKeys[_selectedProvider] ?? '';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _searchController.dispose();
    _customModelNameController.dispose();
    _customModelIdController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final newKey = _apiKeyController.text.trim();
    final newKeys = Map<String, String>.from(widget.apiKeys);
    if (newKey.isEmpty) {
      newKeys.remove(_selectedProvider);
    } else {
      newKeys[_selectedProvider] = newKey;
    }
    widget.onApiKeysChanged(newKeys);
    setState(() => _apiKeySavedFeedback = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _apiKeySavedFeedback = false);
    });
  }

  Future<void> _removeApiKey() async {
    final newKeys = Map<String, String>.from(widget.apiKeys);
    newKeys.remove(_selectedProvider);
    widget.onApiKeysChanged(newKeys);
    _apiKeyController.clear();
    setState(() => _apiKeySavedFeedback = false);
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

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: _buildRadioOption(label: 'Qwen 2.5 Coder 32B', value: 'Qwen 3.6 Coder', groupValue: widget.selectedModel, icon: Icons.code_rounded, onChanged: (v) => widget.onModelChanged(v!))),
          const SizedBox(width: 12),
          Expanded(child: _buildRadioOption(label: 'Google Gemini 2.5 Flash', value: 'Gemini', groupValue: widget.selectedModel, icon: Icons.auto_awesome_rounded, onChanged: (v) => widget.onModelChanged(v!))),
          const SizedBox(width: 12),
          Expanded(child: _buildRadioOption(label: 'Auto-Routing Engine', value: 'Auto', groupValue: widget.selectedModel, icon: Icons.router_rounded, onChanged: (v) => widget.onModelChanged(v!))),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: ZourniaTheme.shellBorder),
        const SizedBox(height: 16),
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
                          final hasKey = widget.apiKeys.containsKey(provider) && widget.apiKeys[provider]!.isNotEmpty;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() {
                                _selectedProvider = provider;
                                _apiKeyController.text = widget.apiKeys[provider] ?? '';
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
                            onPressed: _saveApiKey,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _apiKeySavedFeedback
                                  ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_rounded, size: 16, color: Colors.black), SizedBox(width: 4), Text('SAVED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))])
                                  : const Text('SAVE KEY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        if (widget.apiKeys.containsKey(_selectedProvider) && widget.apiKeys[_selectedProvider]!.isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent, width: 0.5), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: const Text('REMOVE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            onPressed: _removeApiKey,
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
        if (widget.customModels.isEmpty)
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
            itemCount: widget.customModels.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final model = widget.customModels[index];
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
                    onPressed: () {
                      final newModels = List<Map<String, dynamic>>.from(widget.customModels);
                      newModels.removeAt(index);
                      widget.onCustomModelsChanged(newModels);
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
            onPressed: () {
              final name = _customModelNameController.text.trim();
              final id = _customModelIdController.text.trim();
              if (name.isEmpty || id.isEmpty) return;
              if (widget.customModels.any((m) => m['name'] == name)) return;
              final newModels = List<Map<String, dynamic>>.from(widget.customModels);
              newModels.add({'name': name, 'identifier': id, 'provider': 'OpenRouter'});
              widget.onCustomModelsChanged(newModels);
              _customModelNameController.clear();
              _customModelIdController.clear();
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
          if (widget.updateStatusMessage.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (widget.updateInfo?.isUpdateAvailable ?? false) ? ZourniaTheme.shellAccent.withValues(alpha: 0.05) : ZourniaTheme.shellBorder.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (widget.updateInfo?.isUpdateAvailable ?? false) ? ZourniaTheme.shellAccent.withValues(alpha: 0.2) : ZourniaTheme.shellBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.updateStatusMessage, style: TextStyle(color: (widget.updateInfo?.isUpdateAvailable ?? false) ? ZourniaTheme.shellAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                if (widget.updateInfo != null && widget.updateInfo!.isUpdateAvailable) ...[
                  const SizedBox(height: 6),
                  Text('Release Notes: ${widget.updateInfo!.releaseNotes}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ]),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.updateProgressActive) ...[
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: widget.updateProgress, color: ZourniaTheme.shellAccent, backgroundColor: const Color(0xFF161A1F), minHeight: 6))),
              const SizedBox(width: 12),
              Text('${(widget.updateProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: ZourniaTheme.shellAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
          ],
          Row(children: [
            if (widget.updateInfo == null || !widget.updateInfo!.isUpdateAvailable)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ZourniaTheme.shellAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: widget.checkingForUpdates ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.refresh_rounded, size: 14),
                label: Text(widget.checkingForUpdates ? 'CHECKING...' : 'CHECK FOR UPDATES', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: widget.checkingForUpdates ? null : widget.onCheckForUpdates,
              ),
            if (widget.updateInfo != null && widget.updateInfo!.isUpdateAvailable && !widget.updateProgressActive)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ZourniaTheme.shellGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('INSTALL UPDATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: widget.onInstallUpdate,
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
          _telemetryItem('Processes', '${widget.processCount} active'),
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
}
