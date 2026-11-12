# ED PrEP Discrete Choice Experiment (DCE) — `dce-mxm-ln`

Minimal reproducible R project for designing a discrete choice experiment on patient preferences for HIV PrEP in the emergency department (oral and long-acting injectable, including twice-yearly lenacapavir).

**IRB:** IRB00515476 (Johns Hopkins Medicine; PI Dr. Yu-Hsiang Hsieh).  
**Repo:** [dce-mxm-ln](https://github.com/jpinckney0416-wq/dce-mxm-ln)  
**Stage:** Three-attribute **mathematical / illustrative** design demo. No patient data. Do not invent response findings.

> **Important:** The demo design in `outputs/` is an **unrestricted mathematical design**. It may include clinically implausible PrEP combinations and is **not** a clinically validated patient survey. Do not administer to patients.

## Demo attributes (illustrative; `finalized=FALSE`)

| Attribute | Levels |
|---|---|
| Administration method | Oral, Injection |
| Medication frequency | Daily, Monthly, Every 6 months |
| Out-of-pocket cost | $0, $30 |

Clinical note: administration and frequency are **not** independent in real PrEP products. See `docs/design_decisions.md` and `docs/design_report.md` for plausibility analysis and a proposed combined **PrEP regimen** attribute (not silently adopted).

## Layout

```
prep-dce/
├── README.md
├── R/
│   ├── 01_setup.R
│   ├── 02_attributes.R
│   ├── 03_design.R
│   └── 04_evaluate_design.R
├── config/
│   └── attributes.csv
├── outputs/
│   ├── prep_dce_design.csv
│   ├── prep_dce_survey.html
│   ├── prep_dce_diagnostics.csv
│   ├── design_report.md
│   ├── designs/
│   ├── diagnostics/
│   └── redcap/
├── docs/
│   ├── protocol_notes.md
│   ├── design_decisions.md
│   ├── design_report.md
│   └── analysis_plan_future.md
└── data/
    └── simulated/          # empty; no fabricated patient responses
```

## Quick start

From this directory:

```bash
Rscript R/01_setup.R
Rscript R/02_attributes.R
Rscript R/03_design.R
Rscript R/04_evaluate_design.R
```

Or run evaluation alone (sources the upstream scripts):

```bash
Rscript R/04_evaluate_design.R
```

Reproducible seed: `20251112`. Design engine: `idefix::Modfed` (zero-prior local D-efficiency). Main effects only (4 parameters).

## Scope rules

- No identifiable patient data in this repository.
- No fake patient findings, coefficients, or preference weights.
- Final attributes and patient-facing instrument require mixed-methods review and an eIRB amendment.
