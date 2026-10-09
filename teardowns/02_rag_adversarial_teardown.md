# 🔬 Deep-Dive Methodology 02: Adversarial RAG & Confident Abstention
**Author:** AI Evals Engineering Team
**Benchmark Target:** Retrieval-Augmented Generation (RAG) Robustness
**Status:** Public Specification & Reproducible Benchmark

---

## 1. The Core Hazard: The Confident Ungrounded Lie
In enterprise knowledge retrieval, the primary risk of RAG is not failing to find an answer; it is generating a **confident, plausible-sounding hallucination** when retrieved context is incomplete, contradictory, or absent.

Uncalibrated systems score high on standard benchmarks because tests only measure answerable questions. Our adversarial harness subjects RAG pipelines to a strict **Two-Gate Verification**.

---

## 2. Two-Gate Architecture
```
User Query + Corpus
        │
        ▼
┌─────────────────────────────────┐
│ GATE 1: Retrieval Evaluation    │
│ • Hit Rate@k, MRR, NDCG         │
└─────────────────────────────────┘
        │ Context Chunks
        ▼
┌─────────────────────────────────┐
│ GATE 2: Generation Evaluation   │
│ • Faithfulness (Entailment)     │
│ • Citation Precision            │
│ • Abstention Accuracy           │
└─────────────────────────────────┘
```

---

## 3. Adversarial Stress Injection Taxonomy
Our benchmark injects three classes of synthetic perturbations:
1. **Distractor Noise Injection:** Appending 3-5 semantically similar but factually irrelevant documents to the prompt context.
2. **Contradictory Context Injection:** Injecting document pairs where Doc A states fact \( X \) and Doc B states \( \neg X \).
3. **Negative Queries (Unanswerable Tests):** Questions designed around terms present in the context, but whose exact predicate cannot be logically derived from the text.

### Abstention Quality Objective
For unanswerable set \( U \):
\[ \text{Abstention Accuracy} = \frac{1}{|U|} \sum_{q \in U} \mathbb{I}\left[ \text{Model abstained with grounded declaration} \right] \]
Any factual claim emitted on set \( U \) receives a score of 0.0 with a **CRITICAL_HALLUCINATION** penalty.
