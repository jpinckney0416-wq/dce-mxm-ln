# Environment setup summary (Stage 1)

**Date:** 2026-11-12  
**Machine:** Jean's MacBook Pro (macOS Sonoma 14.0, aarch64)  
**Project path:** `/Users/jeanp/prep-dce`

## R

- `R` / `Rscript`: **4.6.2** (2026-10-29) — Diversified Portfolio
- Smoke test (`print("ok")` / `sessionInfo()` via `Rscript`): **passed**
- Bootstrap: `Rscript R/01_setup.R` (seed `REPRODUCIBLE_SEED = 20251112`)

## Packages verified

| Package | Version | Notes |
|---------|---------|--------|
| idefix | 1.1.0 | Installed from CRAN (`https://cloud.r-project.org`); `library(idefix)` OK |
| utils (base) | (base) | `read.csv` on `config/attributes.csv` OK |

## Blockers

None. R present; network/CRAN install succeeded.

## Scope reminder

Stage 1 only: no attribute levels filled, no design generation, no patient/simulated analysis data.
