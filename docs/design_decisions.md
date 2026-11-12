# Design decisions log

Record date, decision, rationale, and owner. Flag items needing PI or statistician review before locking attributes or generating a patient-facing design.

| Date | Decision | Rationale | Owner | Status |
|------|----------|-----------|-------|--------|
| 2026-11-12 | Use three **illustrative** attributes (administration, frequency, cost) with `finalized=FALSE` | Demonstrates DCE pipeline; cost is a simplified stand-in for insurance/reimbursement; not protocol-final | Demo / coding agent | Open — needs PI lock |
| 2026-11-12 | Generate an **unrestricted mathematical design** (12-profile full factorial candidate set) labeled as demo-only | Shows D-efficient design principles and estimability under independent attributes; must **not** be presented as a clinically valid patient survey | Demo / coding agent | Adopted for demo only |
| 2026-11-12 | Document that admin × frequency are **not clinically independent** | Oral↔Daily; Injection↔Monthly or Every 6 months only; other cells invalid/problematic with current PrEP products | Clinical plausibility review | Flag for PI |
| 2026-11-12 | **Propose** (do not silently adopt) a combined **PrEP regimen** attribute for patient-facing work | Under clinical constraints, separate admin and frequency main effects are not independently estimable; combined regimen preserves clinically real alternatives | Statistician / PI decision needed | Proposed — not adopted in demo design matrix |
| 2026-11-12 | Zero-prior local D-efficiency via `idefix::Modfed` (seed `20251112`) | No preference data yet; transparent baseline; do not claim global optimality | Demo / coding agent | Adopted for demo |
| 2026-11-12 | Main effects only (4 parameters) | Matches demo scope; interactions not justified without priors/sample-size plan | Demo / coding agent | Open — statistician review |

## Clinical constraint summary (admin × frequency)

| Administration | Frequency | Clinically plausible? |
|---|---|---|
| Oral | Daily | Yes |
| Oral | Monthly | No / problematic |
| Oral | Every 6 months | No |
| Injection | Daily | No |
| Injection | Monthly | Yes |
| Injection | Every 6 months | Yes |

## Proposed combined regimen levels (for PI review)

1. Oral, daily  
2. Injectable, monthly (cabotegravir-like)  
3. Injectable, every 6 months (lenacapavir-like)  

**Trade-off:** administration and frequency no longer separately estimable; relative preferences among real regimens remain estimable (plus cost/insurance).
