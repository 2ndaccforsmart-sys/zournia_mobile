import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const Map<String, String> defaultModels = {
    'Gemini': 'google/gemini-2.5-flash',
    'Qwen': 'qwen/qwen-2.5-coder-32b-instruct',
    'Dolphin': 'cognitivecomputations/dolphin-2.9.2-qwen2-72b',
    'Hermes': 'nousresearch/hermes-3-llama-3.1-8b',
    'FreeModel': 'openrouter/free',
  };

  static const Map<String, String> endpoints = {
    'together': 'https://api.together.xyz/v1/chat/completions',
    'deepinfra': 'https://api.deepinfra.com/v1/chat/completions',
    'hugging': 'https://router.huggingface.co/v1/chat/completions',
    'hf': 'https://router.huggingface.co/v1/chat/completions',
    'gemini': 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    'google': 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    'openai': 'https://api.openai.com/v1/chat/completions',
    'cerebras': 'https://api.cerebras.ai/v1/chat/completions',
    'groq': 'https://api.groq.com/openai/v1/chat/completions',
    'fireworks': 'https://api.fireworks.ai/inference/v1/chat/completions',
    'anthropic': 'https://api.anthropic.com/v1/messages',
    'claude': 'https://api.anthropic.com/v1/messages',
    'mistral': 'https://api.mistral.ai/v1/chat/completions',
    'wavespeed': 'https://api.wavespeed.ai/v1/chat/completions',
    'aiml': 'https://api.aimlapi.com/v1/chat/completions',
    'siliconflow': 'https://api.siliconflow.cn/v1/chat/completions',
  };

  /// Resolve the provider key, model name, and API endpoint for the given selection.
  static ResolvedModel resolve({
    required String selectedModel,
    required Map<String, String> apiKeys,
    required List<Map<String, dynamic>> customModels,
  }) {
    String provider = 'OpenRouter';
    String modelName = defaultModels['Gemini']!;

    if (defaultModels.containsKey(selectedModel)) {
      modelName = defaultModels[selectedModel]!;
      provider = _resolveProviderForBuiltin(selectedModel, apiKeys);
    } else {
      final custom = customModels.firstWhere(
        (m) => m['name'] == selectedModel,
        orElse: () => <String, dynamic>{},
      );
      if (custom.isNotEmpty && custom['identifier'] != null) {
        modelName = custom['identifier'] as String;
        provider = custom['provider'] as String? ?? 'OpenRouter';
      }
    }

    final provLower = provider.toLowerCase().trim();
    String url = 'https://openrouter.ai/api/v1/chat/completions';
    String provKey = provider;

    for (final entry in endpoints.entries) {
      if (provLower.contains(entry.key)) {
        url = entry.value;
        provKey = provider;
        break;
      }
    }

    return ResolvedModel(provider: provKey, modelName: modelName, url: url);
  }

  static String _resolveProviderForBuiltin(String model, Map<String, String> keys) {
    switch (model) {
      case 'Gemini':
        if (keys.containsKey('Google Gemini')) return 'Google Gemini';
        if (keys.containsKey('Gemini')) return 'Gemini';
        return 'OpenRouter';
      case 'Hermes':
      case 'Dolphin':
        for (final key in ['Together AI', 'Together', 'DeepInfra', 'Hugging Face', 'Hugging', 'HuggingFace', 'hf', 'huggingface']) {
          if (keys.containsKey(key)) return key;
        }
        return 'OpenRouter';
      default:
        return 'OpenRouter';
    }
  }

  static String getModelNameForBuiltin(String selectedModel) {
    return defaultModels[selectedModel] ?? 'google/gemini-2.5-flash';
  }

  /// Send a chat completion request.
  static Future<String> chat({
    required String model,
    required String url,
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    if (apiKey.isEmpty) return 'Error: API key not configured.';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://zournia.internal',
        'X-Title': 'Zournia OS',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': 4096,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        return choices.first['message']['content'] as String;
      }
      return 'Error: Empty response choices returned from model.';
    }
    return 'Error: Server returned status code ${response.statusCode} - ${response.body}';
  }
}

class ResolvedModel {
  final String provider;
  final String modelName;
  final String url;

  const ResolvedModel({required this.provider, required this.modelName, required this.url});
}
