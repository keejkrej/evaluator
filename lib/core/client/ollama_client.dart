import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class LLMResponse {
  final String content;
  final String? thinking;
  final List<ToolCall> toolCalls;
  final int promptTokens;
  final int completionTokens;
  final int latencyMs;
  final String model;

  LLMResponse({
    required this.content,
    this.thinking,
    this.toolCalls = const [],
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.latencyMs = 0,
    required this.model,
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

class OllamaClient {
  final String baseUrl;
  final String? apiKey;
  final String defaultModel;
  final http.Client _httpClient;

  OllamaClient({
    String? baseUrl,
    String? apiKey,
    this.defaultModel = 'glm-5.3-flash:cloud',
    http.Client? httpClient,
  })  : baseUrl = baseUrl ??
            Platform.environment['OLLAMA_BASE_URL'] ??
            'http://127.0.0.1:11434',
        apiKey = apiKey ?? Platform.environment['OLLAMA_API_KEY'],
        _httpClient = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };

  /// Sends a chat request to Ollama /api/chat with full support for glm-5.3-flash:cloud
  Future<LLMResponse> chat({
    required List<Map<String, dynamic>> messages,
    String? model,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.0,
    int? seed = 42,
    int maxTokens = 2048,
  }) async {
    final activeModel = model ?? defaultModel;
    final stopwatch = Stopwatch()..start();

    final payload = {
      'model': activeModel,
      'messages': messages,
      'stream': false,
      'options': {
        'temperature': temperature,
        if (seed != null) 'seed': seed,
        'num_predict': maxTokens,
      },
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    };

    try {
      final uri = Uri.parse('$baseUrl/api/chat');
      final res = await _httpClient.post(
        uri,
        headers: _headers,
        body: jsonEncode(payload),
      );
      stopwatch.stop();

      if (res.statusCode != 200) {
        throw HttpException(
            'Ollama API returned status ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>? ?? {};
      final content = message['content'] as String? ?? '';
      final thinking = message['thinking'] as String?;

      final rawToolCalls = message['tool_calls'] as List? ?? [];
      final toolCalls = <ToolCall>[];
      for (final tc in rawToolCalls) {
        if (tc is Map) {
          final fn = tc['function'] as Map? ?? {};
          final name = fn['name'] as String? ?? '';
          final args = fn['arguments'];
          final parsedArgs = args is Map
              ? Map<String, dynamic>.from(args)
              : (args is String ? jsonDecode(args) as Map<String, dynamic> : <String, dynamic>{});
          toolCalls.add(ToolCall(
            name: name,
            arguments: parsedArgs,
            callId: tc['id'] as String?,
          ));
        }
      }

      final promptTokens = (data['prompt_eval_count'] as num?)?.toInt() ?? 0;
      final completionTokens = (data['eval_count'] as num?)?.toInt() ?? 0;

      return LLMResponse(
        content: content,
        thinking: thinking,
        toolCalls: toolCalls,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        latencyMs: stopwatch.elapsedMilliseconds,
        model: activeModel,
      );
    } catch (e) {
      stopwatch.stop();
      // If offline/unreachable in simulated or mock testing, throw meaningful exception
      rethrow;
    }
  }

  /// Simple completion helper
  Future<String> complete(
    String prompt, {
    String? model,
    String? system,
    double temperature = 0.0,
    int? seed = 42,
    int maxTokens = 2048,
  }) async {
    final messages = [
      if (system != null) {'role': 'system', 'content': system},
      {'role': 'user', 'content': prompt},
    ];
    final res = await chat(
      messages: messages,
      model: model,
      temperature: temperature,
      seed: seed,
      maxTokens: maxTokens,
    );
    return res.content;
  }

  void close() {
    _httpClient.close();
  }
}
