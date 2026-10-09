import '../../core/statistics/statistics.dart';

class StatisticalSignificanceReport {
  final String modelA;
  final String modelB;
  final int sampleSize;
  final double scoreA;
  final double scoreB;
  final BootstrapResult bootstrapResult;
  final McNemarResult? mcNemarResult;
  final double cohensDEffectSize;
  final int recommendedSampleSize;
  final bool isStatisticallySignificant;
  final String executiveSummary;

  StatisticalSignificanceReport({
    required this.modelA,
    required this.modelB,
    required this.sampleSize,
    required this.scoreA,
    required this.scoreB,
    required this.bootstrapResult,
    this.mcNemarResult,
    required this.cohensDEffectSize,
    required this.recommendedSampleSize,
    required this.isStatisticallySignificant,
    required this.executiveSummary,
  });

  Map<String, dynamic> toJson() => {
        'model_a': modelA,
        'model_b': modelB,
        'sample_size': sampleSize,
        'score_a': scoreA,
        'score_b': scoreB,
        'bootstrap': bootstrapResult.toJson(),
        if (mcNemarResult != null) 'mcnemar': mcNemarResult!.toJson(),
        'cohens_d': cohensDEffectSize,
        'recommended_sample_size': recommendedSampleSize,
        'is_statistically_significant': isStatisticallySignificant,
        'executive_summary': executiveSummary,
      };

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# 📊 Statistical Significance Engine Report');
    buf.writeln();
    buf.writeln('> **Executive Decision Math:** $executiveSummary');
    buf.writeln();
    buf.writeln('| Dimension | Baseline ($modelA) | Candidate ($modelB) | Delta & Rigor |');
    buf.writeln('|---|---|---|---|');
    buf.writeln('| **Accuracy / Mean Score** | ${(scoreA * 100).toStringAsFixed(1)}% | ${(scoreB * 100).toStringAsFixed(1)}% | **${bootstrapResult.formatPercentage()}** |');
    buf.writeln('| **Bootstrap 95% CI** | - | - | `[${(bootstrapResult.ciLower * 100).toStringAsFixed(1)}%, ${(bootstrapResult.ciUpper * 100).toStringAsFixed(1)}%]` |');
    buf.writeln('| **P-Value (Two-Tailed)** | - | - | `${bootstrapResult.pValue < 0.001 ? "p < 0.001" : "p = ${bootstrapResult.pValue.toStringAsFixed(4)}"}` ${isStatisticallySignificant ? "✅ (p < 0.05)" : "⚠️ (p ≥ 0.05, Noise)"} |');
    buf.writeln('| **Effect Size (Cohen\'s d)** | - | - | `${cohensDEffectSize.toStringAsFixed(2)}` (${_interpretEffectSize(cohensDEffectSize)}) |');
    buf.writeln('| **Evaluated Sample Size** | N = $sampleSize | N = $sampleSize | Min Required for 80% Power: **$recommendedSampleSize samples** |');

    if (mcNemarResult != null) {
      buf.writeln();
      buf.writeln('### McNemar Paired Contingency Test');
      buf.writeln('- **Candidate Only Wins (Discordant b):** ${mcNemarResult!.bWins}');
      buf.writeln('- **Baseline Only Wins (Discordant c):** ${mcNemarResult!.aWins}');
      buf.writeln('- **Chi-Square Statistic:** `${mcNemarResult!.chiSquare.toStringAsFixed(2)}` (p = ${mcNemarResult!.pValue.toStringAsFixed(4)})');
    }

    return buf.toString();
  }

  static String _interpretEffectSize(double d) {
    final absD = d.abs();
    if (absD < 0.2) return 'Negligible';
    if (absD < 0.5) return 'Small';
    if (absD < 0.8) return 'Medium';
    return 'Large';
  }
}

class StatisticalSignificanceEngine {
  /// Evaluates paired evaluation scores and produces bootstrap intervals & hypothesis tests
  static StatisticalSignificanceReport evaluatePairedDeltas({
    required List<double> candidateScores,
    required List<double> baselineScores,
    String candidateName = 'Model B (GLM-5.3-Flash)',
    String baselineName = 'Model A (Baseline)',
    int bootstrapIterations = 10000,
  }) {
    assert(candidateScores.length == baselineScores.length);
    final n = candidateScores.length;

    final bootstrap = Statistics.bootstrapPairedDifference(
      candidateScores: candidateScores,
      baselineScores: baselineScores,
      iterations: bootstrapIterations,
    );

    final meanA = baselineScores.reduce((a, b) => a + b) / n;
    final meanB = candidateScores.reduce((a, b) => a + b) / n;

    final effectSize = Statistics.cohensD(candidateScores, baselineScores);
    final isSignificant = bootstrap.pValue < 0.05 && (bootstrap.ciLower > 0 || bootstrap.ciUpper < 0);

    // Compute required sample size for the observed delta
    final requiredN = Statistics.requiredSampleSize(
      minimumDetectableDelta: bootstrap.meanDelta.abs() < 0.01 ? 0.02 : bootstrap.meanDelta.abs(),
    );

    // McNemar test if scores are binary (0.0 or 1.0)
    final isBinary = candidateScores.every((s) => s == 0.0 || s == 1.0) &&
        baselineScores.every((s) => s == 0.0 || s == 1.0);

    McNemarResult? mcNemar;
    if (isBinary) {
      mcNemar = Statistics.mcNemarTest(
        modelAPasses: baselineScores.map((s) => s >= 0.5).toList(),
        modelBPasses: candidateScores.map((s) => s >= 0.5).toList(),
      );
    }

    final winSign = bootstrap.meanDelta >= 0 ? 'wins' : 'trails';
    final pStr = bootstrap.pValue < 0.001 ? 'p<0.001' : 'p=${bootstrap.pValue.toStringAsFixed(3)}';
    final summary = '$candidateName $winSign by ${(bootstrap.meanDelta.abs() * 100).toStringAsFixed(1)}% ± ${(bootstrap.marginOfError * 100).toStringAsFixed(1)}% ($pStr)';

    return StatisticalSignificanceReport(
      modelA: baselineName,
      modelB: candidateName,
      sampleSize: n,
      scoreA: meanA,
      scoreB: meanB,
      bootstrapResult: bootstrap,
      mcNemarResult: mcNemar,
      cohensDEffectSize: effectSize,
      recommendedSampleSize: requiredN,
      isStatisticallySignificant: isSignificant,
      executiveSummary: summary,
    );
  }
}
