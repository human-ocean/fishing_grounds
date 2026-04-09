all: figures tables

figures: results/img/fig_grounds_map.png results/img/fig_space_utilization.png results/img/fig_revisitation.png results/img/fig_seasonality.png results/img/fig_pairwise_overlap.png results/img/fig_eps_calibration.png results/img/fig_minpts_distribution.png

tables: results/tab/gear_summary_table.csv results/tab/gini_concentration.csv

makefile-dag.png: Makefile
	make -Bnd | make2graph -b | dot -Tpng -Gdpi=300 -o makefile-dag.png

## CONTENT #####################################################################

results/img/fig_grounds_map.png results/img/fig_space_utilization.png results/img/fig_revisitation.png results/img/fig_seasonality.png results/img/fig_pairwise_overlap.png results/img/fig_eps_calibration.png results/img/fig_minpts_distribution.png results/tab/gear_summary_table.csv results/tab/gini_concentration.csv: scripts/03_content/01_figures.R data/processed/pairwise_overlap.rds data/processed/ground_seasonality.rds
	cd $(<D); Rscript $(<F)

## ANALYSIS ####################################################################

data/processed/vessel_area.rds data/processed/pairwise_overlap.rds data/processed/gini_concentration.rds: scripts/02_analysis/03_space_utilization.R data/output/fishing_grounds.rds
	cd $(<D); Rscript $(<F)

data/processed/visit_dates.rds data/processed/inter_visit_intervals.rds data/processed/ground_seasonality.rds: scripts/02_analysis/04_revisitation_rates.R data/output/vessel_params.rds
	cd $(<D); Rscript $(<F)

data/output/fishing_grounds.rds data/output/vessel_params.rds: scripts/02_analysis/02_identify_grounds.R data/output/gear_eps.rds
	cd $(<D); Rscript $(<F)

data/output/gear_eps.rds data/output/per_vessel_eps.rds: scripts/02_analysis/01_eps_calibration.R data/raw/mex_vms_tracks.rds
	cd $(<D); Rscript $(<F)

## PROCESSING ##################################################################

data/processed/gear_summary.rds data/processed/vessel_summary.rds: scripts/01_processing/02_prepare_tracks.R data/raw/mex_vms_tracks.rds
	cd $(<D); Rscript $(<F)

data/raw/mex_vms_tracks.rds: scripts/01_processing/01_get_vms_tracks.R
	cd $(<D); Rscript $(<F)
