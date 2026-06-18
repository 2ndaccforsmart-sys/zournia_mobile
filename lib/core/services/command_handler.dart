class CommandHandler {
  /// Extract all automation commands from an AI response.
  static List<Command> extractAll(String response) {
    final commands = <Command>[];
    var inCodeBlock = false;

    for (final line in response.split('\n')) {
      final raw = line.trim();
      if (raw.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      final check = raw.replaceAll('`', '').trim();
      if (check.isEmpty) continue;

      for (final prefix in ['EXECUTE:', 'CLOSE:', 'SEARCH:', 'TAP:', 'SWIPE:', 'TYPE:', 'NAV:', 'SCREENSHOT:', 'DUMPUI:', 'VISION:']) {
        if (check.startsWith(prefix)) {
          final payload = check.substring(prefix.length).trim();
          final kind = prefix.replaceAll(':', '');
          if (payload.isNotEmpty || kind == 'SCREENSHOT' || kind == 'DUMPUI' || kind == 'VISION') {
            commands.add(Command(kind: kind, payload: payload));
          }
          break;
        }
      }
    }

    return commands;
  }

  /// Strip command lines from a response, leaving only the conversational text.
  static String cleanResponse(String response) {
    final commandPrefixes = ['EXECUTE:', 'CLOSE:', 'SEARCH:', 'TAP:', 'SWIPE:', 'TYPE:', 'NAV:', 'SCREENSHOT:', 'DUMPUI:', 'VISION:'];
    final cleaned = <String>[];

    for (final line in response.split('\n')) {
      final stripped = line.trim().replaceAll('`', '').trim();
      if (commandPrefixes.any((p) => stripped.startsWith(p))) continue;
      if (line.trim().isNotEmpty) cleaned.add(line);
    }

    return cleaned.join('\n').trim();
  }
}

class Command {
  final String kind;
  final String payload;

  const Command({required this.kind, required this.payload});
}
