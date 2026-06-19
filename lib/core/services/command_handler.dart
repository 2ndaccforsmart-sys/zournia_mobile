class CommandHandler {
  /// All recognized command prefixes — add new ones here.
  static const List<String> allPrefixes = [
    // Original
    'EXECUTE:', 'CLOSE:', 'SEARCH:', 'TAP:', 'SWIPE:', 'TYPE:', 'NAV:',
    'SCREENSHOT:', 'DUMPUI:', 'VISION:',
    // File operations
    'READ_FILE:', 'WRITE_FILE:', 'EDIT_FILE:', 'LIST_DIR:', 'DELETE_FILE:',
    'MKDIR:', 'COPY_FILE:', 'MOVE_FILE:', 'FILE_APPEND:',
    // Clipboard
    'CLIPBOARD_GET:', 'CLIPBOARD_SET:',
    // System & device
    'DEVICE_INFO:', 'BATTERY:', 'STORAGE:', 'RAM:', 'NETWORK:',
    'RUN_SHELL:', 'ENV:',
    // Contacts & messaging
    'CONTACTS:', 'SMS:', 'CALL_LOG:', 'CALENDAR:',
    // App management
    'APPS:', 'OPEN_APP:', 'UNINSTALL_APP:',
    // Media & camera
    'CAMERA:', 'RECORD:', 'GALLERY:', 'MIC:',
    // Notifications
    'NOTIFICATIONS:', 'POST_NOTIFICATION:',
    // Desktop-specific
    'WINDOW_LIST:', 'DESKTOP_OPEN:', 'DESKTOP_SCREENSHOT:',
    // Advanced input (mobile)
    'LONGPRESS:', 'PINCH:', 'DOUBLE_TAP:',
    // Text editing
    'SELECT_ALL:', 'COPY_TEXT:', 'PASTE_TEXT:',
    // Wake/sleep
    'WAKE:', 'SLEEP:', 'UNLOCK:',
  ];

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

      for (final prefix in allPrefixes) {
        if (check.startsWith(prefix)) {
          final payload = check.substring(prefix.length).trim();
          final kind = prefix.replaceAll(':', '');
          // Commands with no payload are still valid
          commands.add(Command(kind: kind, payload: payload));
          break;
        }
      }
    }

    return commands;
  }

  /// Strip command lines from a response, leaving only the conversational text.
  static String cleanResponse(String response) {
    final cleaned = <String>[];
    for (final line in response.split('\n')) {
      final stripped = line.trim().replaceAll('`', '').trim();
      if (allPrefixes.any((p) => stripped.startsWith(p))) continue;
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
