import 'dart:math';

/// Mathematical statistics and rigorous hypothesis testing for AI Evaluations.
class Statistics {
  static final _random = Random(42);

  /// Performs bootstrap resampling on paired differences (Candidate - Baseline).
  /// Returns mean delta, 95% confidence interval [lower, upper], margin of error, and p-value.
  static BootstrapResult bootstrapPairedDifference({
    required List<double> candidateScores,
    required List<double> baselineScores,
    int iterations = 10000,
    double confidenceLevel = 0.95,
  }) {
    assert(candidateScores.length == baselineScores.length,
        'Candidate and baseline arrays must have identical length');
    final n = candidateScores.length;
    if (n == 0) {
      return BootstrapResult(meanDelta: 0, ciLower: 0, ciUpper: 0, marginOfError: 0, pValue: 1.0);
    }

    final diffs = List.generate(n, (i) => candidateScores[i] - baselineScores[i]);
    final observedMeanDelta = diffs.reduce((a, b) => a + b) / n;

    final bootstrapMeans = <double>[];
    for (int iter = 0; iter < iterations; iter++) {
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        final randomIndex = _random.nextInt(n);
        sum += diffs[randomIndex];
      }
      bootstrapMeans.add(sum / n);
    }

    bootstrapMeans.sort();

    final alpha = 1.0 - confidenceLevel;
    final lowerIndex = (alpha / 2 * iterations).floor().clamp(0, iterations - 1);
    final upperIndex = ((1.0 - alpha / 2) * iterations).floor().clamp(0, iterations - 1);

    final ciLower = bootstrapMeans[lowerIndex];
    final ciUpper = bootstrapMeans[upperIndex];
    final marginOfError = (ciUpper - ciLower) / 2.0;

    // Approximate two-tailed p-value: proportion of bootstrap iterations with sign opposite to observed
    int opposingCount = 0;
    if (observedMeanDelta > 0) {
      opposingCount = bootstrapMeans.where((m) => m <= 0).length;
    } else if (observedMeanDelta < 0) {
      opposingCount = bootstrapMeans.where((m) => m >= 0).length;
    } else {
      opposingCount = iterations ~/ 2;
    }
    final pValue = (2.0 * opposingCount / iterations).clamp(0.0001, 1.0);

    return BootstrapResult(
      meanDelta: observedMeanDelta,
      ciLower: ciLower,
      ciUpper: ciUpper,
      marginOfError: marginOfError,
      pValue: pValue,
    );
  }

  /// McNemar's test for paired binary outcomes (e.g. Pass/Fail test cases).
  /// Checks if model B's success rate is significantly different from model A.
  /// Contigency table:
  /// b = Cases where A passed and B failed (Discordant pair 1)
  /// c = Cases where A failed and B passed (Discordant pair 2)
  static McNemarResult mcNemarTest({
    required List<bool> modelAPasses,
    required List<bool> modelBPasses,
  }) {
    assert(modelAPasses.length == modelBPasses.length);
    int aOnly = 0; // Model A passed, Model B failed
    int bOnly = 0; // Model B passed, Model A failed

    for (int i = 0; i < modelAPasses.length; i++) {
      final a = modelAPasses[i];
      final b = modelBPasses[i];
      if (a && !b) aOnly++;
      if (!a && b) bOnly++;
    }

    final discordantTotal = aOnly + bOnly;
    if (discordantTotal == 0) {
      return McNemarResult(
        chiSquare: 0.0,
        pValue: 1.0,
        bWins: 0,
        aWins: 0,
        isSignificant: false,
      );
    }

    // Edwards continuity correction: (|b - c| - 1)^2 / (b + c)
    final diff = (bOnly - aOnly).abs();
    final numerator = pow(max(0, diff - 1), 2).toDouble();
    final chiSquare = numerator / discordantTotal;

    // Chi-Square with 1 degree of freedom p-value approximation
    final pValue = _chiSquarePValue1Df(chiSquare);

    return McNemarResult(
      chiSquare: chiSquare,
      pValue: pValue,
      bWins: bOnly,
      aWins: aOnly,
      isSignificant: pValue < 0.05,
    );
  }

  /// Calculates Cohen's Kappa for inter-rater agreement (e.g. LLM Judge vs Human Ground Truth).
  /// Supports binary or categorical labels.
  static double cohensKappa(List<String> raterA, List<String> raterB) {
    assert(raterA.length == raterB.length && raterA.isNotEmpty);
    final n = raterA.length;
    final categories = <String>{...raterA, ...raterB}.toList();

    // Observed agreement
    int agreed = 0;
    final countA = <String, int>{};
    final countB = <String, int>{};
    for (final c in categories) {
      countA[c] = 0;
      countB[c] = 0;
    }

    for (int i = 0; i < n; i++) {
      if (raterA[i] == raterB[i]) agreed++;
      countA[raterA[i]] = (countA[raterA[i]] ?? 0) + 1;
      countB[raterB[i]] = (countB[raterB[i]] ?? 0) + 1;
    }

    final po = agreed / n;

    // Chance agreement
    double pe = 0.0;
    for (final c in categories) {
      final pA = (countA[c] ?? 0) / n;
      final pB = (countB[c] ?? 0) / n;
      pe += pA * pB;
    }

    if ((1.0 - pe).abs() < 1e-9) return 1.0;
    return (po - pe) / (1.0 - pe);
  }

  /// Calculates Pearson correlation coefficient between two continuous score lists.
  static double pearsonCorrelation(List<double> x, List<double> y) {
    assert(x.length == y.length && x.isNotEmpty);
    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;

    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;

    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }

    if (denX == 0 || denY == 0) return 0.0;
    return num / (sqrt(denX) * sqrt(denY));
  }

  /// Calculates Cohen's d effect size for paired samples.
  static double cohensD(List<double> candidate, List<double> baseline) {
    assert(candidate.length == baseline.length && candidate.isNotEmpty);
    final n = candidate.length;
    final diffs = List.generate(n, (i) => candidate[i] - baseline[i]);
    final meanDiff = diffs.reduce((a, b) => a + b) / n;

    final variance = diffs.map((d) => pow(d - meanDiff, 2)).reduce((a, b) => a + b) / (n - 1);
    final s = sqrt(variance);
    if (s == 0) return 0.0;
    return meanDiff / s;
  }

  /// Power analysis / sample size calculator.
  /// Computes minimum samples required to detect a difference delta with power 80% and alpha 0.05.
  static int requiredSampleSize({
    required double minimumDetectableDelta,
    double standardDeviation = 0.25,
    double alpha = 0.05,
    double power = 0.80,
  }) {
    // Two-tailed Z_alpha/2 = 1.96 for alpha=0.05, Z_beta = 0.84 for power=80%
    const zAlpha = 1.96;
    const zBeta = 0.8416;
    final delta = minimumDetectableDelta.abs();
    if (delta == 0) return 10000;
    final n = (pow(zAlpha + zBeta, 2) * 2 * pow(standardDeviation, 2)) / pow(delta, 2);
    return max(10, n.ceil());
  }

  static double _chiSquarePValue1Df(double x) {
    if (x <= 0) return 1.0;
    // P(Chi2 > x) = 2 * (1 - Phi(sqrt(x)))
    final z = sqrt(x);
    final p = 2.0 * (1.0 - _normalCdf(z));
    return p.clamp(0.00001, 1.0);
  }

  static double _normalCdf(double z) {
    // Approximation of standard normal CDF
    final t = 1.0 / (1.0 + 0.2316419 * z.abs());
    final d = 0.3989422804014327 * exp(-z * z / 2.0);
    final prob = d * t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
    return z > 0 ? 1.0 - prob : prob;
  }
}

class BootstrapResult {
  final double meanDelta;
  final double ciLower;
  final double ciUpper;
  final double marginOfError;
  final double pValue;

  BootstrapResult({
    required this.meanDelta,
    required this.ciLower,
    required this.ciUpper,
    required this.marginOfError,
    required this.pValue,
  });

  String formatPercentage() {
    final pctDelta = (meanDelta * 100).toStringAsFixed(1);
    final pctMoE = (marginOfError * 100).toStringAsFixed(1);
    final pStr = pValue < 0.001 ? 'p<0.001' : 'p=${pValue.toStringAsFixed(3)}';
    final sign = meanDelta >= 0 ? '+' : '';
    return '$sign$pctDelta% ± $pctMoE% ($pStr)';
  }

  Map<String, dynamic> toJson() => {
        'mean_delta': meanDelta,
        'ci_lower': ciLower,
        'ci_upper': ciUpper,
        'margin_of_error': marginOfError,
        'p_value': pValue,
        'formatted': formatPercentage(),
      };
}

class McNemarResult {
  final double chiSquare;
  final double pValue;
  final int bWins;
  final int aWins;
  final bool isSignificant;

  McNemarResult({
    required this.chiSquare,
    required this.pValue,
    required this.bWins,
    required this.aWins,
    required this.isSignificant,
  });

  Map<String, dynamic> toJson() => {
        'chi_square': chiSquare,
        'p_value': pValue,
        'b_wins': bWins,
        'a_wins': aWins,
        'is_significant': isSignificant,
      };
}
