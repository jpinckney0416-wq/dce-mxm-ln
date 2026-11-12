# PrEP DCE Design Report — Three-Attribute Mathematical Demo

**Label:** Unrestricted mathematical / illustrative design. **Not** a clinically validated patient survey.
**Seed:** `20251112`. **No patient data, findings, or preference weights.**

## 1. How the 10 choice sets were selected

Candidate profiles were the full factorial of 2×3×2 = 12 unrestricted profiles (administration × frequency × cost), coded with dummy (treatment) coding and reference levels Oral / Daily / $0 (4 main-effect parameters).

An efficient design with 10 choice sets × 2 alternatives was generated using `idefix::Modfed` (modified Fedorov / coordinate-exchange style swap search) minimizing the **local D-error** under a **zero prior** (`par.draws = 0` for all 4 parameters). Search used n.start = 48 random starts, max.iter = 200, parallel = FALSE, optim = "D". Among starts, the pipeline **prefers the lowest DB-error design with zero duplicate/reversed choice sets** when available (hygiene over a marginally lower D-error with repeated sets). **This is not a claim of global optimality** across all algorithms, priors, or constrained candidate sets.

Selection note: Selected des3 among 7 duplicate-free starts (DB.error=0.537285); raw Modfed BestDesign DB.error=0.531830 had duplicates.

Selected design summary: DB.error = 0.537285; AB.error = 0.645833; Orthogonality = 0.894427; infinite-error draws = 0%.

## 2. Clinical plausibility and confounding

Administration method and medication frequency **cannot vary independently** while remaining clinically plausible with current PrEP products:

| Administration | Frequency | Plausible? | Rationale |
|---|---|---|---|
| Oral | Daily | Yes | Standard oral PrEP (e.g., TDF/FTC, TAF/FTC) |
| Oral | Monthly | No / problematic | No standard monthly oral HIV PrEP regimen as a labeled product schedule |
| Oral | Every 6 months | No | Oral pills are not dosed every 6 months |
| Injection | Daily | No | Injectables are not administered daily |
| Injection | Monthly | Yes | Cabotegravir-like long-acting injectable |
| Injection | Every 6 months | Yes | Lenacapavir-like twice-yearly injectable |

Of 12 unrestricted profiles, 6 are clinically plausible (cost varies freely). In the generated unrestricted design, 10 of 20 alternatives are clinically implausible; 7 of 10 sets contain at least one implausible alternative. These combinations were **not** manufactured as recommended survey content; they appear because the demo uses an unrestricted candidate set to illustrate design mathematics.

### Constrained-design identifiability

If only clinically plausible profiles are allowed, administration and frequency travel together as **regimens** (Oral+Daily; Injection+Monthly; Injection+Every 6 months). Separate main effects for administration and frequency are then **not independently estimable** from choice data: contrasts that would isolate admin from frequency require implausible cells.

### Proposed combined attribute (not silently adopted)

For a patient-facing instrument, **propose** replacing separate administration + frequency with a single **PrEP regimen** attribute, e.g.:

1. Oral, daily
2. Injectable, monthly (cabotegravir-like)
3. Injectable, every 6 months (lenacapavir-like)

plus cost ($0, $30) or a richer insurance/reimbursement attribute from the protocol.

**What is no longer separately estimable:** the independent main effects of administration method vs medication frequency (and their interaction as separable constructs). 
What remains estimable: relative preferences among clinically real regimens, and cost (or insurance) effects conditional on regimen.

**Decision needed (PI / clinical / statistician):** adopt combined regimen attribute vs keep separate attributes with explicit constraints and accept confounding.

## 3. Are effects independently estimable in this unrestricted demo?

Under the unrestricted dummy-coded main-effects model, the within-choice-set difference matrix D is 10×4 with rank **4**. 
Main effects are mathematically estimable in this demo: rank(D) >= 4 (`TRUE`). 
**Caveat:** estimability here is algebraic under unrestricted profiles; it does **not** imply clinical validity or that the same parameters remain identifiable after imposing clinical constraints.

## 4. Remaining confounding / correlations

Correlations among within-set attribute differences (clogit-relevant): admin_Injection vs freq_Monthly: 0.055; admin_Injection vs freq_Every6mo: 0.047; freq_Monthly vs freq_Every6mo: -0.674; admin_Injection vs cost_30: 0.250; freq_Monthly vs cost_30: -0.055; freq_Every6mo vs cost_30: -0.047.

Even when rank is full, nonzero correlations among difference columns imply partial confounding / shared information across attributes; precision will be uneven. Under clinical constraints these correlations become structural (admin↔frequency).

## 5. Level balance (20 alternatives)

- Administration: Oral=10, Injection=10
- Frequency: Daily=6, Monthly=6, Every 6 months=8
- Cost: $0=10, $30=10

## 6. Design hygiene checks

- Identical alternatives within a set: **0**
- Duplicate or reversed choice sets: **0**
- Dominated sets under stated illustrative prefs (Oral>Injection; Daily>Monthly>Every 6 months; $0>$30): **3** — these prefs are QC assumptions only, **not** patient results
- Clinically implausible alternatives: **10** / 20

## 7. Comparison vs random design

A random 10×2 design was drawn from the same unrestricted candidate set (seed 20251112+1) and evaluated under the same zero prior.
- Modfed DB.error: **0.537285**
- Random DB.error: **0.978721**
Modfed achieved a lower DB-error than this random draw under identical assumptions (better by this criterion).

This comparison is valid only as a same-assumption check; it is not a proof of optimality.

## 8. Decisions still needed before a real patient survey

1. PI/clinical lock on attribute list (protocol candidates vs demo stand-ins).
2. Adopt **combined PrEP regimen** attribute vs constrained separate admin/frequency (statistician review of estimability).
3. Replace illustrative cost with protocol insurance/reimbursement levels as appropriate.
4. Priors: keep zero-prior D-efficiency vs Bayesian D-efficiency with informed priors from mixed methods / literature.
5. Dominance and implausible-profile rules for the patient-facing instrument.
6. eIRB amendment after mixed methods before any patient administration.
7. REDCap implementation, consent language, and pilot testing.

## 9. Outputs

- `outputs/prep_dce_design.csv`
- `outputs/prep_dce_survey.html`
- `outputs/prep_dce_diagnostics.csv`
- `outputs/designs/prep_dce_design_objects.rds`
- `docs/design_report.md` (this file)

## 10. Limitations

- Unrestricted design includes clinically invalid PrEP combinations.
- Zero prior ignores likely preference directionality.
- Main-effects-only; no interactions modeled.
- Local D-efficiency search with finite random starts — not a global optimum guarantee.
- Dominance check uses researcher-stated illustrative preferences, not data.
- No patient responses analyzed; none exist in this repository.
