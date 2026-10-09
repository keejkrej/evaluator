# 📐 AI Evals Engineering Suite in Dart

> A complete, production-grade implementation of the **15 AI Evals Engineer Projects** and **12-Stage Evaluation Roadmap**, written in **Dart** with first-class support for **GLM-5.3-Flash** via Ollama Cloud / API.

---

## 🚀 Overview

Vibe-checking is dead. Uncalibrated judges are just expensive vibes; calibrated judges are scientific instruments. The trajectory is the unit of accountability when agents touch your stack.

This repository implements all 15 industry-standard evaluation systems requested by modern AI Evals Engineers:

| # | System | Purpose & Why | CLI Subcommand |
|---|---|---|---|
| **1** | **Trajectory Grading Engine** | Scores agent tool calls against a deterministic DAG state machine. Fails runs on hallucinated API parameters or skipped safety checks. | `evaluator trajectory` |
| **2** | **Shadow Routing Comparator** | Proxies and mirrors 5% of production traffic to GLM-5.3-Flash, diffs trajectories, and auto-generates cost/quality reports without affecting users. | `evaluator shadow` |
| **3** | **Calibrated LLM-as-a-Judge** | Measures judge verbosity, position, and self-preference biases against 500 human-labeled anchors, applying temperature scaling to reduce ECE. | `evaluator judge` |
| **4** | **CI/CD Regression Gate** | GitHub Action gate running parameterized evals on PRs, blocking merges if task success drops >2% or P95 latency spikes >15%. | `evaluator gate` |
| **5** | **RAG Adversarial Harness** | Two-gate evaluation (Retrieval & Generation) injecting distractor noise and contradictory docs to enforce confident abstention on unanswerable queries. | `evaluator rag` |
| **6** | **Automated DPO Flywheel** | Captures user thumbs-down events, auto-formats them into clean `{prompt, chosen, rejected}` preference pairs, and generates nightly LoRA scripts. | `evaluator dpo` |
| **7** | **Statistical Significance Engine** | 10,000-iteration bootstrap resampling producing `"Model B wins by 3.2% ± 1.1% (p<0.05)"` with McNemar's test and power analysis. | `evaluator stats` |
| **8** | **Agent Red-Team Fuzzer** | Injects prompt injections, malformed tool schemas, infinite loop traps, and unauthorized privilege escalation into agent interfaces. | `evaluator redteam` |
| **9** | **Production Drift Monitor** | Nightly sampling daemon pulling 5% of live traffic, calculating Z-score anomaly spikes, action frequency drift, and alerting before users complain. | `evaluator drift` |
| **10** | **Cost-Quality Pareto Dashboard** | Maps inference cost vs task success tradeoffs for System-1 (GLM-5.3-Flash) vs System-2 routing with an interactive HTML/SVG visualizer. | `evaluator pareto` |
| **11** | **Counterfactual Replay Debugger** | Records LLM hops and tool outputs, surgically replaces node $k$, and replays the trajectory to pinpoint the causal bifurcation step. | `evaluator replay` |
| **12** | **Synthetic Edge-Case Generator** | Uses GLM-5.3-Flash to systematically generate out-of-distribution (OOD) inputs, boundary conditions, and conflicting instructions. | `evaluator synthetic` |
| **13** | **Context Window Eviction Tester** | Floods working memory with noise up to token thresholds, testing needle retrieval across depths (10% to 90%), compression retention, and eviction. | `evaluator eviction` |
| **14** | **Dataset Contamination Checker** | N-gram (8-gram/13-gram) and Jaccard similarity scanner detecting data leaks between golden eval sets and training/fine-tuning corpora. | `evaluator contamination` |
| **15** | **Public Eval Methodology Teardowns** | 3 published deep-dive specifications detailing exact grading rubrics, judge prompts, and statistical frameworks. | `evaluator teardown` |

---

## 🏗️ Architecture

```
evaluator/
├── bin/
│   └── evaluator.dart                 # CLI entry point (all 15 subcommands)
├── lib/
│   ├── evaluator.dart                 # Top-level library export
│   ├── core/
│   │   ├── client/                    # Ollama client supporting GLM-5.3-Flash
│   │   ├── dag/                       # Deterministic DAG state machine
│   │   ├── models/                    # Data models: Trajectory, Steps, RAG, DPO, Anchors
│   │   └── statistics/                # 10k Bootstrap CI, McNemar, Cohen's Kappa, Pearson
│   ├── data/                          # Dataset loader & downloader (SQuAD 2.0, BFCL)
│   └── modules/                       # Modules for Projects 1 through 15
├── data/                              # Pre-bundled golden datasets & human anchors
├── test/                              # Comprehensive unit & integration test suite
└── teardowns/                         # 3 Publication-ready methodology teardowns
```

---

## ⚡ Quick Start

### 1. Requirements
- Dart SDK $\ge$ 3.0 (Tested on Dart 3.13.5 macOS arm64 / Linux)
- Ollama running locally or reachable at `http://127.0.0.1:11434` with `glm-5.3-flash:cloud`
- Environment variable `OLLAMA_API_KEY` (automatically picked up)

### 2. Run All 15 Systems End-to-End
```bash
# Run unit test suite
dart test

# Run all 15 AI evaluation engines in sequence
dart run bin/evaluator.dart all
```

Or run the bundled demo script:
```bash
./examples/run_all_evals.sh
```

---

## 🔍 Data Sourcing & Synthetic Generation

### 1. Downloading Open Benchmark Data
The CLI includes automated dataset downloaders:
```bash
# Download real SQuAD 2.0 validation data (answerable & unanswerable abstention tests)
dart run bin/evaluator.dart dataset --source=squad2
```

### 2. Generating Synthetic Evaluation Data for Agentic Products
If you are developing an agentic product (such as Devin, Claude Code, Cursor, or ChatGPT):
1. **Production Logging / Traces:**
   Extract session transcripts into `Trajectory` JSONL format. Each step captures:
   ```json
   {
     "step_index": 1,
     "thought": "Looking up user transaction...",
     "tool_call": {
       "name": "lookup_transaction",
       "arguments": {"transaction_id": "tx_9921"}
     },
     "tool_result": {"status": "success"},
     "latency_ms": 140
   }
   ```
2. **Frontier Model Synthesis:**
   Use the `synthetic` subcommand to prompt GLM-5.3-Flash to generate boundary conditions and out-of-distribution adversarial cases:
   ```bash
   dart run bin/evaluator.dart synthetic
   ```

---

## 🛠️ Subcommand Usage Guide

### 1. Trajectory Grading Engine (Deterministic DAG)
```bash
dart run bin/evaluator.dart trajectory --dag=financial_refund
```
- Step-level inspection: Verifies tool state transitions.
- Catches hallucinated arguments (`HALLUCINATED_PARAMETER`).
- Catches skipped safety checks (`SKIPPED_SAFETY_CHECK`).

### 2. Shadow Routing Comparator
```bash
dart run bin/evaluator.dart shadow --rate=0.05
```
- Compares Primary Model vs Candidate Model (GLM-5.3-Flash).
- Computes trajectory alignment rate, P95 latency delta, and cost savings percentage.

### 3. Calibrated LLM-as-a-Judge
```bash
dart run bin/evaluator.dart judge
```
- Calibrates against 500 human-labeled anchor pairs in `data/judge_anchors/500_human_anchors.jsonl`.
- Measures Cohen's Kappa ($\kappa$), Pearson Correlation ($r$), Verbosity Bias ($\Delta_{verbose}$), and Positional Flip Rate.

### 4. CI/CD Regression Gate
```bash
dart run bin/evaluator.dart gate
```
- Blocks pull requests if task success drops $> 2.0\%$ or P95 latency spikes $> 15.0\%$.
- Outputs GitHub Markdown PR comments with regressed test cases.

### 5. RAG Adversarial Harness
```bash
dart run bin/evaluator.dart rag
```
- Evaluates Gate 1 (Retrieval: Hit Rate, MRR, NDCG) and Gate 2 (Generation: Faithfulness, Citation Precision).
- Evaluates Gate 3: Confident abstention on unanswerable questions.

### 6. Automated DPO Flywheel
```bash
dart run bin/evaluator.dart dpo
```
- Converts production thumbs-down signals into DPO pairs.
- Generates `data/dpo_feedback/train_nightly_lora.sh` fine-tuning script.

### 7. Statistical Significance Engine
```bash
dart run bin/evaluator.dart stats
```
- Runs 10,000 bootstrap iterations to output:
  `"Model B wins by 7.0% ± 10.0% (p<0.05)"`
- Runs McNemar's test for paired binary pass/fail comparisons.

### 8. Agent Red-Team Fuzzer
```bash
dart run bin/evaluator.dart redteam
```
- Executes direct & indirect prompt injections, oversized schema fuzzing, and loop traps against agent guardrails.

### 9. Production Drift Monitor
```bash
dart run bin/evaluator.dart drift
```
- Evaluates live production traffic against rolling baseline.
- Uses Z-score anomaly detection to alert on failure rate spikes.

### 10. Cost-Quality Pareto Dashboard
```bash
dart run bin/evaluator.dart pareto --out=pareto_dashboard.html
```
- Generates an interactive HTML/SVG visualization mapping the Pareto frontier.
- Open `pareto_dashboard.html` in any browser to inspect the frontier.

### 11. Counterfactual Replay Debugger
```bash
dart run bin/evaluator.dart replay
```
- Mutates node $k$ in a failing 5-step trajectory.
- Replays remaining steps to isolate the causal root cause of failure.

### 12. Synthetic Edge-Case Generator
```bash
dart run bin/evaluator.dart synthetic
```
- Synthesizes frontier boundary conditions with GLM-5.3-Flash.

### 13. Context Window Eviction Tester
```bash
dart run bin/evaluator.dart eviction
```
- Floods agent context with noise up to token limits.
- Evaluates needle retrieval at 10%, 25%, 50%, 75%, and 90% depth.

### 14. Dataset Contamination Checker
```bash
dart run bin/evaluator.dart contamination
```
- Scans evaluation sets against pre-training corpora using 8-gram and Jaccard similarity.

### 15. Public Eval Methodology Teardowns
```bash
dart run bin/evaluator.dart teardown
```
- Exports 3 comprehensive methodology teardowns into `teardowns/`:
  1. `01_agent_trajectory_teardown.md`
  2. `02_rag_adversarial_teardown.md`
  3. `03_judge_calibration_teardown.md`

---

## 📊 Mathematical Rigor & Statistical Formulations

### 1. Bootstrap Confidence Intervals
Given paired differences $\Delta_i = y_i^{\text{candidate}} - y_i^{\text{baseline}}$, we resample $B = 10,000$ iterations with replacement:
$$\bar{\Delta}^*_b = \frac{1}{N} \sum_{i=1}^N \Delta^*_{b, i}$$
The $95\%$ empirical confidence interval is $[\bar{\Delta}^*_{\alpha/2}, \bar{\Delta}^*_{1 - \alpha/2}]$.

### 2. McNemar's Test for Paired Classifications
$$\chi^2 = \frac{(|b - c| - 1)^2}{b + c}$$
Where $b$ represents cases where Candidate passed and Baseline failed, and $c$ represents cases where Baseline passed and Candidate failed.

### 3. Cohen's Kappa for Judge Agreement
$$\kappa = \frac{p_o - p_e}{1 - p_e}$$
Where $p_o$ is observed agreement and $p_e$ is chance agreement.

---

## 📜 License
MIT License. Built for Builders.
