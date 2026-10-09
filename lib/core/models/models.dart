import 'dart:convert';

/// Represents a single tool call within an agent trajectory step.
class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String? callId;

  ToolCall({
    required this.name,
    required this.arguments,
    this.callId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'arguments': arguments,
        if (callId != null) 'call_id': callId,
      };

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      name: json['name'] as String,
      arguments: json['arguments'] != null
          ? Map<String, dynamic>.from(json['arguments'] as Map)
          : <String, dynamic>{},
      callId: json['call_id'] as String?,
    );
  }

  @override
  String toString() => '$name(${jsonEncode(arguments)})';
}

/// Represents the execution output of a tool call.
class ToolResult {
  final String toolName;
  final dynamic output;
  final bool isError;
  final String? errorMessage;

  ToolResult({
    required this.toolName,
    required this.output,
    this.isError = false,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'tool_name': toolName,
        'output': output,
        'is_error': isError,
        if (errorMessage != null) 'error_message': errorMessage,
      };

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      toolName: json['tool_name'] as String,
      output: json['output'],
      isError: json['is_error'] as bool? ?? false,
      errorMessage: json['error_message'] as String?,
    );
  }
}

/// Represents a single step in an agent's execution trajectory.
class TrajectoryStep {
  final int stepIndex;
  final String? thought;
  final ToolCall? toolCall;
  final ToolResult? toolResult;
  final String? response;
  final int latencyMs;
  final int promptTokens;
  final int completionTokens;

  TrajectoryStep({
    required this.stepIndex,
    this.thought,
    this.toolCall,
    this.toolResult,
    this.response,
    this.latencyMs = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });

  Map<String, dynamic> toJson() => {
        'step_index': stepIndex,
        if (thought != null) 'thought': thought,
        if (toolCall != null) 'tool_call': toolCall!.toJson(),
        if (toolResult != null) 'tool_result': toolResult!.toJson(),
        if (response != null) 'response': response,
        'latency_ms': latencyMs,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
      };

  factory TrajectoryStep.fromJson(Map<String, dynamic> json) {
    return TrajectoryStep(
      stepIndex: json['step_index'] as int? ?? 0,
      thought: json['thought'] as String?,
      toolCall: json['tool_call'] != null
          ? ToolCall.fromJson(Map<String, dynamic>.from(json['tool_call'] as Map))
          : null,
      toolResult: json['tool_result'] != null
          ? ToolResult.fromJson(Map<String, dynamic>.from(json['tool_result'] as Map))
          : null,
      response: json['response'] as String?,
      latencyMs: json['latency_ms'] as int? ?? 0,
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
    );
  }
}

/// Represents an entire agent trajectory from prompt to completion.
class Trajectory {
  final String id;
  final String query;
  final List<TrajectoryStep> steps;
  final String? finalAnswer;
  final bool isSuccess;
  final Map<String, dynamic> metadata;

  Trajectory({
    required this.id,
    required this.query,
    required this.steps,
    this.finalAnswer,
    this.isSuccess = false,
    this.metadata = const {},
  });

  int get totalLatencyMs => steps.fold(0, (sum, s) => sum + s.latencyMs);
  int get totalPromptTokens => steps.fold(0, (sum, s) => sum + s.promptTokens);
  int get totalCompletionTokens => steps.fold(0, (sum, s) => sum + s.completionTokens);
  int get totalTokens => totalPromptTokens + totalCompletionTokens;

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'steps': steps.map((s) => s.toJson()).toList(),
        if (finalAnswer != null) 'final_answer': finalAnswer,
        'is_success': isSuccess,
        'metadata': metadata,
      };

  factory Trajectory.fromJson(Map<String, dynamic> json) {
    return Trajectory(
      id: json['id'] as String? ?? 'traj_${DateTime.now().millisecondsSinceEpoch}',
      query: json['query'] as String? ?? '',
      steps: (json['steps'] as List? ?? [])
          .map((s) => TrajectoryStep.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      finalAnswer: json['final_answer'] as String?,
      isSuccess: json['is_success'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }
}

/// Generic evaluation result for any test case or step.
class EvalResult {
  final String testId;
  final bool passed;
  final double score;
  final String? failureReason;
  final Map<String, dynamic> metrics;
  final int? failingStep;

  EvalResult({
    required this.testId,
    required this.passed,
    required this.score,
    this.failureReason,
    this.metrics = const {},
    this.failingStep,
  });

  Map<String, dynamic> toJson() => {
        'test_id': testId,
        'passed': passed,
        'score': score,
        if (failureReason != null) 'failure_reason': failureReason,
        'metrics': metrics,
        if (failingStep != null) 'failing_step': failingStep,
      };
}

/// RAG Evaluation Test Case
class RAGTestCase {
  final String id;
  final String query;
  final List<String> retrievedContexts;
  final String? groundTruthAnswer;
  final bool isAnswerable;
  final List<String> expectedCitations;
  final Map<String, dynamic> metadata;

  RAGTestCase({
    required this.id,
    required this.query,
    required this.retrievedContexts,
    this.groundTruthAnswer,
    this.isAnswerable = true,
    this.expectedCitations = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'retrieved_contexts': retrievedContexts,
        if (groundTruthAnswer != null) 'ground_truth_answer': groundTruthAnswer,
        'is_answerable': isAnswerable,
        'expected_citations': expectedCitations,
        'metadata': metadata,
      };

  factory RAGTestCase.fromJson(Map<String, dynamic> json) {
    return RAGTestCase(
      id: json['id'] as String,
      query: json['query'] as String,
      retrievedContexts: (json['retrieved_contexts'] as List? ?? []).cast<String>(),
      groundTruthAnswer: json['ground_truth_answer'] as String?,
      isAnswerable: json['is_answerable'] as bool? ?? true,
      expectedCitations: (json['expected_citations'] as List? ?? []).cast<String>(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }
}

/// DPO Preference Pair
class DPOPair {
  final String id;
  final String prompt;
  final String chosen;
  final String rejected;
  final String source;
  final Map<String, dynamic> metadata;

  DPOPair({
    required this.id,
    required this.prompt,
    required this.chosen,
    required this.rejected,
    required this.source,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'chosen': chosen,
        'rejected': rejected,
        'source': source,
        'metadata': metadata,
      };

  factory DPOPair.fromJson(Map<String, dynamic> json) {
    return DPOPair(
      id: json['id'] as String? ?? 'dpo_${DateTime.now().millisecondsSinceEpoch}',
      prompt: json['prompt'] as String,
      chosen: json['chosen'] as String,
      rejected: json['rejected'] as String,
      source: json['source'] as String? ?? 'production_feedback',
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }
}

/// Human Anchor for LLM Judge Calibration
class HumanAnchor {
  final String id;
  final String input;
  final String responseA;
  final String responseB;
  final double humanScoreA;
  final double humanScoreB;
  final String humanPreference; // 'A', 'B', or 'tie'
  final String rubricDimension;
  final String rationales;

  HumanAnchor({
    required this.id,
    required this.input,
    required this.responseA,
    required this.responseB,
    required this.humanScoreA,
    required this.humanScoreB,
    required this.humanPreference,
    required this.rubricDimension,
    this.rationales = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'input': input,
        'response_a': responseA,
        'response_b': responseB,
        'human_score_a': humanScoreA,
        'human_score_b': humanScoreB,
        'human_preference': humanPreference,
        'rubric_dimension': rubricDimension,
        'rationales': rationales,
      };

  factory HumanAnchor.fromJson(Map<String, dynamic> json) {
    return HumanAnchor(
      id: json['id'] as String,
      input: json['input'] as String,
      responseA: json['response_a'] as String,
      responseB: json['response_b'] as String,
      humanScoreA: (json['human_score_a'] as num).toDouble(),
      humanScoreB: (json['human_score_b'] as num).toDouble(),
      humanPreference: json['human_preference'] as String,
      rubricDimension: json['rubric_dimension'] as String? ?? 'overall',
      rationales: json['rationales'] as String? ?? '',
    );
  }
}
