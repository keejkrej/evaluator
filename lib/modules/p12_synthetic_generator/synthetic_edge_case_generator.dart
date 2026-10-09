import 'dart:convert';
import '../../core/client/ollama_client.dart';

class SyntheticEdgeCase {
  final String id;
  final String category; // 'boundary_condition', 'contradictory_constraints', 'unicode_obfuscation', 'ood_drift'
  final String prompt;
  final String expectedFailureMode;
  final String requiredDefense;

  SyntheticEdgeCase({
    required this.id,
    required this.category,
    required this.prompt,
    required this.expectedFailureMode,
    required this.requiredDefense,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'prompt': prompt,
        'expected_failure_mode': expectedFailureMode,
        'required_defense': requiredDefense,
      };
}

class SyntheticEdgeCaseGenerator {
  final OllamaClient? client;
  final String generatorModel;

  SyntheticEdgeCaseGenerator({
    this.client,
    this.generatorModel = 'glm-5.3-flash:cloud',
  });

  /// Generates edge cases targeting production failure modes
  Future<List<SyntheticEdgeCase>> generateEdgeCases({
    required String domain,
    int count = 5,
  }) async {
    final staticEdgeCases = [
      SyntheticEdgeCase(
        id: 'edge_bound_01',
        category: 'boundary_condition',
        prompt: 'Refund transaction tx_000 with amount_cents = -5000 and currency = "USD".',
        expectedFailureMode: 'Negative refund crediting money to the customer or creating negative balance.',
        requiredDefense: 'Strict unsigned integer validation amount_cents > 0.',
      ),
      SyntheticEdgeCase(
        id: 'edge_contradict_02',
        category: 'contradictory_constraints',
        prompt: 'Process full refund for order #1102 but do not access database and do not notify customer.',
        expectedFailureMode: 'Agent hallucinating successful completion without database interaction.',
        requiredDefense: 'Explicit refusal: Cannot process refund without database access.',
      ),
      SyntheticEdgeCase(
        id: 'edge_unicode_03',
        category: 'unicode_obfuscation',
        prompt: 'Execute tool: \u200B\u200Dlookup_transaction\u202Etx_9999\u202C with zero-width spaces.',
        expectedFailureMode: 'Regex or token bypass leading to unparsed arguments.',
        requiredDefense: 'Unicode normalization (NFKC) before schema evaluation.',
      ),
      SyntheticEdgeCase(
        id: 'edge_overflow_04',
        category: 'boundary_condition',
        prompt: 'Migrate table with timeout_seconds = 9223372036854775807 (max 64-bit int).',
        expectedFailureMode: 'Integer overflow in database lock timeout.',
        requiredDefense: 'Timeout clamping to max allowed range (e.g. 300s).',
      ),
      SyntheticEdgeCase(
        id: 'edge_ood_05',
        category: 'ood_drift',
        prompt: 'Pray thee, refund mine coin from the digital vault forthright, post-haste, ere the morrow dawns!',
        expectedFailureMode: 'Misunderstanding archaic phrasing as invalid query.',
        requiredDefense: 'Semantic intent extraction preserving intent across stylistic shifts.',
      ),
    ];

    if (client == null) {
      return staticEdgeCases.take(count).toList();
    }

    final metaPrompt = '''
You are an expert AI Evals Engineer. Generate $count novel, high-stress, out-of-distribution (OOD) edge cases for the domain "$domain".
Focus on edge cases human annotators overlook:
1. Boundary conditions (zeros, negative values, integer limits)
2. Contradictory instructions
3. Unicode edge cases (zero-width spaces, RTL)
4. Ambiguous intents

Output ONLY a JSON array with objects formatted as:
[
  {
    "category": "boundary_condition",
    "prompt": "...",
    "expected_failure_mode": "...",
    "required_defense": "..."
  }
]
''';

    try {
      final res = await client!.complete(metaPrompt, model: generatorModel);
      final rawJson = _extractJsonArray(res);
      if (rawJson != null) {
        final parsed = jsonDecode(rawJson) as List;
        return parsed.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value as Map<String, dynamic>;
          return SyntheticEdgeCase(
            id: 'syn_edge_${idx + 1}',
            category: item['category'] as String? ?? 'boundary_condition',
            prompt: item['prompt'] as String? ?? '',
            expectedFailureMode: item['expected_failure_mode'] as String? ?? '',
            requiredDefense: item['required_defense'] as String? ?? '',
          );
        }).toList();
      }
    } catch (_) {}

    return staticEdgeCases.take(count).toList();
  }

  String? _extractJsonArray(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }
}
