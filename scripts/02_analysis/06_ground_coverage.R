################################################################################
# Ground coverage: share of each vessel's activity inside fishing grounds
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# For each vessel, computes the share of VMS points (and hours) that fall
# inside its identified fishing grounds, i.e. the share DBSCAN did not label
# as noise. Vessels with no ground are kept with a share of zero.
#
# Inputs:
#   data/output/fishing_grounds.rds
#   data/processed/vessel_summary.rds
#
# Produces:
#   data/processed/vessel_coverage.rds
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  sf
)

fishing_grounds <- read_rds(here("data/output/fishing_grounds.rds"))
vessel_summary <- read_rds(here("data/processed/vessel_summary.rds"))

## PROCESSING ##################################################################

# Rows with fg_hours == 0 are placeholders for vessels without grounds; their
# n_pts is the vessel's total point count, so it must not enter the numerator.
in_grounds <- fishing_grounds |>
  st_drop_geometry() |>
  group_by(vessel_rnpa) |>
  summarise(
    n_grounds = sum(fg_hours > 0),
    pts_in_grounds = sum(n_pts[fg_hours > 0]),
    hours_in_grounds = sum(fg_hours),
    .groups = "drop"
  )

vessel_coverage <- vessel_summary |>
  select(gear_type, vessel_rnpa, n_points, total_hours) |>
  inner_join(in_grounds, by = "vessel_rnpa") |>
  mutate(
    share_pts = pts_in_grounds / n_points,
    share_hours = hours_in_grounds / total_hours
  )

# Both inputs derive from the same tracks; a mismatch means one of them is stale
stopifnot(
  nrow(vessel_coverage) == nrow(vessel_summary),
  nrow(vessel_coverage) == nrow(in_grounds),
  between(vessel_coverage$share_pts, 0, 1),
  between(vessel_coverage$share_hours, 0, 1 + 1e-8)
)

message("--- Share of points inside fishing grounds, by gear ---")
vessel_coverage |>
  group_by(gear_type) |>
  summarise(
    n_vessels = n(),
    n_without_grounds = sum(n_grounds == 0),
    median_share_all = median(share_pts),
    median_share_with_grounds = median(share_pts[n_grounds > 0]),
    pooled_share = sum(pts_in_grounds) / sum(n_points),
    .groups = "drop"
  ) |>
  print()

## EXPORT ######################################################################

write_rds(vessel_coverage, here("data/processed/vessel_coverage.rds"))

message("\nSaved: data/processed/vessel_coverage.rds")
