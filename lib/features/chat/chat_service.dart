import 'dart:convert';
import 'dart:io';

class ChatService {
  static const String _chatDir = 'saved_chats';

  /// Save chat history to a file.
  static Future<String> save({
    required String name,
    required List<Map<String, String>> messages,
    required String model,
    required String mode,
  }) async {
    final dir = Directory(_chatDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final file = File('$_chatDir/$name.json');
    final data = {
      'messages': messages,
      'model': model,
      'mode': mode,
    };
    await file.writeAsString(jsonEncode(data));
    return 'Chat saved to $name.';
  }

  /// Load chat history from a file.
  static Future<ChatLoadResult?> load(String name) async {
    final file = File('$_chatDir/$name.json');
    if (!file.existsSync()) return null;

    final data = jsonDecode(await file.readAsString());
    final messages = (data['messages'] as List)
        .map((m) => {'sender': m['sender'] as String, 'text': m['text'] as String})
        .toList();

    return ChatLoadResult(
      messages: messages,
      model: data['model'] as String?,
      mode: data['mode'] as String?,
    );
  }

  /// List all saved chat names.
  static List<String> list() {
    final dir = Directory(_chatDir);
    if (!dir.existsSync()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.json', ''))
        .toList()
      ..sort();
  }

  /// Clear chat history file directory.
  static Future<void> clearHistory() async {
    final dir = Directory(_chatDir);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// Export chat as a readable text file.
  static Future<String> export({
    required String name,
    required List<Map<String, String>> messages,
  }) async {
    final dir = Directory(_chatDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final buffer = StringBuffer();
    for (final m in messages) {
      final label = m['sender'] == 'user' ? 'You' : 'Zournia';
      buffer.writeln('[$label]\n${m['text']}\n');
    }

    await File('$_chatDir/$name.txt').writeAsString(buffer.toString());
    return 'Chat exported to $name.txt';
  }

  /// Delete a saved chat.
  static bool delete(String name) {
    final file = File('$_chatDir/$name.json');
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    }
    return false;
  }
}

class ChatLoadResult {
  final List<Map<String, String>> messages;
  final String? model;
  final String? mode;

  const ChatLoadResult({required this.messages, this.model, this.mode});
}
