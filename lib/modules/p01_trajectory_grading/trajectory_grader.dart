import '../../core/dag/deterministic_dag.dart';
import '../../core/models/models.dart';

class TrajectoryGrader {
  final Map<String, DeterministicDAG> registeredDags;

  TrajectoryGrader({Map<String, DeterministicDAG>? dags})
      : registeredDags = dags ?? {
          'financial_refund': DeterministicDAG.financialRefundDAG(),
          'database_migration': DeterministicDAG.databaseMigrationDAG(),
        };

  /// Grades a single trajectory against a specified DAG
  DAGValidationResult grade({
    required Trajectory trajectory,
    String? dagName,
    DeterministicDAG? customDag,
  }) {
    final dag = customDag ?? (dagName != null ? registeredDags[dagName] : registeredDags.values.first);
    if (dag == null) {
      throw ArgumentError('No DAG registered with name "$dagName"');
    }

    return dag.gradeTrajectory(trajectory);
  }

  /// Batch grades a list of trajectories and computes summary statistics
  TrajectoryBatchReport gradeBatch({
    required List<Trajectory> trajectories,
    String? dagName,
    DeterministicDAG? customDag,
  }) {
    final results = <String, DAGValidationResult>{};
    int passedCount = 0;
    int hallucinatedParamFailures = 0;
    int skippedSafetyCheckFailures = 0;
    int invalidTransitionFailures = 0;
    double totalDistance = 0.0;
    double totalCoverage = 0.0;

    for (final traj in trajectories) {
      final res = grade(trajectory: traj, dagName: dagName, customDag: customDag);
      results[traj.id] = res;
      if (res.passed) {
        passedCount++;
      } else {
        if (res.violatedRule == 'HALLUCINATED_PARAMETER') hallucinatedParamFailures++;
        if (res.violatedRule == 'SKIPPED_SAFETY_CHECK') skippedSafetyCheckFailures++;
        if (res.violatedRule == 'INVALID_TRANSITION') invalidTransitionFailures++;
      }
      totalDistance += res.trajectoryDistance;
      totalCoverage += res.stateCoverage;
    }

    final n = trajectories.isEmpty ? 1 : trajectories.length;
    return TrajectoryBatchReport(
      totalEvaluated: trajectories.length,
      passedCount: passedCount,
      failedCount: trajectories.length - passedCount,
      passRate: passedCount / n,
      hallucinatedParamCount: hallucinatedParamFailures,
      skippedSafetyCheckCount: skippedSafetyCheckFailures,
      invalidTransitionCount: invalidTransitionFailures,
      meanTrajectoryDistance: totalDistance / n,
      meanStateCoverage: totalCoverage / n,
      individualResults: results,
    );
  }
}

class TrajectoryBatchReport {
  final int totalEvaluated;
  final int passedCount;
  final int failedCount;
  final double passRate;
  final int hallucinatedParamCount;
  final int skippedSafetyCheckCount;
  final int invalidTransitionCount;
  final double meanTrajectoryDistance;
  final double meanStateCoverage;
  final Map<String, DAGValidationResult> individualResults;

  TrajectoryBatchReport({
    required this.totalEvaluated,
    required this.passedCount,
    required this.failedCount,
    required this.passRate,
    required this.hallucinatedParamCount,
    required this.skippedSafetyCheckCount,
    required this.invalidTransitionCount,
    required this.meanTrajectoryDistance,
    required this.meanStateCoverage,
    required this.individualResults,
  });

  Map<String, dynamic> toJson() => {
        'total_evaluated': totalEvaluated,
        'passed_count': passedCount,
        'failed_count': failedCount,
        'pass_rate': passRate,
        'hallucinated_param_count': hallucinatedParamCount,
        'skipped_safety_check_count': skippedSafetyCheckCount,
        'invalid_transition_count': invalidTransitionCount,
        'mean_trajectory_distance': meanTrajectoryDistance,
        'mean_state_coverage': meanStateCoverage,
        'individual_results': individualResults.map((k, v) => MapEntry(k, v.toJson())),
      };
}
