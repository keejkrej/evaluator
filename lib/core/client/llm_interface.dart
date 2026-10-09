abstract class LLMInterface {
  Future<dynamic> chat({
    required List<Map<String, dynamic>> messages,
    String? model,
    List<Map<String, dynamic>>? tools,
    double temperature,
    int? seed,
    int maxTokens,
  });

  Future<String> complete(
    String prompt, {
    String? model,
    String? system,
    double temperature,
    int? seed,
    int maxTokens,
  });

  void close();
}
