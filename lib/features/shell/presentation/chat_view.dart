import 'package:flutter/material.dart';
import '../../ui_components/dropdown_menu.dart';

class ChatView extends StatefulWidget {
  final List<Map<String, String>> messages;
  final ScrollController scrollController;
  final String chatMode;
  final String selectedModel;
  final List<String> allModelNames;
  final TextEditingController inputController;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onChatModeChanged;
  final VoidCallback onNavigateToSettings;

  const ChatView({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.chatMode,
    required this.selectedModel,
    required this.allModelNames,
    required this.inputController,
    required this.onSend,
    required this.onModelChanged,
    required this.onChatModeChanged,
    required this.onNavigateToSettings,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: widget.messages.isEmpty
              ? _buildEmptyState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBubble = constraints.maxWidth * 0.72;
                    return ListView.builder(
                      controller: widget.scrollController,
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth > 900 ? (constraints.maxWidth - 800) / 2 : 28,
                        80,
                        constraints.maxWidth > 900 ? (constraints.maxWidth - 800) / 2 : 28,
                        100,
                      ),
                      itemCount: widget.messages.length,
                      itemBuilder: (context, index) {
                        final msg = widget.messages[index];
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
            value: widget.chatMode,
            items: const ['default', 'normal', 'autonomous'],
            itemLabel: (v) => v,
            accentColor: Colors.white,
            onChanged: (v) => widget.onChatModeChanged(v!),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
}

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
