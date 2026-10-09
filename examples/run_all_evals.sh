#!/usr/bin/env bash
# Runner for all 15 AI Evals Engineering Projects in Dart
set -euo pipefail

echo "================================================================="
echo "   🚀 AI EVALS ENGINEERING: 15 PRODUCTION EVALUATION SYSTEMS"
echo "   Written in Dart | Powered by GLM-5.3-Flash via Ollama"
echo "================================================================="

# 1. Run Unit Tests
echo -e "\n[0/15] Running Test Suite..."
dart test

# 2. Run All 15 CLI Evaluation Engines
echo -e "\n[1-15/15] Running All 15 Evaluation Engines via CLI..."
dart run bin/evaluator.dart all

echo -e "\n✅ All 15 AI Evaluation Systems executed successfully!"
