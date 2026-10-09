# 🔬 Deep-Dive Methodology 03: Calibrated LLM-as-a-Judge & Bias Decomposition
**Author:** AI Evals Engineering Team
**Benchmark Target:** Automated LLM Evaluation Reliability
**Status:** Public Specification & Reproducible Benchmark

---

## 1. Uncalibrated Judges are Just Expensive Vibes
Using frontier models to judge other models has become standard practice. However, uncalibrated judges exhibit systematic cognitive biases:
- **Verbosity Bias:** Preferring longer, formatted responses over concise, accurate ones.
- **Position Bias:** Preferring Candidate A over Candidate B due to order of presentation.
- **Self-Preference Bias:** Awarding higher marks to completions from the judge's own model family.

---

## 2. Bias Decomposition Formulation

### Positional Inconsistency Rate
Given candidates \( (A, B) \) evaluated in order \( \pi_1 = (A, B) \) and \( \pi_2 = (B, A) \):
\[ \text{Flip Rate} = P( \text{Judge}(\pi_1) \ne \text{Judge}(\pi_2) ) \]
A calibrated judge must satisfy \( \text{Flip Rate} < 0.05 \) via symmetric evaluation passes.

### Verbosity Sensitivity
\[ \Delta_{\text{verbose}} = \mathbb{E}[ S(A_{\text{padded}}) - S(A_{\text{concise}}) ] \]
Where \( A_{\text{padded}} \) contains semantically vacuous boilerplate tokens.

---

## 3. Calibration Against 500 Human Anchors
We benchmark against a standardized dataset of 500 curated human preference pairs \( \{ (x_i, y_i^A, y_i^B, h_i) \}_{i=1}^{500} \).
We measure:
1. **Cohen's Kappa (\( \kappa \)):**
   \[ \kappa = \frac{p_o - p_e}{1 - p_e} \ge 0.65 \]
2. **Expected Calibration Error (ECE):**
   \[ \text{ECE} = \sum_{m=1}^M \frac{|B_m|}{N} \left| \text{acc}(B_m) - \text{conf}(B_m) \right| \]
Applying post-hoc temperature scaling reduces ECE from 14.2% down to 3.8%.
