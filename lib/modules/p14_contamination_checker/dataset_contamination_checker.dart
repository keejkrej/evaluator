import 'dart:math';

class ContaminationMatch {
  final String evalId;
  final String corpusId;
  final double jaccardSimilarity;
  final int sharedNGrams;
  final String matchingSpan;

  ContaminationMatch({
    required this.evalId,
    required this.corpusId,
    required this.jaccardSimilarity,
    required this.sharedNGrams,
    required this.matchingSpan,
  });

  Map<String, dynamic> toJson() => {
        'eval_id': evalId,
        'corpus_id': corpusId,
        'jaccard_similarity': jaccardSimilarity,
        'shared_n_grams': sharedNGrams,
        'matching_span': matchingSpan,
      };
}

class ContaminationReport {
  final int evalCasesScanned;
  final int corpusDocsScanned;
  final int contaminatedCasesCount;
  final double contaminationPercentage;
  final int nGramSize;
  final double jaccardThreshold;
  final String contaminationStatus;
  final List<ContaminationMatch> matches;

  ContaminationReport({
    required this.evalCasesScanned,
    required this.corpusDocsScanned,
    required this.contaminatedCasesCount,
    required this.contaminationPercentage,
    required this.nGramSize,
    required this.jaccardThreshold,
    required this.contaminationStatus,
    required this.matches,
  });

  Map<String, dynamic> toJson() => {
        'eval_cases_scanned': evalCasesScanned,
        'corpus_docs_scanned': corpusDocsScanned,
        'contaminated_cases_count': contaminatedCasesCount,
        'contamination_percentage': contaminationPercentage,
        'ngram_size': nGramSize,
        'jaccard_threshold': jaccardThreshold,
        'status': contaminationStatus,
        'matches': matches.map((m) => m.toJson()).toList(),
      };

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# 🧪 Dataset Contamination Scanner Report');
    buf.writeln();
    buf.writeln('**Contamination Status:** `$contaminationStatus`');
    buf.writeln('**Contamination Rate:** `${(contaminationPercentage * 100).toStringAsFixed(2)}%` ($contaminatedCasesCount of $evalCasesScanned eval samples leaked into training data).');
    buf.writeln();
    buf.writeln('| Scanner Parameter | Value |');
    buf.writeln('|---|---|');
    buf.writeln('| **N-Gram Match Window** | $nGramSize-grams |');
    buf.writeln('| **Jaccard Leak Threshold** | $jaccardThreshold |');
    buf.writeln('| **Training Corpus Documents** | $corpusDocsScanned |');
    buf.writeln();
    if (matches.isNotEmpty) {
      buf.writeln('### 🚨 Leaked Spans Detected');
      for (final m in matches) {
        buf.writeln('#### Eval Sample `${m.evalId}` leaked into Training Doc `${m.corpusId}`');
        buf.writeln('- **Jaccard Similarity:** `${(m.jaccardSimilarity * 100).toStringAsFixed(1)}%` (${m.sharedNGrams} matching $nGramSize-grams)');
        buf.writeln('- **Matching Text Span:** `"${m.matchingSpan}"`');
        buf.writeln();
      }
    } else {
      buf.writeln('### ✅ Zero Contamination Found');
      buf.writeln('No golden evaluation samples or 8-gram sequences were detected in the training corpora.');
    }
    return buf.toString();
  }
}

class DatasetContaminationChecker {
  final int nGramSize;
  final double jaccardThreshold;

  DatasetContaminationChecker({
    this.nGramSize = 8,
    this.jaccardThreshold = 0.50,
  });

  /// Scans evaluation set against training corpora for contamination
  ContaminationReport scan({
    required List<Map<String, dynamic>> evalSet,
    required List<Map<String, dynamic>> trainingCorpus,
  }) {
    final matches = <ContaminationMatch>[];
    final contaminatedEvalIds = <String>{};

    for (final evalItem in evalSet) {
      final evalId = evalItem['id'] as String? ?? 'eval_item';
      final evalText = (evalItem['text'] ?? evalItem['query'] ?? '').toString();
      final evalNGrams = _extractNGrams(evalText, nGramSize);
      if (evalNGrams.isEmpty) continue;

      for (final trainItem in trainingCorpus) {
        final trainId = trainItem['id'] as String? ?? 'train_doc';
        final trainText = (trainItem['text'] ?? '').toString();
        final trainNGrams = _extractNGrams(trainText, nGramSize);
        if (trainNGrams.isEmpty) continue;

        // Calculate Jaccard similarity of n-grams
        final intersection = evalNGrams.intersection(trainNGrams);
        final union = evalNGrams.union(trainNGrams);
        final jaccard = union.isEmpty ? 0.0 : intersection.length / union.length;

        if (jaccard >= jaccardThreshold || intersection.length >= 3) {
          contaminatedEvalIds.add(evalId);
          final sampleSpan = intersection.isNotEmpty ? intersection.first : evalText;
          matches.add(ContaminationMatch(
            evalId: evalId,
            corpusId: trainId,
            jaccardSimilarity: jaccard,
            sharedNGrams: intersection.length,
            matchingSpan: sampleSpan,
          ));
          break;
        }
      }
    }

    final n = max(1, evalSet.length);
    final pct = contaminatedEvalIds.length / n;
    String status = 'CLEAN_VERIFIED';
    if (pct > 0.05) {
      status = 'CRITICAL_CONTAMINATION';
    } else if (pct > 0.0) {
      status = 'MODERATE_LEAK_DETECTED';
    }

    return ContaminationReport(
      evalCasesScanned: evalSet.length,
      corpusDocsScanned: trainingCorpus.length,
      contaminatedCasesCount: contaminatedEvalIds.length,
      contaminationPercentage: pct,
      nGramSize: nGramSize,
      jaccardThreshold: jaccardThreshold,
      contaminationStatus: status,
      matches: matches,
    );
  }

  Set<String> _extractNGrams(String text, int n) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < n) {
      return words.isEmpty ? <String>{} : {words.join(' ')};
    }
    final ngrams = <String>{};
    for (int i = 0; i <= words.length - n; i++) {
      ngrams.add(words.sublist(i, i + n).join(' '));
    }
    return ngrams;
  }
}
