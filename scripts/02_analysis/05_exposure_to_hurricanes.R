################################################################################
# Calculate hurricane wind exposure at fishing ground centroids
################################################################################
#
# Juan Carlos Villasenor-Derbez
# jc_villasenor@miami.edu
#
# Downloads IBTrACS NA basin tracks, reconstructs wind fields using the
# stormwindmodel package, and computes daily maximum sustained wind speed
# at each fishing ground centroid. Only Gulf of Mexico gears (shrimp trawl,
# set longline, drifting longline) are included, and grounds are filtered
# to those that were active during each storm.
#
# Inputs:
#   data/output/fishing_grounds.rds
#   data/processed/visit_dates.rds
#   IBTrACS v04r01 NA basin (downloaded from NOAA)
#
# Outputs:
#   data/processed/hurricane_exposure/{YEAR}_{NAME}.rds  (per storm)
#   data/processed/hurricane_ground_exposure.rds          (combined)
#
################################################################################

# SET UP #######################################################################

pacman::p_load(
  here,
  tidyverse,
  sf,
  stormwindmodel,
  furrr,
  lubridate
)

sf_use_s2(FALSE)

dir.create(here("data/processed/hurricane_exposure"),
           showWarnings = FALSE, recursive = TRUE)

## Load fishing grounds and visit dates ----------------------------------------

fishing_grounds <- read_rds(here("data/output/fishing_grounds.rds"))
visit_dates <- read_rds(here("data/processed/visit_dates.rds"))

## Filter to Gulf of Mexico gears ----------------------------------------------

gom_gears <- c("shrimp_trawl", "set_longline", "drifting_longline")

grounds <- fishing_grounds |>
  filter(fg_hours > 0,
         gear_type %in% gom_gears) |>
  inner_join(visit_dates |> select(gear_type, vessel_rnpa, cluster,
                                   first_visit, last_visit),
             by = c("gear_type", "vessel_rnpa", "cluster"))

n_grounds <- nrow(grounds)
message(sprintf("Working with %d fishing grounds across %d vessels and %d gear types",
                n_grounds,
                n_distinct(grounds$vessel_rnpa),
                n_distinct(grounds$gear_type)))

## Build centroid grid ---------------------------------------------------------

grounds_centroids <- st_centroid(grounds)

grounds_grid <- grounds_centroids |>
  bind_cols(st_coordinates(grounds_centroids)) |>
  st_drop_geometry() |>
  transmute(
    gridid = paste(vessel_rnpa, cluster, sep = "-"),
    gear_type,
    vessel_rnpa,
    cluster,
    first_visit,
    last_visit,
    glon = X,
    glat = Y,
    glandsea = FALSE
  )

# DOWNLOAD AND PREPARE HURRICANE TRACKS ########################################

base_url <- "https://www.ncei.noaa.gov/data/international-best-track-archive-for-climate-stewardship-ibtracs/v04r01/access/csv"

message("Downloading IBTrACS NA basin...")
col_names_na <- names(read_csv(paste0(base_url, "/ibtracs.NA.list.v04r01.csv"),
                               n_max = 0, show_col_types = FALSE))

hur_na <- read_csv(paste0(base_url, "/ibtracs.NA.list.v04r01.csv"),
                   col_names = col_names_na,
                   skip = 2,
                   show_col_types = FALSE)

hurricanes <- hur_na |>
  filter(between(SEASON, 2007, 2024),
         NAME != "UNNAMED") |>
  select(name = NAME, year = SEASON, date = ISO_TIME,
         latitude = LAT, longitude = LON,
         wind = USA_WIND) |>
  mutate(
    date_parsed = ymd_hms(date),
    date = paste0(
      year(date_parsed),
      str_pad(month(date_parsed), 2, pad = "0"),
      str_pad(day(date_parsed), 2, pad = "0"),
      str_pad(hour(date_parsed), 2, pad = "0"),
      str_pad(minute(date_parsed), 2, pad = "0")
    ),
    storm_id = paste0(year, "_", name)
  ) |>
  select(-date_parsed)

storm_ids <- unique(hurricanes$storm_id)
n_storms <- length(storm_ids)
message(sprintf("Found %d named storms in NA basin (2007-2024)", n_storms))

# COMPUTE EXPOSURE PER STORM ##################################################

#' Compute daily max sustained wind speed at each active ground for one storm
#'
#' @param track Data frame of IBTrACS track points for a single storm.
#' @param full_grid Full grid of fishing ground centroids with visit metadata.
#' @param storm_id Character string identifying the storm (YEAR_NAME).
#' @return Invisibly returns NULL; writes RDS to disk.
compute_storm_exposure <- function(track, full_grid, storm_id) {

  out_path <- here("data/processed/hurricane_exposure", paste0(storm_id, ".rds"))

  # Skip if already computed

  if (file.exists(out_path)) {
    message(sprintf("  [skip] %s already exists", storm_id))
    return(invisible(NULL))
  }

  # Determine storm date range
  storm_dates <- track |>
    mutate(d = ymd(substr(date, 1, 8))) |>
    pull(d)
  storm_start <- min(storm_dates, na.rm = TRUE)
  storm_end <- max(storm_dates, na.rm = TRUE)

  # Filter to grounds active during this storm
  active_grid <- full_grid |>
    filter(first_visit <= storm_end,
           last_visit >= storm_start)

  if (nrow(active_grid) == 0) {
    message(sprintf("  [skip] %s — no active grounds during storm window", storm_id))
    return(invisible(NULL))
  }

  # Build stormwindmodel grid (needs: gridid, glon, glat, glandsea)
  grid_df <- active_grid |>
    select(gridid, glon, glat, glandsea) |>
    as.data.frame()

  # Compute wind fields
  exposure <- tryCatch(
    stormwindmodel::calc_grid_winds(hurr_track = track, grid_df = grid_df),
    error = function(e) {
      message(sprintf("  [error] %s — %s", storm_id, conditionMessage(e)))
      return(NULL)
    }
  )

  if (is.null(exposure)) return(invisible(NULL))

  # Extract daily max sustained wind per grid cell
  ts <- exposure[["vmax_sust"]] |>
    as_tibble(rownames = "time") |>
    pivot_longer(cols = -time,
                 names_to = "grid_id",
                 values_to = "vmax_sust") |>
    mutate(time = ymd_hms(time),
           date = as_date(time)) |>
    left_join(active_grid |> select(gridid, glon, glat, gear_type,
                                    vessel_rnpa, cluster),
              by = c("grid_id" = "gridid")) |>
    group_by(grid_id, vessel_rnpa, cluster, gear_type, glon, glat, date) |>
    summarize(vmax_sust = max(vmax_sust, na.rm = TRUE),
              .groups = "drop") |>
    filter(vmax_sust >= 34) |>
    mutate(storm_id = storm_id)

  write_rds(ts, out_path)
  message(sprintf("  [done] %s — %d ground-days with TS+ winds",
                  storm_id, nrow(ts)))
  invisible(NULL)
}

# Run in parallel
plan(multisession, workers = min(4L, parallel::detectCores() - 1L))

message("\nComputing exposure for each storm...")
hurricanes |>
  split(hurricanes$storm_id) |>
  future_walk(
    \(track) compute_storm_exposure(track,
                                    full_grid = grounds_grid,
                                    storm_id = unique(track$storm_id)),
    .options = furrr_options(seed = TRUE)
  )

plan(sequential)

# COMBINE RESULTS ##############################################################

message("\nCombining per-storm results...")

storm_files <- list.files(here("data/processed/hurricane_exposure"),
                          pattern = "\\.rds$", full.names = TRUE)

hurricane_exposure <- storm_files |>
  map_dfr(read_rds) |>
  separate_wider_delim(storm_id, delim = "_", names = c("storm_year", "storm_name"),
                       too_many = "merge") |>
  mutate(storm_year = as.integer(storm_year)) |>
  rename(lon = glon, lat = glat) |>
  select(vessel_rnpa, cluster, gear_type, lon, lat,
         storm_name, storm_year, date, vmax_sust)

write_rds(hurricane_exposure,
          here("data/processed/hurricane_ground_exposure.rds"))

n_exposed <- n_distinct(paste(hurricane_exposure$vessel_rnpa,
                              hurricane_exposure$cluster))

message(sprintf("\nDone. %d unique grounds exposed across %d storms.",
                n_exposed,
                n_distinct(paste(hurricane_exposure$storm_year,
                                 hurricane_exposure$storm_name))))
message("Saved: data/processed/hurricane_ground_exposure.rds")
