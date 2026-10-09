import 'dart:io';

class RoutingCandidate {
  final String id;
  final String name;
  final String routingType; // 'System-1 (Flash)', 'Hybrid Dynamic', 'System-2 (Frontier)'
  final double costPer1kRequests; // in USD
  final double taskSuccessRate; // 0.0 to 1.0
  final int latencyP50Ms;
  final int latencyP95Ms;
  final bool isParetoOptimal;
  final String tenant;

  const RoutingCandidate({
    required this.id,
    required this.name,
    required this.routingType,
    required this.costPer1kRequests,
    required this.taskSuccessRate,
    required this.latencyP50Ms,
    required this.latencyP95Ms,
    this.isParetoOptimal = false,
    this.tenant = 'enterprise_default',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'routing_type': routingType,
        'cost_per_1k': costPer1kRequests,
        'success_rate': taskSuccessRate,
        'latency_p50': latencyP50Ms,
        'latency_p95': latencyP95Ms,
        'is_pareto_optimal': isParetoOptimal,
        'tenant': tenant,
      };
}

class CostQualityParetoDashboard {
  /// Computes the Pareto frontier from a list of candidate strategies
  /// A candidate is Pareto-optimal if no other candidate has BOTH lower cost AND higher success rate.
  static List<RoutingCandidate> computeParetoFrontier(List<RoutingCandidate> candidates) {
    final results = <RoutingCandidate>[];

    for (int i = 0; i < candidates.length; i++) {
      final c1 = candidates[i];
      bool isDominated = false;

      for (int j = 0; j < candidates.length; j++) {
        if (i == j) continue;
        final c2 = candidates[j];
        // c2 dominates c1 if c2 has <= cost AND >= success, with at least one strictly better
        if (c2.costPer1kRequests <= c1.costPer1kRequests &&
            c2.taskSuccessRate >= c1.taskSuccessRate &&
            (c2.costPer1kRequests < c1.costPer1kRequests || c2.taskSuccessRate > c1.taskSuccessRate)) {
          isDominated = true;
          break;
        }
      }

      results.add(RoutingCandidate(
        id: c1.id,
        name: c1.name,
        routingType: c1.routingType,
        costPer1kRequests: c1.costPer1kRequests,
        taskSuccessRate: c1.taskSuccessRate,
        latencyP50Ms: c1.latencyP50Ms,
        latencyP95Ms: c1.latencyP95Ms,
        isParetoOptimal: !isDominated,
        tenant: c1.tenant,
      ));
    }

    return results;
  }

  /// Generates sample multi-tier benchmark candidates
  static List<RoutingCandidate> getSampleCandidatePool() {
    return [
      const RoutingCandidate(
        id: 'cfg_sys1_flash',
        name: 'GLM-5.3-Flash Pure',
        routingType: 'System-1 (Flash)',
        costPer1kRequests: 0.12,
        taskSuccessRate: 0.912,
        latencyP50Ms: 140,
        latencyP95Ms: 290,
      ),
      const RoutingCandidate(
        id: 'cfg_hybrid_dynamic',
        name: 'Dynamic Triage + GLM Escalation',
        routingType: 'Hybrid Dynamic',
        costPer1kRequests: 0.45,
        taskSuccessRate: 0.968,
        latencyP50Ms: 220,
        latencyP95Ms: 540,
      ),
      const RoutingCandidate(
        id: 'cfg_sys2_frontier',
        name: 'Frontier System-2 Multi-Step Loop',
        routingType: 'System-2 (Frontier)',
        costPer1kRequests: 3.20,
        taskSuccessRate: 0.975,
        latencyP50Ms: 1800,
        latencyP95Ms: 4200,
      ),
      const RoutingCandidate(
        id: 'cfg_legacy_inefficient',
        name: 'Legacy Unoptimized Agent',
        routingType: 'System-2 (Frontier)',
        costPer1kRequests: 4.80,
        taskSuccessRate: 0.890, // Sub-optimal & high cost
        latencyP50Ms: 2400,
        latencyP95Ms: 5800,
      ),
    ];
  }

  /// Exports an interactive HTML / SVG visualizer dashboard
  static String generateHtmlVisualizer(List<RoutingCandidate> candidates, {String? outputPath}) {
    final frontier = computeParetoFrontier(candidates);

    final html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Cost-Quality Pareto Frontier Dashboard</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0d1117; color: #c9d1d9; margin: 0; padding: 24px; }
    .container { max-width: 1000px; margin: 0 auto; }
    h1 { color: #58a6ff; margin-bottom: 8px; }
    p.subtitle { color: #8b949e; margin-bottom: 24px; }
    .card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; margin-bottom: 24px; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th, td { text-align: left; padding: 12px 14px; border-bottom: 1px solid #21262d; font-size: 14px; }
    th { color: #8b949e; text-transform: uppercase; font-size: 12px; letter-spacing: 0.5px; }
    .badge { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 12px; font-weight: 600; }
    .badge-pareto { background: #238636; color: #ffffff; }
    .badge-dominated { background: #484f58; color: #8b949e; }
    svg { width: 100%; height: 320px; background: #0d1117; border-radius: 6px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>📈 Cost-Quality Pareto Frontier Dashboard</h1>
    <p class="subtitle">Empirical unit economics mapping System-1 vs System-2 routing tradeoffs.</p>

    <div class="card">
      <h3>Pareto Optimization Curve</h3>
      <svg viewBox="0 0 800 300">
        <!-- Axes -->
        <line x1="60" y1="260" x2="760" y2="260" stroke="#30363d" stroke-width="2"/>
        <line x1="60" y1="30" x2="60" y2="260" stroke="#30363d" stroke-width="2"/>
        <text x="400" y="290" fill="#8b949e" font-size="12" text-anchor="middle">Inference Cost (\$ per 1,000 requests)</text>
        <text x="20" y="145" fill="#8b949e" font-size="12" text-anchor="middle" transform="rotate(-90 20 145)">Task Success Rate (%)</text>

        <!-- Points -->
        <circle cx="150" cy="110" r="8" fill="#2ea043" />
        <text x="150" y="95" fill="#58a6ff" font-size="11" text-anchor="middle">GLM-5.3-Flash (91.2% @ \$0.12)</text>

        <circle cx="320" cy="60" r="8" fill="#2ea043" />
        <text x="320" y="45" fill="#2ea043" font-size="11" text-anchor="middle">Dynamic Hybrid (96.8% @ \$0.45)</text>

        <circle cx="680" cy="48" r="8" fill="#2ea043" />
        <text x="680" y="35" fill="#f0883e" font-size="11" text-anchor="middle">Frontier System-2 (97.5% @ \$3.20)</text>

        <circle cx="730" cy="140" r="7" fill="#da3633" />
        <text x="730" y="160" fill="#8b949e" font-size="11" text-anchor="middle">Dominated Legacy (89.0% @ \$4.80)</text>

        <!-- Pareto Line -->
        <polyline points="150,110 320,60 680,48" fill="none" stroke="#238636" stroke-width="2" stroke-dasharray="4"/>
      </svg>
    </div>

    <div class="card">
      <h3>Routing Candidate Evaluation Table</h3>
      <table>
        <thead>
          <tr>
            <th>Configuration</th>
            <th>Architecture Type</th>
            <th>Cost / 1k Reqs</th>
            <th>Success Rate</th>
            <th>P95 Latency</th>
            <th>Frontier Status</th>
          </tr>
        </thead>
        <tbody>
          ${frontier.map((c) => '''
          <tr>
            <td><strong>${c.name}</strong></td>
            <td>${c.routingType}</td>
            <td>\$${c.costPer1kRequests.toStringAsFixed(2)}</td>
            <td>${(c.taskSuccessRate * 100).toStringAsFixed(1)}%</td>
            <td>${c.latencyP95Ms} ms</td>
            <td><span class="badge ${c.isParetoOptimal ? 'badge-pareto' : 'badge-dominated'}">${c.isParetoOptimal ? 'PARETO OPTIMAL' : 'DOMINATED'}</span></td>
          </tr>
          ''').join('')}
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>''';

    if (outputPath != null) {
      File(outputPath).writeAsStringSync(html);
    }
    return html;
  }
}
