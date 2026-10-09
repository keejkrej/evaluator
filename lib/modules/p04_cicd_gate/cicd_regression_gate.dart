import 'dart:io';

class GateThresholds {
  final double maxSuccessDrop; // e.g. 0.02 = 2%
  final double maxLatencySpike; // e.g. 0.15 = 15%
  final double maxCostSpike; // e.g. 0.10 = 10%
  final double hysteresisMargin; // e.g. 0.005 = 0.5%

  const GateThresholds({
    this.maxSuccessDrop = 0.02,
    this.maxLatencySpike = 0.15,
    this.maxCostSpike = 0.10,
    this.hysteresisMargin = 0.005,
  });
}

class RegressionGateDecision {
  final bool shouldBlock;
  final String status;
  final double baselineSuccessRate;
  final double candidateSuccessRate;
  final double successDrop;
  final double baselineLatencyP95;
  final double candidateLatencyP95;
  final double latencySpikeRatio;
  final List<String> blockingReasons;
  final List<String> failingCaseIds;

  RegressionGateDecision({
    required this.shouldBlock,
    required this.status,
    required this.baselineSuccessRate,
    required this.candidateSuccessRate,
    required this.successDrop,
    required this.baselineLatencyP95,
    required this.candidateLatencyP95,
    required this.latencySpikeRatio,
    required this.blockingReasons,
    required this.failingCaseIds,
  });

  Map<String, dynamic> toJson() => {
        'should_block': shouldBlock,
        'status': status,
        'baseline_success_rate': baselineSuccessRate,
        'candidate_success_rate': candidateSuccessRate,
        'success_drop': successDrop,
        'baseline_latency_p95': baselineLatencyP95,
        'candidate_latency_p95': candidateLatencyP95,
        'latency_spike_ratio': latencySpikeRatio,
        'blocking_reasons': blockingReasons,
        'failing_case_ids': failingCaseIds,
      };

  String toGithubMarkdown() {
    final buf = StringBuffer();
    if (shouldBlock) {
      buf.writeln('## 🚨 CI/CD Regression Gate: MERGE BLOCKED');
      buf.writeln();
      buf.writeln('> **Action Required:** This pull request introduced a regression exceeding safety thresholds and cannot be merged.');
    } else {
      buf.writeln('## ✅ CI/CD Regression Gate: PASSED');
      buf.writeln();
      buf.writeln('> **All Quality Gates Clear:** Candidate model/prompt metrics satisfy regression invariants.');
    }
    buf.writeln();
    buf.writeln('| Metric | Baseline (main) | Candidate (PR) | Delta | Threshold Gate |');
    buf.writeln('|---|---|---|---|---|');
    final successDeltaPct = (-successDrop * 100).toStringAsFixed(1);
    final successIcon = successDrop > 0.02 ? '❌ FAILED' : '✅ PASSED';
    buf.writeln('| **Task Success Rate** | ${(baselineSuccessRate * 100).toStringAsFixed(1)}% | ${(candidateSuccessRate * 100).toStringAsFixed(1)}% | $successDeltaPct% | $successIcon (drop ≤ 2.0%) |');

    final latencyDeltaPct = (latencySpikeRatio * 100).toStringAsFixed(1);
    final latencyIcon = latencySpikeRatio > 0.15 ? '❌ FAILED' : '✅ PASSED';
    buf.writeln('| **P95 Latency** | ${baselineLatencyP95.toStringAsFixed(0)}ms | ${candidateLatencyP95.toStringAsFixed(0)}ms | +$latencyDeltaPct% | $latencyIcon (spike ≤ 15.0%) |');
    buf.writeln();

    if (blockingReasons.isNotEmpty) {
      buf.writeln('### ⛔ Blocking Reasons');
      for (final reason in blockingReasons) {
        buf.writeln('- $reason');
      }
      buf.writeln();
    }

    if (failingCaseIds.isNotEmpty) {
      buf.writeln('### 🔍 Regressed Test Cases (${failingCaseIds.length})');
      for (final id in failingCaseIds) {
        buf.writeln('- `$id`');
      }
      buf.writeln();
    }

    return buf.toString();
  }
}

class CICDRegressionGate {
  final GateThresholds thresholds;

  CICDRegressionGate({
    this.thresholds = const GateThresholds(),
  });

  /// Evaluates candidate metrics vs baseline metrics and determines merge gate outcome
  RegressionGateDecision evaluate({
    required Map<String, dynamic> baselineMetrics,
    required Map<String, dynamic> candidateMetrics,
    List<String> failingCases = const [],
  }) {
    final baseSuccess = (baselineMetrics['success_rate'] as num?)?.toDouble() ?? 1.0;
    final candSuccess = (candidateMetrics['success_rate'] as num?)?.toDouble() ?? 1.0;
    final successDrop = baseSuccess - candSuccess;

    final baseLat = (baselineMetrics['latency_p95'] as num?)?.toDouble() ?? 300.0;
    final candLat = (candidateMetrics['latency_p95'] as num?)?.toDouble() ?? 300.0;
    final latencySpikeRatio = baseLat > 0 ? (candLat - baseLat) / baseLat : 0.0;

    final blockingReasons = <String>[];

    // Check success drop threshold with hysteresis
    if (successDrop > (thresholds.maxSuccessDrop + thresholds.hysteresisMargin)) {
      blockingReasons.add(
          'Task success rate dropped by ${(successDrop * 100).toStringAsFixed(1)}% (Threshold: ${(thresholds.maxSuccessDrop * 100).toStringAsFixed(1)}%)');
    }

    // Check latency spike
    if (latencySpikeRatio > thresholds.maxLatencySpike) {
      blockingReasons.add(
          'P95 Latency spiked by ${(latencySpikeRatio * 100).toStringAsFixed(1)}% from ${baseLat}ms to ${candLat}ms (Threshold: ${(thresholds.maxLatencySpike * 100).toStringAsFixed(1)}%)');
    }

    final shouldBlock = blockingReasons.isNotEmpty;
    final status = shouldBlock ? 'BLOCK_MERGE' : 'ALLOW_MERGE';

    return RegressionGateDecision(
      shouldBlock: shouldBlock,
      status: status,
      baselineSuccessRate: baseSuccess,
      candidateSuccessRate: candSuccess,
      successDrop: successDrop,
      baselineLatencyP95: baseLat,
      candidateLatencyP95: candLat,
      latencySpikeRatio: latencySpikeRatio,
      blockingReasons: blockingReasons,
      failingCaseIds: failingCases,
    );
  }

  /// Writes GitHub Action step output or exit code
  static void writePRCommentAndExit(RegressionGateDecision decision, {String? outputPath}) {
    final md = decision.toGithubMarkdown();
    if (outputPath != null) {
      File(outputPath).writeAsStringSync(md);
    }
    stdout.writeln(md);
    if (decision.shouldBlock) {
      exitCode = 1;
    } else {
      exitCode = 0;
    }
  }
}
