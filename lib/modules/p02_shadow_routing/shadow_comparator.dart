import 'dart:math';
import '../../core/client/ollama_client.dart';
import '../../core/models/models.dart';

class ShadowComparisonResult {
  final String requestId;
  final String query;
  final Trajectory primaryTrajectory;
  final Trajectory shadowTrajectory;
  final double trajectoryDivergenceScore;
  final int latencyDeltaMs;
  final double primaryCostEstimate;
  final double shadowCostEstimate;
  final bool toolSequencesMatch;
  final List<String> primaryToolSequence;
  final List<String> shadowToolSequence;

  ShadowComparisonResult({
    required this.requestId,
    required this.query,
    required this.primaryTrajectory,
    required this.shadowTrajectory,
    required this.trajectoryDivergenceScore,
    required this.latencyDeltaMs,
    required this.primaryCostEstimate,
    required this.shadowCostEstimate,
    required this.toolSequencesMatch,
    required this.primaryToolSequence,
    required this.shadowToolSequence,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'query': query,
        'trajectory_divergence_score': trajectoryDivergenceScore,
        'latency_delta_ms': latencyDeltaMs,
        'primary_cost_estimate': primaryCostEstimate,
        'shadow_cost_estimate': shadowCostEstimate,
        'tool_sequences_match': toolSequencesMatch,
        'primary_tool_sequence': primaryToolSequence,
        'shadow_tool_sequence': shadowToolSequence,
      };
}

class ShadowRoutingReport {
  final int totalRequests;
  final int mirroredRequests;
  final double mirrorRate;
  final double averageLatencyDeltaMs;
  final double totalPrimaryCost;
  final double totalShadowCost;
  final double costSavingsPercentage;
  final double toolAlignmentRate;
  final String routingRecommendation;
  final List<ShadowComparisonResult> samples;

  ShadowRoutingReport({
    required this.totalRequests,
    required this.mirroredRequests,
    required this.mirrorRate,
    required this.averageLatencyDeltaMs,
    required this.totalPrimaryCost,
    required this.totalShadowCost,
    required this.costSavingsPercentage,
    required this.toolAlignmentRate,
    required this.routingRecommendation,
    required this.samples,
  });

  Map<String, dynamic> toJson() => {
        'total_requests': totalRequests,
        'mirrored_requests': mirroredRequests,
        'mirror_rate': mirrorRate,
        'average_latency_delta_ms': averageLatencyDeltaMs,
        'total_primary_cost': totalPrimaryCost,
        'total_shadow_cost': totalShadowCost,
        'cost_savings_percentage': costSavingsPercentage,
        'tool_alignment_rate': toolAlignmentRate,
        'routing_recommendation': routingRecommendation,
        'sample_count': samples.length,
      };

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# 🪞 Shadow Routing Comparator Report');
    buf.writeln();
    buf.writeln('**Recommendation:** `${routingRecommendation.toUpperCase()}`');
    buf.writeln();
    buf.writeln('| Metric | Primary Model | Shadow Model (GLM-5.3 Flash) | Delta / Change |');
    buf.writeln('|---|---|---|---|');
    buf.writeln('| **Mirrored Traffic** | 100% | ${(mirrorRate * 100).toStringAsFixed(1)}% | $mirroredRequests calls |');
    buf.writeln('| **Tool Alignment Rate** | 100% | ${(toolAlignmentRate * 100).toStringAsFixed(1)}% | ${toolAlignmentRate >= 0.95 ? '✅ Aligned' : '⚠️ Divergent'} |');
    buf.writeln('| **Avg Latency Delta** | Baseline | ${averageLatencyDeltaMs > 0 ? "+$averageLatencyDeltaMs" : "$averageLatencyDeltaMs"} ms | ${averageLatencyDeltaMs <= 0 ? '⚡ Faster' : 'Slower'} |');
    buf.writeln('| **Estimated Cost** | \$${totalPrimaryCost.toStringAsFixed(4)} | \$${totalShadowCost.toStringAsFixed(4)} | **-${costSavingsPercentage.toStringAsFixed(1)}%** |');
    buf.writeln();
    buf.writeln('### Trajectory Diffs (Top Mirrored Runs)');
    for (int i = 0; i < min(3, samples.length); i++) {
      final s = samples[i];
      buf.writeln('#### Run ${s.requestId}: "${s.query}"');
      buf.writeln('- **Primary Tools:** `${s.primaryToolSequence.join(' -> ')}`');
      buf.writeln('- **Shadow Tools:** `${s.shadowToolSequence.join(' -> ')}`');
      buf.writeln('- **Divergence Score:** `${s.trajectoryDivergenceScore.toStringAsFixed(2)}` | **Latency Delta:** `${s.latencyDeltaMs}ms`');
      buf.writeln();
    }
    return buf.toString();
  }
}

class ShadowRoutingComparator {
  final double samplingRate;
  final OllamaClient? shadowClient;
  final double primaryCostPer1k;
  final double shadowCostPer1k;

  ShadowRoutingComparator({
    this.samplingRate = 0.05,
    this.shadowClient,
    this.primaryCostPer1k = 0.002, // $0.002 per 1k tokens (baseline)
    this.shadowCostPer1k = 0.0002, // $0.0002 per 1k tokens (GLM-5.3-Flash)
  });

  /// Compares paired trajectories or runs shadow inference
  ShadowRoutingReport compareTrajectories({
    required List<Trajectory> primaryTrajectories,
    required List<Trajectory> candidateTrajectories,
  }) {
    assert(primaryTrajectories.length == candidateTrajectories.length);
    final count = primaryTrajectories.length;
    final samples = <ShadowComparisonResult>[];

    int alignedToolsCount = 0;
    int totalLatencyDelta = 0;
    double primaryCostSum = 0.0;
    double shadowCostSum = 0.0;

    for (int i = 0; i < count; i++) {
      final prim = primaryTrajectories[i];
      final shad = candidateTrajectories[i];

      final primTools = prim.steps
          .where((s) => s.toolCall != null)
          .map((s) => s.toolCall!.name)
          .toList();
      final shadTools = shad.steps
          .where((s) => s.toolCall != null)
          .map((s) => s.toolCall!.name)
          .toList();

      final toolsMatch = _listEquals(primTools, shadTools);
      if (toolsMatch) alignedToolsCount++;

      final latencyDelta = shad.totalLatencyMs - prim.totalLatencyMs;
      totalLatencyDelta += latencyDelta;

      final pCost = (prim.totalTokens / 1000.0) * primaryCostPer1k;
      final sCost = (shad.totalTokens / 1000.0) * shadowCostPer1k;
      primaryCostSum += pCost;
      shadowCostSum += sCost;

      final divergence = _calculateSequenceDivergence(primTools, shadTools);

      samples.add(ShadowComparisonResult(
        requestId: prim.id,
        query: prim.query,
        primaryTrajectory: prim,
        shadowTrajectory: shad,
        trajectoryDivergenceScore: divergence,
        latencyDeltaMs: latencyDelta,
        primaryCostEstimate: pCost,
        shadowCostEstimate: sCost,
        toolSequencesMatch: toolsMatch,
        primaryToolSequence: primTools,
        shadowToolSequence: shadTools,
      ));
    }

    final n = count == 0 ? 1 : count;
    final alignmentRate = alignedToolsCount / n;
    final avgLatencyDelta = totalLatencyDelta / n;
    final costSavings = primaryCostSum > 0
        ? ((primaryCostSum - shadowCostSum) / primaryCostSum) * 100.0
        : 0.0;

    String recommendation = 'PROMOTE_TO_CANARY';
    if (alignmentRate < 0.90) {
      recommendation = 'REJECT_TRAJECTORY_DIVERGENCE';
    } else if (avgLatencyDelta > 200) {
      recommendation = 'FLAG_LATENCY_SPIKE';
    }

    return ShadowRoutingReport(
      totalRequests: count,
      mirroredRequests: count,
      mirrorRate: samplingRate,
      averageLatencyDeltaMs: avgLatencyDelta,
      totalPrimaryCost: primaryCostSum,
      totalShadowCost: shadowCostSum,
      costSavingsPercentage: costSavings,
      toolAlignmentRate: alignmentRate,
      routingRecommendation: recommendation,
      samples: samples,
    );
  }

  static double _calculateSequenceDivergence(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0.0;
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 0.0;
    int mismatches = 0;
    for (int i = 0; i < maxLen; i++) {
      final itemA = i < a.length ? a[i] : null;
      final itemB = i < b.length ? b[i] : null;
      if (itemA != itemB) mismatches++;
    }
    return mismatches / maxLen;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
