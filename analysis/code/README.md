# Code Organization

This folder stores runnable table scripts.

## Rule

Each numbered script corresponds to one output table and can be run directly with `Rscript`.

## Scripts

- `01_tab_sample_flow.R`
- `02_tab_balance.R`
- `03_tab_attrition.R`
- `04_tab_main_ancova_t1.R`
- `05_tab_planned_contrasts_t1.R`
- `06_tab_pooled_effects_t1.R`
- `07_tab_heterogeneity_nat_t1.R`
- `08_tab_heterogeneity_rs_t1.R`
- `09_tab_heterogeneity_foreign_t1.R`
- `14_tab_main_ancova_t2.R`
- `15_tab_persistence_pooled_t1_t2.R`
- `16_tab_behavioral_outcomes_t1_t2.R`
- `17_tab_weekly_panel_slot1.R`
- `18_tab_signed_dose_response_t1.R`
- `19_tab_robustness_main_t1.R`
- `20_tab_multiple_testing_t1.R`
- `21_tab_recruitment_selection.R`
- `22_tab_attrition_composition.R`
- `23_tab_data_quality_by_investment.R`
- `24_tab_high_investment_robustness_t1.R`

## Figure Scripts

- `10_fig_main_effects_t1.R`
- `11_fig_heterogeneity_nationalism_t1.R`
- `12_fig_heterogeneity_regime_support_t1.R`
- `13_fig_heterogeneity_foreign_exposure_t1.R`

## Helper

- `_table_helpers.R` stores shared formatting, data-loading, and regression utilities used by the runnable scripts.
- `_figure_helpers.R` stores shared plotting utilities used by the runnable figure scripts.
