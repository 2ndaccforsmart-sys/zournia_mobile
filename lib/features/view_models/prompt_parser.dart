class ParsedIntent {
  final String rawInput;
  final String? tag;
  final String? target;
  final IntentType type;

  ParsedIntent({required this.rawInput, this.tag, this.target, required this.type});

  factory ParsedIntent.parse(String input) {
    if (input.startsWith('/cmd')) return ParsedIntent(rawInput: input, tag: '/cmd', type: IntentType.command);
    if (input.startsWith('@file')) return ParsedIntent(rawInput: input, tag: '@file', target: input.split(' ').last, type: IntentType.fileEdit);
    if (input.contains('plan') || input.contains('outline')) return ParsedIntent(rawInput: input, type: IntentType.plan);
    return ParsedIntent(rawInput: input, type: IntentType.chat);
  }
}

enum IntentType { command, fileEdit, plan, chat }
