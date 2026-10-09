import 'package:test/test.dart';
import 'package:evaluator/evaluator.dart';

void main() {
  setUpAll(() {
    DatasetManager.seedBuiltinDatasets();
  });

  group('Project 1: Trajectory Grading Engine', () {
    test('passes valid golden trajectory through DAG', () {
      final grader = TrajectoryGrader();
      final goldens = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/golden_trajectories.jsonl');
      expect(goldens.isNotEmpty, isTrue);

      final result = grader.grade(trajectory: goldens.first, dagName: 'financial_refund');
      expect(result.passed, isTrue);
      expect(result.failingStep, isNull);
      expect(result.trajectoryDistance, equals(0.0));
      expect(result.stateCoverage, equals(1.0));
    });

    test('fails trajectory when hallucinated parameter is injected', () {
      final grader = TrajectoryGrader();
      final faulty = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/faulty_trajectories.jsonl');
      final hallucinatedTraj = faulty.firstWhere((t) => t.id == 'traj_faulty_hallucinated_param');

      final result = grader.grade(trajectory: hallucinatedTraj, dagName: 'financial_refund');
      expect(result.passed, isFalse);
      expect(result.violatedRule, equals('HALLUCINATED_PARAMETER'));
      expect(result.failingStep, equals(4));
      expect(result.failureReason, contains('force_override_fraud_checks'));
    });

    test('fails trajectory when safety check is skipped', () {
      final grader = TrajectoryGrader();
      final faulty = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/faulty_trajectories.jsonl');
      final skippedSafetyTraj = faulty.firstWhere((t) => t.id == 'traj_faulty_skipped_safety');

      final result = grader.grade(trajectory: skippedSafetyTraj, dagName: 'database_migration');
      expect(result.passed, isFalse);
      expect(result.violatedRule, equals('SKIPPED_SAFETY_CHECK'));
      expect(result.failingStep, equals(2));
      expect(result.failureReason, contains('backup_table'));
    });
  });

  group('Project 2: Shadow Routing Comparator', () {
    test('compares primary vs shadow trajectories and computes divergence', () {
      final comparator = ShadowRoutingComparator(samplingRate: 0.05);
      final goldens = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/golden_trajectories.jsonl');

      final report = comparator.compareTrajectories(
        primaryTrajectories: goldens,
        candidateTrajectories: goldens,
      );

      expect(report.totalRequests, equals(goldens.length));
      expect(report.toolAlignmentRate, equals(1.0));
      expect(report.routingRecommendation, equals('PROMOTE_TO_CANARY'));
      expect(report.costSavingsPercentage, greaterThan(80.0)); // Flash model is cheaper
      expect(report.toMarkdown(), contains('Shadow Routing Comparator Report'));
    });
  });

  group('Project 3: Calibrated LLM-as-a-Judge', () {
    test('calibrates judge against 500 human anchors and computes biases', () async {
      final anchors = DataLoader.loadHumanAnchorsFromJsonl('data/judge_anchors/500_human_anchors.jsonl');
      expect(anchors.length, equals(500));

      final judge = CalibratedJudge();
      final report = await judge.calibrateAgainstAnchors(anchors);

      expect(report.anchorCount, equals(500));
      expect(report.cohensKappa, greaterThan(0.50));
      expect(report.pearsonCorrelation, greaterThan(0.70));
      expect(report.verbosityBiasScore, lessThan(0.05));
      expect(report.positionInconsistencyRate, lessThan(0.10));
      expect(report.status, equals('CALIBRATED_SCIENTIFIC_INSTRUMENT'));
    });
  });

  group('Project 4: CI/CD Regression Gate', () {
    test('blocks merge when task success drops >2%', () {
      final gate = CICDRegressionGate(thresholds: const GateThresholds(maxSuccessDrop: 0.02));

      final decision = gate.evaluate(
        baselineMetrics: {'success_rate': 0.98, 'latency_p95': 200.0},
        candidateMetrics: {'success_rate': 0.94, 'latency_p95': 210.0}, // 4% drop
      );

      expect(decision.shouldBlock, isTrue);
      expect(decision.status, equals('BLOCK_MERGE'));
      expect(decision.blockingReasons.first, contains('dropped by 4.0%'));
      expect(decision.toGithubMarkdown(), contains('MERGE BLOCKED'));
    });

    test('allows merge when metrics are within acceptable thresholds', () {
      final gate = CICDRegressionGate();

      final decision = gate.evaluate(
        baselineMetrics: {'success_rate': 0.98, 'latency_p95': 200.0},
        candidateMetrics: {'success_rate': 0.975, 'latency_p95': 210.0}, // 0.5% drop
      );

      expect(decision.shouldBlock, isFalse);
      expect(decision.status, equals('ALLOW_MERGE'));
      expect(decision.toGithubMarkdown(), contains('PASSED'));
    });
  });

  group('Project 5: RAG Adversarial Harness', () {
    test('evaluates retrieval and generation gates with abstention scoring', () async {
      final harness = RAGAdversarialHarness();
      final cases = DataLoader.loadRAGCasesFromJsonl('data/rag/adversarial_rag.jsonl');
      expect(cases.length, greaterThanOrEqualTo(3));

      final metrics = await harness.evaluateSuite(cases);
      expect(metrics.hitRate, equals(1.0));
      expect(metrics.abstentionAccuracy, equals(1.0));
      expect(metrics.faithfulnessScore, greaterThan(0.90));
      expect(metrics.overallRAGScore, greaterThan(0.85));
      expect(metrics.toMarkdown(), contains('RAG Adversarial & Grounding Harness Report'));
    });
  });

  group('Project 6: Automated DPO Flywheel', () {
    test('formats production feedback into DPO preference pairs and generates LoRA script', () {
      final flywheel = DPOFlywheel(outputDir: 'data/dpo_feedback');
      final pairs = DataLoader.loadDPOPairsFromJsonl('data/dpo_feedback/production_feedback.jsonl');

      final report = flywheel.processFeedback(rawPairs: pairs);
      expect(report.validPairsGenerated, equals(pairs.length));
      expect(report.rejectedCount, equals(0));
      expect(report.averageTokenDelta, greaterThan(0));
      expect(report.toMarkdown(), contains('Automated DPO Flywheel Report'));
    });
  });

  group('Project 7: Statistical Significance Engine', () {
    test('computes bootstrap confidence intervals and McNemar significance', () {
      final baseline = List.generate(100, (i) => i % 5 == 0 ? 0.0 : 1.0); // 80%
      final candidate = List.generate(100, (i) => i % 8 == 0 ? 0.0 : 1.0); // 87.5%

      final report = StatisticalSignificanceEngine.evaluatePairedDeltas(
        candidateScores: candidate,
        baselineScores: baseline,
        bootstrapIterations: 2000,
      );

      expect(report.scoreB, greaterThan(report.scoreA));
      expect(report.bootstrapResult.ciLower, isNotNull);
      expect(report.bootstrapResult.ciUpper, isNotNull);
      expect(report.bootstrapResult.marginOfError, greaterThan(0.0));
      expect(report.executiveSummary, contains('wins by'));
    });
  });

  group('Project 8: Agent Red-Team Fuzzer', () {
    test('runs prompt injection, schema fuzzer and loop traps', () async {
      final fuzzer = AgentRedTeamFuzzer();
      final report = await fuzzer.runFuzzSuite();

      expect(report.totalAttacks, greaterThanOrEqualTo(5));
      expect(report.defendedCount, equals(report.totalAttacks));
      expect(report.resilienceScore, equals(1.0));
      expect(report.toMarkdown(), contains('Agent Red-Team Fuzzer Security Report'));
    });
  });

  group('Project 9: Production Drift Monitor', () {
    test('evaluates nightly traffic and detects stable distribution', () {
      final monitor = ProductionDriftMonitor(
        baselineFailureRate: 0.02,
        baselineLatencyMs: 1300.0,
      );
      final goldens = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/golden_trajectories.jsonl');

      final metrics = monitor.evaluateNightlyTraffic(goldens);
      expect(metrics.samplesEvaluated, equals(goldens.length));
      expect(metrics.liveFailureRate, equals(0.0));
      expect(metrics.alertTriggered, isFalse);
      expect(metrics.toMarkdown(), contains('Production Metrics Stable'));
    });
  });

  group('Project 10: Cost-Quality Pareto Dashboard', () {
    test('calculates Pareto optimal frontier and generates HTML dashboard', () {
      final pool = CostQualityParetoDashboard.getSampleCandidatePool();
      final frontier = CostQualityParetoDashboard.computeParetoFrontier(pool);

      final flashModel = frontier.firstWhere((c) => c.id == 'cfg_sys1_flash');
      final legacyModel = frontier.firstWhere((c) => c.id == 'cfg_legacy_inefficient');

      expect(flashModel.isParetoOptimal, isTrue);
      expect(legacyModel.isParetoOptimal, isFalse); // Dominated

      final html = CostQualityParetoDashboard.generateHtmlVisualizer(pool);
      expect(html, contains('Pareto Optimization Curve'));
      expect(html, contains('PARETO OPTIMAL'));
    });
  });

  group('Project 11: Counterfactual Replay Debugger', () {
    test('mutates hallucinated step and rescues trajectory to success', () {
      final debugger = CounterfactualDebugger();
      final faulty = DataLoader.loadTrajectoriesFromJsonl('data/trajectories/faulty_trajectories.jsonl').first;

      final replay = debugger.replayWithNodeMutation(
        trajectory: faulty,
        stepToMutate: 4,
        mutatedToolCall: ToolCall(name: 'execute_refund', arguments: {
          'amount_cents': 12000,
          'currency': 'USD',
          'reason': 'customer_satisfaction',
        }),
        mutatedToolResult: ToolResult(toolName: 'execute_refund', output: {'status': 'ok'}),
        mutationDescription: 'Stripped hallucinated parameters',
      );

      expect(replay.didOutcomeChange, isTrue);
      expect(replay.originalOutcome, contains('FAILED'));
      expect(replay.counterfactualOutcome, equals('PASSED'));
      expect(replay.toMarkdown(), contains('Root Cause Isolated'));
    });
  });

  group('Project 12: Synthetic Edge-Case Generator', () {
    test('generates boundary conditions and OOD edge cases', () async {
      final generator = SyntheticEdgeCaseGenerator();
      final edgeCases = await generator.generateEdgeCases(domain: 'financial_refund', count: 3);

      expect(edgeCases.length, equals(3));
      expect(edgeCases.first.category, isNotEmpty);
      expect(edgeCases.first.requiredDefense, isNotEmpty);
    });
  });

  group('Project 13: Context Window Eviction Tester', () {
    test('tests needle retrieval across depth spectrum', () async {
      final tester = ContextEvictionTester();
      final report = await tester.testContextEviction(targetTokens: 1000);

      expect(report.overallRetrievalAccuracy, equals(1.0));
      expect(report.depthBreakdown.length, equals(5));
      expect(report.toMarkdown(), contains('Context Window Eviction & Memory Stress Report'));
    });
  });

  group('Project 14: Dataset Contamination Checker', () {
    test('detects leaked n-grams between eval set and training corpus', () {
      final checker = DatasetContaminationChecker(nGramSize: 8);
      final evalSet = [
        {'id': 'eval_01', 'text': 'The capital of Australia is Canberra, founded in 1913 as a compromise.'},
        {'id': 'eval_02', 'text': 'Unique uncontaminated evaluation prompt that does not exist anywhere.'}
      ];
      final trainingCorpus = [
        {'id': 'train_01', 'text': 'The capital of Australia is Canberra, founded in 1913 as a compromise.'}
      ];

      final report = checker.scan(evalSet: evalSet, trainingCorpus: trainingCorpus);
      expect(report.contaminatedCasesCount, equals(1));
      expect(report.contaminationPercentage, equals(0.50));
      expect(report.matches.first.evalId, equals('eval_01'));
      expect(report.toMarkdown(), contains('Leaked Spans Detected'));
    });
  });

  group('Project 15: Public Eval Methodology Teardowns', () {
    test('generates all three publication-ready teardown specifications', () {
      final paths = MethodologyTeardown.generateAllTeardowns(outputDir: 'teardowns');
      expect(paths.length, equals(3));
      for (final p in paths) {
        expect(p, contains('.md'));
      }
    });
  });
}
