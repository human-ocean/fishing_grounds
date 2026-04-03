################################################################################
# Prepare tracks: basic summaries and cleaning
################################################################################
#
# Juan Carlos Villaseñor-Derbez
# juancvd@stanford.edu
#
# Loads raw tracks from data/raw/, computes summary statistics on vessels per
# gear and points per vessel, and saves a lightweight summary to
# data/processed/.
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse
)

tracks <- read_rds(here("data/raw/mex_vms_tracks.rds"))

## SUMMARIES ###################################################################

gear_summary <- tracks |>
  group_by(gear_type) |>
  summarise(
    n_vessels = n_distinct(vessel_rnpa),
    n_points = n(),
    total_hours = sum(hours, na.rm = TRUE),
    date_range_start = min(date, na.rm = TRUE),
    date_range_end = max(date, na.rm = TRUE),
    .groups = "drop"
  )

vessel_summary <- tracks |>
  group_by(gear_type, vessel_rnpa) |>
  summarise(
    n_points = n(),
    total_hours = sum(hours, na.rm = TRUE),
    n_segments = n_distinct(segment_id),
    n_dates = n_distinct(date),
    .groups = "drop"
  )

message("--- Gear-level summary ---")
print(gear_summary)

message("\n--- Vessel-level distribution (points per vessel) ---")
vessel_summary |>
  group_by(gear_type) |>
  summarise(
    n_vessels = n(),
    median_pts = median(n_points),
    mean_pts = round(mean(n_points)),
    min_pts = min(n_points),
    max_pts = max(n_points),
    .groups = "drop"
  ) |>
  print()

## EXPORT ######################################################################

dir.create(here("data/processed"), showWarnings = FALSE, recursive = TRUE)

write_rds(gear_summary, here("data/processed/gear_summary.rds"))
write_rds(vessel_summary, here("data/processed/vessel_summary.rds"))

message("\nSaved: data/processed/gear_summary.rds")
message("Saved: data/processed/vessel_summary.rds")
