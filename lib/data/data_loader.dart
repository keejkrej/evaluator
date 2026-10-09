import 'dart:convert';
import 'dart:io';
import '../core/models/models.dart';

class DataLoader {
  /// Loads a list of Trajectories from a JSONL file
  static List<Trajectory> loadTrajectoriesFromJsonl(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    final lines = file.readAsLinesSync();
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => Trajectory.fromJson(jsonDecode(l) as Map<String, dynamic>))
        .toList();
  }

  /// Saves a list of Trajectories to a JSONL file
  static void saveTrajectoriesToJsonl(String filePath, List<Trajectory> trajectories) {
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      trajectories.map((t) => jsonEncode(t.toJson())).join('\n') + '\n',
    );
  }

  /// Loads RAG test cases from JSONL
  static List<RAGTestCase> loadRAGCasesFromJsonl(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    return file
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .map((l) => RAGTestCase.fromJson(jsonDecode(l) as Map<String, dynamic>))
        .toList();
  }

  /// Loads Human Anchors for Judge Calibration from JSONL
  static List<HumanAnchor> loadHumanAnchorsFromJsonl(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    return file
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .map((l) => HumanAnchor.fromJson(jsonDecode(l) as Map<String, dynamic>))
        .toList();
  }

  /// Loads DPO pairs from JSONL
  static List<DPOPair> loadDPOPairsFromJsonl(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    return file
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .map((l) => DPOPair.fromJson(jsonDecode(l) as Map<String, dynamic>))
        .toList();
  }

  /// Saves DPO pairs to JSONL
  static void saveDPOPairsToJsonl(String filePath, List<DPOPair> pairs) {
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      pairs.map((p) => jsonEncode(p.toJson())).join('\n') + '\n',
    );
  }
}
