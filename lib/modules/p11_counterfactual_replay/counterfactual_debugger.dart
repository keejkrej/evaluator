import '../../core/client/ollama_client.dart';
import '../../core/models/models.dart';
import '../../core/dag/deterministic_dag.dart';

class CounterfactualReplayResult {
  final Trajectory originalTrajectory;
  final Trajectory counterfactualTrajectory;
  final int mutationStepIndex;
  final String mutationDescription;
  final bool didOutcomeChange;
  final String originalOutcome;
  final String counterfactualOutcome;
  final List<String> originalStepActions;
  final List<String> counterfactualStepActions;

  CounterfactualReplayResult({
    required this.originalTrajectory,
    required this.counterfactualTrajectory,
    required this.mutationStepIndex,
    required this.mutationDescription,
    required this.didOutcomeChange,
    required this.originalOutcome,
    required this.counterfactualOutcome,
    required this.originalStepActions,
    required this.counterfactualStepActions,
  });

  Map<String, dynamic> toJson() => {
        'original_id': originalTrajectory.id,
        'counterfactual_id': counterfactualTrajectory.id,
        'mutation_step': mutationStepIndex,
        'mutation': mutationDescription,
        'outcome_changed': didOutcomeChange,
        'original_outcome': originalOutcome,
        'counterfactual_outcome': counterfactualOutcome,
        'original_actions': originalStepActions,
        'counterfactual_actions': counterfactualStepActions,
      };

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# 🔀 Counterfactual Replay Debugger Report');
    buf.writeln();
    buf.writeln('**Causal Bifurcation Step:** `Step $mutationStepIndex`');
    buf.writeln('**Mutation Applied:** `$mutationDescription`');
    buf.writeln('**Outcome Changed:** ${didOutcomeChange ? "✅ Causal Root Identified (Failure -> Success)" : "No change in final outcome"}');
    buf.writeln();
    buf.writeln('| Step | Original Execution | Counterfactual Replay |');
    buf.writeln('|---|---|---|');
    final maxSteps = originalStepActions.length > counterfactualStepActions.length
        ? originalStepActions.length
        : counterfactualStepActions.length;

    for (int i = 0; i < maxSteps; i++) {
      final orig = i < originalStepActions.length ? originalStepActions[i] : '<em>[terminated]</em>';
      final count = i < counterfactualStepActions.length ? counterfactualStepActions[i] : '<em>[terminated]</em>';
      final marker = (i + 1) == mutationStepIndex ? ' 👈 [MUTATED]' : '';
      buf.writeln('| Step ${i + 1}$marker | `$orig` | `$count` |');
    }

    buf.writeln();
    buf.writeln('### Root-Cause Assessment');
    if (didOutcomeChange) {
      buf.writeln('> 🎯 **Root Cause Isolated:** Replacing node `$mutationStepIndex` rescued the workflow from failure. The hallucination at step $mutationStepIndex was the causal origin of the downstream breakage.');
    } else {
      buf.writeln('> ⚠️ Counterfactual mutation at step $mutationStepIndex did not alter the ultimate failure outcome.');
    }
    return buf.toString();
  }
}

class CounterfactualDebugger {
  final OllamaClient? client;

  CounterfactualDebugger({this.client});

  /// Replays a trajectory after surgically mutating step k
  CounterfactualReplayResult replayWithNodeMutation({
    required Trajectory trajectory,
    required int stepToMutate,
    required ToolCall mutatedToolCall,
    required ToolResult mutatedToolResult,
    required String mutationDescription,
    DeterministicDAG? dag,
  }) {
    final activeDag = dag ?? DeterministicDAG.financialRefundDAG();
    final newSteps = <TrajectoryStep>[];

    // Copy steps before the mutation
    for (int i = 0; i < trajectory.steps.length; i++) {
      final s = trajectory.steps[i];
      if (s.stepIndex < stepToMutate) {
        newSteps.add(s);
      }
    }

    // Insert mutated step k
    newSteps.add(TrajectoryStep(
      stepIndex: stepToMutate,
      thought: 'Counterfactual replay: corrected step $stepToMutate',
      toolCall: mutatedToolCall,
      toolResult: mutatedToolResult,
      latencyMs: 150,
      promptTokens: 350,
      completionTokens: 40,
    ));

    // Complete the remaining steps according to the golden path or DAG
    final remainingGolden = activeDag.goldenPath.skip(stepToMutate).toList();
    int currentStep = stepToMutate + 1;
    for (final toolName in remainingGolden) {
      final node = activeDag.nodes[toolName];
      final sampleArgs = <String, dynamic>{};
      if (node != null) {
        for (final p in node.parameterSchema.entries) {
          if (p.value.type == 'string') sampleArgs[p.key] = 'valid_${p.key}';
          if (p.value.type == 'int') sampleArgs[p.key] = 100;
          if (p.value.type == 'double') sampleArgs[p.key] = 0.05;
        }
      }
      newSteps.add(TrajectoryStep(
        stepIndex: currentStep++,
        thought: 'Replaying downstream step with valid state.',
        toolCall: ToolCall(name: toolName, arguments: sampleArgs),
        toolResult: ToolResult(toolName: toolName, output: {'status': 'ok'}),
        latencyMs: 120,
        promptTokens: 400,
        completionTokens: 30,
      ));
    }

    final origRes = activeDag.gradeTrajectory(trajectory);
    final countTrajectory = Trajectory(
      id: '${trajectory.id}_counterfactual',
      query: trajectory.query,
      steps: newSteps,
      finalAnswer: 'Completed counterfactually.',
      isSuccess: true,
    );
    final countRes = activeDag.gradeTrajectory(countTrajectory);

    final origActions = trajectory.steps.where((s) => s.toolCall != null).map((s) => s.toolCall!.name).toList();
    final countActions = countTrajectory.steps.where((s) => s.toolCall != null).map((s) => s.toolCall!.name).toList();

    return CounterfactualReplayResult(
      originalTrajectory: trajectory,
      counterfactualTrajectory: countTrajectory,
      mutationStepIndex: stepToMutate,
      mutationDescription: mutationDescription,
      didOutcomeChange: origRes.passed != countRes.passed,
      originalOutcome: origRes.passed ? 'PASSED' : 'FAILED (${origRes.violatedRule})',
      counterfactualOutcome: countRes.passed ? 'PASSED' : 'FAILED (${countRes.violatedRule})',
      originalStepActions: origActions,
      counterfactualStepActions: countActions,
    );
  }
}
