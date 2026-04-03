################################################################################
# Revisitation rates
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Descriptive analysis of how often vessels revisit their fishing grounds:
#   - Distinct visit dates per vessel-ground pair
#   - Inter-visit intervals
#   - Seasonal vs year-round ground characterisation
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  sf,
  dbscan,
  lubridate
)

sf_use_s2(FALSE)

source(here("R/project_to_metric.R"))
source(here("R/minpts_rule.R"))

tracks <- read_rds(here("data/raw/mex_vms_tracks.rds"))
gear_eps <- read_rds(here("data/output/gear_eps.rds"))
vessel_params <- read_rds(here("data/output/vessel_params.rds"))

## ASSIGN PINGS TO GROUNDS #####################################################

assign_clusters <- function(vessel_data, eps, min_pts) {
  npts <- nrow(vessel_data)
  vessel_data$cluster <- 0L

  if (npts >= min_pts) {
    spat <- vessel_data |>
      sf::st_as_sf(coords = c("lon", "lat"), crs = "EPSG:4326") |>
      project_to_metric()

    clust <- spat |>
      sf::st_coordinates() |>
      dbscan::dbscan(eps = eps, minPts = min_pts)

    vessel_data$cluster <- clust$cluster
  }

  vessel_data
}

tagged_tracks <- tracks |>
  inner_join(gear_eps, by = "gear_type") |>
  inner_join(vessel_params |> select(vessel_rnpa, min_pts), by = "vessel_rnpa") |>
  group_by(vessel_rnpa, eps, min_pts) |>
  group_split() |>
  purrr::map_dfr(\(d) assign_clusters(d, eps = unique(d$eps), min_pts = unique(d$min_pts))) |>
  filter(cluster > 0)

## VISIT-LEVEL SUMMARIES #######################################################

visit_dates <- tagged_tracks |>
  group_by(gear_type, vessel_rnpa, cluster) |>
  summarise(
    visit_dates = list(sort(unique(date))),
    n_visits = n_distinct(date),
    first_visit = min(date, na.rm = TRUE),
    last_visit = max(date, na.rm = TRUE),
    span_days = as.numeric(difftime(max(date), min(date), units = "days")),
    total_hours = sum(hours, na.rm = TRUE),
    .groups = "drop"
  )

## INTER-VISIT INTERVALS ######################################################

inter_visit <- visit_dates |>
  filter(n_visits >= 2) |>
  mutate(
    intervals = purrr::map(visit_dates, \(d) as.numeric(diff(d))),
    mean_interval_days = purrr::map_dbl(intervals, mean, na.rm = TRUE),
    median_interval_days = purrr::map_dbl(intervals, median, na.rm = TRUE),
    min_interval_days = purrr::map_dbl(intervals, min, na.rm = TRUE),
    max_interval_days = purrr::map_dbl(intervals, max, na.rm = TRUE)
  ) |>
  select(-visit_dates, -intervals)

## SEASONAL VS YEAR-ROUND #####################################################

seasonality <- tagged_tracks |>
  mutate(month = month(date)) |>
  group_by(gear_type, vessel_rnpa, cluster) |>
  summarise(
    n_months = n_distinct(month),
    months_active = paste(sort(unique(month)), collapse = ","),
    .groups = "drop"
  ) |>
  mutate(ground_type = if_else(n_months >= 10, "year_round", "seasonal"))

seasonality_summary <- seasonality |>
  group_by(gear_type, ground_type) |>
  summarise(n_grounds = n(), .groups = "drop") |>
  group_by(gear_type) |>
  mutate(frac = n_grounds / sum(n_grounds)) |>
  ungroup()

message("--- Revisitation summary by gear ---")
inter_visit |>
  group_by(gear_type) |>
  summarise(
    n_ground_pairs = n(),
    median_n_visits = median(n_visits),
    mean_interval = mean(mean_interval_days, na.rm = TRUE),
    median_interval = median(median_interval_days, na.rm = TRUE),
    .groups = "drop"
  ) |>
  print()

message("\n--- Seasonality ---")
print(seasonality_summary)

## EXPORT ######################################################################

dir.create(here("data/processed"), showWarnings = FALSE, recursive = TRUE)

write_rds(visit_dates |> select(-visit_dates), here("data/processed/visit_dates.rds"))
write_rds(inter_visit, here("data/processed/inter_visit_intervals.rds"))
write_rds(seasonality, here("data/processed/ground_seasonality.rds"))

message("\nSaved: data/processed/visit_dates.rds")
message("Saved: data/processed/inter_visit_intervals.rds")
message("Saved: data/processed/ground_seasonality.rds")
