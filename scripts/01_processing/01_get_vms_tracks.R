################################################################################
# Collect VMS fishing tracks from BigQuery
################################################################################
#
# Juan Carlos Villaseñor-Derbez
# juancvd@stanford.edu
#
# Queries mex_vms_processed_latest joined with vessel_info_latest, applies
# gear-specific speed filters, and saves data/raw/mex_vms_tracks.rds.
# Includes segment_id (periods separated by >24h broadcast gaps) for the
# trip-structure analysis.
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  bigrquery,
  DBI
)

bq_auth("juancarlos.villader@gmail.com")

con <- dbConnect(
  drv = bigquery(),
  project = "mex-fisheries",
  dataset = "mex_vms",
  billing = "mex-fisheries",
  use_legacy_sql = FALSE,
  allowLargeResults = TRUE
)

vms <- tbl(con, "mex_vms_processed_latest")
vessel_info <- tbl(con, "vessel_info_latest")

## PROCESSING ##################################################################

target_vessels <- vessel_info |>
  mutate(gear_type = case_when((gear_type == "ARRASTRE" & target_finfish == 0 & target_sardine == 0 & target_shark == 0 & target_shrimp == 1 & target_tuna == 0 & target_other == 0) ~ "shrimp_trawl",
                               (gear_type == "PALANGRE" & target_finfish == 1 & target_sardine == 0 & target_shark == 0 & target_shrimp == 0 & target_tuna == 0 & target_other == 0) ~ "set_longline",
                               (gear_type == "PALANGRE" & target_finfish == 0 & target_sardine == 0 & (target_shark == 1 | target_tuna == 1) & target_shrimp == 0 & target_other == 0) ~ "drifting_longline",
                               (gear_type == "CERCO" & target_finfish == 0 & target_sardine == 1 & target_shark == 0 & target_shrimp == 0 & target_tuna == 0 & target_other == 0) ~ "small_pelagic_purse_seine",
                               (gear_type == "CERCO" & target_finfish == 0 & target_sardine == 0 & target_shark == 0 & target_shrimp == 0 & target_tuna == 1 & target_other == 0) ~ "tuna_purse_seine",
                               T ~ NA_character_)) |> 
  filter(!is.na(gear_type)) |> 
  select(vessel_rnpa, gear_type) |>
  distinct()

tracks <- vms |>
  inner_join(target_vessels, by = "vessel_rnpa") |>
  filter(
    distance_from_shore_m > 1000,
    !is.null(datetime),
    !is.na(datetime),
    gear_type == "shrimp_trawl"              & between(implied_speed_knots, 1, 5) |
      gear_type == "set_longline"              & between(implied_speed_knots, 2, 6) |
      gear_type == "drifting_longline"         & between(implied_speed_knots, 2, 9) |
      gear_type == "small_pelagic_purse_seine" & between(implied_speed_knots, 1, 4) |
      gear_type == "tuna_purse_seine"          & between(implied_speed_knots, 1, 4)
  ) |>
  mutate(date = sql("EXTRACT(date FROM datetime)")) |>
  select(datetime, date, vessel_rnpa, gear_type, lon, lat, hours)

local_tracks <- collect(tracks)

# Derive segment_id: consecutive fishing pings separated by >24h gaps
local_tracks <- local_tracks |>
  arrange(vessel_rnpa, datetime) |>
  group_by(vessel_rnpa) |>
  mutate(
    time_gap_h = as.numeric(difftime(datetime, lag(datetime), units = "hours")),
    new_segment = is.na(time_gap_h) | time_gap_h > 24,
    segment_id = cumsum(new_segment)
  ) |>
  select(-time_gap_h, -new_segment) |>
  ungroup()

## EXPORT ######################################################################

write_rds(
  x = local_tracks,
  file = here("data/raw/mex_vms_tracks.rds")
)

message("Saved: data/raw/mex_vms_tracks.rds")
