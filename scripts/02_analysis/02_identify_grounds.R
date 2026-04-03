################################################################################
# Identify fishing grounds
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Runs DBSCAN with gear-level eps and vessel-specific minPts.
# minPts = 25 * N_years  (domain rule: 5 hrs x 5 days per year of data).
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  dbscan,
  sf,
  furrr,
  lubridate
)

sf_use_s2(FALSE)

source(here("R/project_to_metric.R"))
source(here("R/get_extensive.R"))
source(here("R/minpts_rule.R"))

tracks <- read_rds(here("data/raw/mex_vms_tracks.rds"))
gear_eps <- read_rds(here("data/output/gear_eps.rds"))

## COMPUTE PER-VESSEL MINPTS ##################################################

vessel_years <- tracks |>
  mutate(year = year(date)) |>
  group_by(vessel_rnpa) |>
  summarise(n_years = n_distinct(year), .groups = "drop")

vessel_params <- vessel_years |>
  mutate(min_pts = compute_minpts(n_years))

message("--- minPts distribution ---")
summary(vessel_params$min_pts)

## PROCESSING ##################################################################

message("\n--- Gear-level eps ---")
print(gear_eps)

plan(multisession, workers = min(4L, parallel::detectCores() - 1L))

fishing_grounds <- tracks |>
  inner_join(gear_eps, by = "gear_type") |>
  inner_join(vessel_params, by = "vessel_rnpa") |>
  group_by(vessel_rnpa, eps, min_pts) |>
  group_split() |>
  future_map_dfr(
    \(d) get_extensive(d, eps = unique(d$eps), min_pts = unique(d$min_pts)),
    .options = furrr_options(seed = TRUE)
  )

plan(sequential)

n_grounds <- fishing_grounds |> filter(fg_hours > 0) |> nrow()
n_vessels <- n_distinct(fishing_grounds$vessel_rnpa)

message(sprintf(
  "\nIdentified %d fishing grounds across %d vessels",
  n_grounds, n_vessels
))

## EXPORT ######################################################################

dir.create(here("data/output"), showWarnings = FALSE, recursive = TRUE)

write_rds(fishing_grounds, here("data/output/fishing_grounds.rds"))
write_rds(vessel_params, here("data/output/vessel_params.rds"))

message("Saved: data/output/fishing_grounds.rds")
message("Saved: data/output/vessel_params.rds")
