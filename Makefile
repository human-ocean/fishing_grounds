all: figures tables

figures: results/img/fig_grounds_map.png results/img/fig_space_utilization.png results/img/fig_revisitation.png results/img/fig_seasonality.png results/img/fig_pairwise_overlap.png results/img/fig_eps_calibration.png results/img/fig_minpts_distribution.png results/img/fig_grounds_exposed_by_year.png results/img/fig_hurricanes_per_ground.png

tables: results/tab/eps_summary.tex results/tab/gear_summary_table.tex results/tab/gini_concentration.tex results/tab/grounds_exposure_summary.tex results/tab/hurricanes_per_ground.tex

makefile-dag.png: Makefile
	make -Bnd | make2graph -b | dot -Tpng -Gdpi=300 -o makefile-dag.png

## HURRICANE CONTENT ###########################################################

results/img/fig_grounds_exposed_by_year.png results/img/fig_hurricanes_per_ground.png results/tab/grounds_exposure_summary.tex results/tab/hurricanes_per_ground.tex: scripts/03_content/02_hurricane_figures.R data/processed/hurricane_ground_exposure.rds
	cd $(<D); Rscript $(<F)

## CONTENT: CALIBRATION ########################################################

results/img/fig_minpts_distribution.png results/img/fig_eps_calibration.png results/tab/eps_summary.tex: scripts/03_content/01_calibration_figures.R data/output/vessel_params.rds data/output/gear_eps.rds data/output/per_vessel_eps.rds data/raw/mex_vms_tracks.rds
	cd $(<D); Rscript $(<F)

## CONTENT: GROUNDS MAP ########################################################

results/img/fig_grounds_map.png: scripts/03_content/03_grounds_map.R data/output/fishing_grounds.rds
	cd $(<D); Rscript $(<F)

## CONTENT: SPACE UTILIZATION ##################################################

results/img/fig_space_utilization.png results/img/fig_pairwise_overlap.png results/tab/gear_summary_table.tex results/tab/gini_concentration.tex: scripts/03_content/04_space_utilization.R data/processed/vessel_area.rds data/processed/pairwise_overlap.rds data/processed/gini_concentration.rds
	cd $(<D); Rscript $(<F)

## CONTENT: REVISITATION #######################################################

results/img/fig_revisitation.png results/img/fig_seasonality.png: scripts/03_content/05_revisitation.R data/processed/visit_dates.rds data/processed/inter_visit_intervals.rds data/processed/ground_seasonality.rds
	cd $(<D); Rscript $(<F)

## HURRICANE EXPOSURE ##########################################################

data/processed/hurricane_ground_exposure.rds: scripts/02_analysis/05_exposure_to_hurricanes.R data/output/fishing_grounds.rds data/processed/visit_dates.rds
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
