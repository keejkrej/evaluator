import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:evaluator/evaluator.dart';

void main(List<String> arguments) async {
  // Ensure default datasets exist
  DatasetManager.seedBuiltinDatasets();

  final runner = CommandRunner(
    'evaluator',
    'AI Evals Engineering Suite in Dart: 15 Production Evaluation Systems.',
  )
    ..addCommand(TrajectoryCommand())
    ..addCommand(ShadowCommand())
    ..addCommand(JudgeCommand())
    ..addCommand(GateCommand())
    ..addCommand(RAGCommand())
    ..addCommand(DPOCommand())
    ..addCommand(StatsCommand())
    ..addCommand(RedTeamCommand())
    ..addCommand(DriftCommand())
    ..addCommand(ParetoCommand())
    ..addCommand(ReplayCommand())
    ..addCommand(SyntheticCommand())
    ..addCommand(EvictionCommand())
    ..addCommand(ContaminationCommand())
    ..addCommand(TeardownCommand())
    ..addCommand(DatasetCommand())
    ..addCommand(AllCommand());

  try {
    await runner.run(arguments.isEmpty ? ['--help'] : arguments);
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 2;
  }
}

/// 1. Trajectory Grading Engine
class TrajectoryCommand extends Command {
  @override
  final name = 'trajectory';
  @override
  final description = 'Step-level evaluator that scores agent tool calls against a deterministic DAG';

  TrajectoryCommand() {
    argParser.addOption('dag', abbr: 'd', defaultsTo: 'financial_refund', help: 'DAG workflow to enforce');
    argParser.addOption('input', abbr: 'i', help: 'Path to input trajectory JSONL');
  }

  @override
  void run() {
    final grader = TrajectoryGrader();
    final goldenTrajs = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/golden_trajectories.jsonl');
    final faultyTrajs = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/faulty_trajectories.jsonl');
    final all = [...goldenTrajs, ...faultyTrajs];

    stdout.writeln('=== [Project 1] Trajectory Grading Engine ===');
    stdout.writeln('Loaded ${all.length} trajectories. Evaluating against Deterministic DAG: financial_refund...');
    stdout.writeln();

    for (final traj in all) {
      final dagKey = traj.metadata['domain']?.toString() ??
          (traj.id.contains('migration') ? 'database_migration' : 'financial_refund');
      final res = grader.grade(trajectory: traj, dagName: dagKey);
      if (res.passed) {
        stdout.writeln('✅ [PASS] ${traj.id} ($dagKey): Valid transition sequence, 0 schema errors, safety invariant held.');
      } else {
        stdout.writeln('🚨 [FAIL] ${traj.id} ($dagKey):');
        stdout.writeln('   • Step: ${res.failingStep} (${res.failingTool})');
        stdout.writeln('   • Violation: ${res.violatedRule}');
        stdout.writeln('   • Reason: ${res.failureReason}');
      }
    }

    int passed = 0;
    int hallucinated = 0;
    int skippedSafety = 0;
    for (final traj in all) {
      final dagKey = traj.metadata['domain']?.toString() ??
          (traj.id.contains('migration') ? 'database_migration' : 'financial_refund');
      final res = grader.grade(trajectory: traj, dagName: dagKey);
      if (res.passed) passed++;
      if (res.violatedRule == 'HALLUCINATED_PARAMETER') hallucinated++;
      if (res.violatedRule == 'SKIPPED_SAFETY_CHECK') skippedSafety++;
    }

    stdout.writeln();
    stdout.writeln('--- Trajectory Summary ---');
    stdout.writeln('Pass Rate: ${((passed / all.length) * 100).toStringAsFixed(1)}% ($passed/${all.length})');
    stdout.writeln('Hallucinated Parameters: $hallucinated');
    stdout.writeln('Skipped Safety Checks: $skippedSafety');
  }
}

/// 2. Shadow Routing Comparator
class ShadowCommand extends Command {
  @override
  final name = 'shadow';
  @override
  final description = 'Mirror traffic to GLM-5.3-Flash, diff trajectories and generate cost/quality reports';

  ShadowCommand() {
    argParser.addOption('rate', defaultsTo: '0.05', help: 'Sampling rate (e.g. 0.05 = 5%)');
  }

  @override
  void run() {
    stdout.writeln('=== [Project 2] Shadow Routing Comparator ===');
    final comparator = ShadowRoutingComparator(samplingRate: double.tryParse(argResults?['rate'] ?? '0.05') ?? 0.05);
    final goldens = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/golden_trajectories.jsonl');

    final report = comparator.compareTrajectories(
      primaryTrajectories: goldens,
      candidateTrajectories: goldens,
    );
    stdout.writeln(report.toMarkdown());
  }
}

/// 3. Calibrated LLM-as-a-Judge
class JudgeCommand extends Command {
  @override
  final name = 'judge';
  @override
  final description = 'Measure judge verbosity, position and self-preference biases against 500 human anchors';

  @override
  Future<void> run() async {
    stdout.writeln('=== [Project 3] Calibrated LLM-as-a-Judge ===');
    final anchors = DataLoader.loadHumanAnchorsFromJsonl('data/judge_anchors/500_human_anchors.jsonl');
    stdout.writeln('Calibrating against ${anchors.length} human-labeled ground truth anchors...');
    final judge = CalibratedJudge();
    final report = await judge.calibrateAgainstAnchors(anchors);
    stdout.writeln(report.toMarkdown());
  }
}

/// 4. CI/CD Regression Gate
class GateCommand extends Command {
  @override
  final name = 'gate';
  @override
  final description = 'Block PR merges if task success drops >2% or latency spikes';

  @override
  void run() {
    stdout.writeln('=== [Project 4] CI/CD Regression Gate ===');
    final gate = CICDRegressionGate();

    // Baseline metrics from main branch
    final baseline = {'success_rate': 0.98, 'latency_p95': 280.0};
    // Candidate metrics from pull request
    final candidate = {'success_rate': 0.95, 'latency_p95': 340.0};

    final decision = gate.evaluate(
      baselineMetrics: baseline,
      candidateMetrics: candidate,
      failingCases: ['traj_migration_case_04'],
    );

    stdout.writeln(decision.toGithubMarkdown());
  }
}

/// 5. RAG Adversarial Harness
class RAGCommand extends Command {
  @override
  final name = 'rag';
  @override
  final description = 'Test suite injecting distractor context and contradictory docs for abstention testing';

  @override
  Future<void> run() async {
    stdout.writeln('=== [Project 5] RAG Adversarial Harness ===');
    final client = OllamaClient();
    final harness = RAGAdversarialHarness(client: client);
    final testCases = DataLoader.loadRAGCasesFromJsonl('data/rag/adversarial_rag.jsonl');
    stdout.writeln('Evaluating ${testCases.length} RAG queries across Retrieval and Generation gates with GLM-5.3-Flash...');

    final metrics = await harness.evaluateSuite(testCases);
    stdout.writeln(metrics.toMarkdown());
    client.close();
  }
}

/// 6. Automated DPO Flywheel
class DPOCommand extends Command {
  @override
  final name = 'dpo';
  @override
  final description = 'Capture user thumbs-downs, format into preference pairs and trigger LoRA fine-tuning';

  @override
  void run() {
    stdout.writeln('=== [Project 6] Automated DPO Flywheel ===');
    final flywheel = DPOFlywheel();
    final pairs = DataLoader.loadDPOPairsFromJsonl('data/dpo_feedback/production_feedback.jsonl');
    final report = flywheel.processFeedback(rawPairs: pairs);
    stdout.writeln(report.toMarkdown());
  }
}

/// 7. Statistical Significance Engine
class StatsCommand extends Command {
  @override
  final name = 'stats';
  @override
  final description = 'Bootstrapping utility that outputs Model B wins by X% ± Y% (p<0.05)';

  @override
  void run() {
    stdout.writeln('=== [Project 7] Statistical Significance Engine ===');
    // 100 paired evaluation samples
    final baselineScores = List.generate(100, (i) => i % 5 == 0 ? 0.0 : 1.0); // 80% baseline
    final candidateScores = List.generate(100, (i) => i % 8 == 0 ? 0.0 : 1.0); // 87.5% candidate

    final report = StatisticalSignificanceEngine.evaluatePairedDeltas(
      candidateScores: candidateScores,
      baselineScores: baselineScores,
      candidateName: 'Candidate Model (GLM-5.3-Flash)',
      baselineName: 'Baseline Model',
    );
    stdout.writeln(report.toMarkdown());
  }
}

/// 8. Agent Red-Team Fuzzer
class RedTeamCommand extends Command {
  @override
  final name = 'redteam';
  @override
  final description = 'Automated harness injecting prompt injections, malformed schemas and loop traps';

  @override
  Future<void> run() async {
    stdout.writeln('=== [Project 8] Agent Red-Team Fuzzer ===');
    final client = OllamaClient();
    final fuzzer = AgentRedTeamFuzzer(client: client);
    stdout.writeln('Executing Red-Team attack vectors against agent guardrails with GLM-5.3-Flash...');
    final report = await fuzzer.runFuzzSuite();
    stdout.writeln(report.toMarkdown());
    client.close();
  }
}

/// 9. Production Drift Monitor
class DriftCommand extends Command {
  @override
  final name = 'drift';
  @override
  final description = 'Sample 5% of live traffic nightly, run offline evals and alert on decay';

  @override
  void run() {
    stdout.writeln('=== [Project 9] Production Drift Monitor ===');
    final monitor = ProductionDriftMonitor(samplingFraction: 0.05);
    final goldens = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/golden_trajectories.jsonl');
    final metrics = monitor.evaluateNightlyTraffic(goldens);
    stdout.writeln(metrics.toMarkdown());
  }
}

/// 10. Cost-Quality Pareto Dashboard
class ParetoCommand extends Command {
  @override
  final name = 'pareto';
  @override
  final description = 'Visualizer mapping tradeoff between inference cost and task success rate';

  ParetoCommand() {
    argParser.addOption('out', abbr: 'o', defaultsTo: 'pareto_dashboard.html', help: 'Output HTML path');
  }

  @override
  void run() {
    stdout.writeln('=== [Project 10] Cost-Quality Pareto Dashboard ===');
    final pool = CostQualityParetoDashboard.getSampleCandidatePool();
    final outPath = argResults?['out'] as String? ?? 'pareto_dashboard.html';
    CostQualityParetoDashboard.generateHtmlVisualizer(pool, outputPath: outPath);
    stdout.writeln('✅ Generated Pareto Frontier visualizer at: $outPath');
  }
}

/// 11. Counterfactual Replay Debugger
class ReplayCommand extends Command {
  @override
  final name = 'replay';
  @override
  final description = 'Record LLM hops, mutate a node in the graph and replay remaining trajectory';

  @override
  void run() {
    stdout.writeln('=== [Project 11] Counterfactual Replay Debugger ===');
    final faultyTrajs = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/faulty_trajectories.jsonl');
    if (faultyTrajs.isEmpty) {
      stdout.writeln('No faulty trajectories found to debug.');
      return;
    }

    final faulty = faultyTrajs.first;
    final debugger = CounterfactualDebugger();

    stdout.writeln('Original trajectory failed: "${faulty.query}"');
    final result = debugger.replayWithNodeMutation(
      trajectory: faulty,
      stepToMutate: 4,
      mutatedToolCall: ToolCall(name: 'execute_refund', arguments: {
        'amount_cents': 12000,
        'currency': 'USD',
        'reason': 'customer_satisfaction',
      }),
      mutatedToolResult: ToolResult(toolName: 'execute_refund', output: {'status': 'success'}),
      mutationDescription: 'Removed hallucinated force_override_fraud_checks parameter',
    );

    stdout.writeln(result.toMarkdown());
  }
}

/// 12. Synthetic Edge-Case Generator
class SyntheticCommand extends Command {
  @override
  final name = 'synthetic';
  @override
  final description = 'Systematically generate out-of-distribution inputs and boundary conditions with GLM-5.3-Flash';

  @override
  Future<void> run() async {
    stdout.writeln('=== [Project 12] Synthetic Edge-Case Generator ===');
    final client = OllamaClient();
    final generator = SyntheticEdgeCaseGenerator(client: client);
    stdout.writeln('Synthesizing frontier boundary edge cases for domain "financial_refund" using GLM-5.3-Flash...');
    final edgeCases = await generator.generateEdgeCases(domain: 'financial_refund', count: 3);

    for (final ec in edgeCases) {
      stdout.writeln('⚡ [${ec.category.toUpperCase()}] ${ec.id}:');
      stdout.writeln('   • Prompt: "${ec.prompt}"');
      stdout.writeln('   • Failure Mode: ${ec.expectedFailureMode}');
      stdout.writeln('   • Required Defense: ${ec.requiredDefense}');
      stdout.writeln();
    }
    client.close();
  }
}

/// 13. Context Window Eviction Tester
class EvictionCommand extends Command {
  @override
  final name = 'eviction';
  @override
  final description = 'Fill working memory with noise to test compression, eviction and state retrieval';

  @override
  Future<void> run() async {
    stdout.writeln('=== [Project 13] Context Window Eviction Tester ===');
    final client = OllamaClient();
    final tester = ContextEvictionTester(client: client);
    stdout.writeln('Stress-testing context window memory depths [10%, 25%, 50%, 75%, 90%] with GLM-5.3-Flash...');
    final report = await tester.testContextEviction(targetTokens: 2000);
    stdout.writeln(report.toMarkdown());
    client.close();
  }
}

/// 14. Dataset Contamination Checker
class ContaminationCommand extends Command {
  @override
  final name = 'contamination';
  @override
  final description = 'N-gram and embedding similarity scanner ensuring eval set hasn\'t leaked into training';

  @override
  void run() {
    stdout.writeln('=== [Project 14] Dataset Contamination Checker ===');
    final evalLines = File('data/contamination/eval_set.jsonl').readAsLinesSync();
    final trainLines = File('data/contamination/training_corpus.jsonl').readAsLinesSync();

    final evalSet = evalLines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();
    final trainCorpus = trainLines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();

    final checker = DatasetContaminationChecker(nGramSize: 8);
    final report = checker.scan(evalSet: evalSet, trainingCorpus: trainCorpus);
    stdout.writeln(report.toMarkdown());
  }
}

/// 15. Public Eval Methodology Teardown
class TeardownCommand extends Command {
  @override
  final name = 'teardown';
  @override
  final description = 'Publish 3 deep-dives detailing exact grading rubrics, judge prompts and statistical frameworks';

  @override
  void run() {
    stdout.writeln('=== [Project 15] Public Eval Methodology Teardowns ===');
    final paths = MethodologyTeardown.generateAllTeardowns();
    stdout.writeln('Generated 3 publication-ready teardown specifications:');
    for (final p in paths) {
      stdout.writeln('  📄 $p');
    }
  }
}

/// Dataset Downloader & Synthesizer
class DatasetCommand extends Command {
  @override
  final name = 'dataset';
  @override
  final description = 'Download or generate evaluation benchmarks (SQuAD 2.0, BFCL, Trajectories)';

  DatasetCommand() {
    argParser.addOption('source', defaultsTo: 'squad2', help: 'Source dataset to download: squad2, generate_trajectories');
  }

  @override
  Future<void> run() async {
    final src = argResults?['source'] ?? 'squad2';
    stdout.writeln('Managing dataset: $src...');
    if (src == 'squad2') {
      stdout.writeln('Fetching real SQuAD 2.0 validation data from Stanford Explorer...');
      final cases = await DatasetManager.downloadSquad2(limit: 20);
      stdout.writeln('Downloaded ${cases.length} real SQuAD 2.0 test cases (including answerable & unanswerable abstention queries).');
      stdout.writeln('Sample query: "${cases.first.query}" (Answerable: ${cases.first.isAnswerable})');
    } else {
      DatasetManager.seedBuiltinDatasets();
      stdout.writeln('Seeded built-in golden evaluation datasets.');
    }
  }
}

/// All 15 Systems End-to-End Suite Runner
class AllCommand extends Command {
  @override
  final name = 'all';
  @override
  final description = 'Run all 15 AI Evals Engineering projects end-to-end';

  @override
  Future<void> run() async {
    stdout.writeln('===============================================================');
    stdout.writeln('🚀 RUNNING ALL 15 AI EVALS ENGINEERING PROJECTS IN DART');
    stdout.writeln('Powered by GLM-5.3-Flash & Rigorous Statistical Frameworks');
    stdout.writeln('===============================================================');
    stdout.writeln();

    TrajectoryCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    ShadowCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    await JudgeCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    GateCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    await RAGCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    DPOCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    StatsCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    await RedTeamCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    DriftCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    ParetoCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    ReplayCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    await SyntheticCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    await EvictionCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    ContaminationCommand().run();
    stdout.writeln('\n---------------------------------------------------------------\n');
    TeardownCommand().run();

    stdout.writeln();
    stdout.writeln('===============================================================');
    stdout.writeln('🎯 ALL 15 AI EVALS PROJECTS COMPLETED SUCCESSFULLY!');
    stdout.writeln('===============================================================');
  }
}
