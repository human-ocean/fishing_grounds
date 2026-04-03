################################################################################
# eps calibration
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Calibrates DBSCAN eps per gear using per-vessel kNN elbow detection.
# Uses k = BASE_MINPTS (25) for kNN distance computation — the base density
# threshold from the domain rule (5 hours x 5 days).
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  dbscan,
  sf,
  furrr
)

sf_use_s2(FALSE)

source(here("R/find_elbow.R"))
source(here("R/project_to_metric.R"))
source(here("R/minpts_rule.R"))

tracks <- read_rds(here("data/raw/mex_vms_tracks.rds"))

## PER-VESSEL EPS ESTIMATION ###################################################

estimate_vessel_eps <- function(vessel_data, k) {
  spat <- vessel_data |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = "EPSG:4326") |>
    project_to_metric()
  knn_dists <- sort(dbscan::kNNdist(sf::st_coordinates(spat), k = k))
  find_elbow(knn_dists)
}

# Qualifying vessels must have at least 2x the base minPts
min_qualifying_pts <- 2L * BASE_MINPTS

options(future.globals.maxSize = 3 * 1024^3)
plan(multisession, workers = min(4L, parallel::detectCores() - 1L))

eps_results <- tracks |>
  distinct(gear_type) |>
  pull(gear_type) |>
  purrr::map_dfr(function(gt) {
    gear_tracks <- tracks |> filter(gear_type == gt)

    vessel_counts <- gear_tracks |>
      count(vessel_rnpa, name = "n_pts")

    qualifying <- vessel_counts |>
      filter(n_pts >= min_qualifying_pts)

    message(sprintf(
      "[%s] %d / %d vessels qualify (>= %d pts)",
      gt, nrow(qualifying), nrow(vessel_counts), min_qualifying_pts
    ))

    per_vessel <- qualifying |>
      pull(vessel_rnpa) |>
      furrr::future_map_dbl(\(v) {
        vdata <- gear_tracks |> filter(vessel_rnpa == v)
        estimate_vessel_eps(vdata, k = BASE_MINPTS)
      }, .options = furrr_options(seed = TRUE))

    tibble(
      gear_type = gt,
      vessel_rnpa = qualifying$vessel_rnpa,
      vessel_eps = per_vessel
    )
  })

plan(sequential)

## AGGREGATE ###################################################################

gear_eps <- eps_results |>
  group_by(gear_type) |>
  summarise(eps = median(vessel_eps), .groups = "drop")

message("\n--- Gear-level eps (metres) ---")
print(gear_eps)

## DIAGNOSTIC PLOTS ############################################################

dir.create(here("results/img"), showWarnings = FALSE, recursive = TRUE)

# Boxplot of per-vessel eps by gear
p_box <- ggplot(eps_results, aes(x = gear_type, y = vessel_eps / 1e3)) +
  geom_boxplot(outlier.alpha = 0.3) +
  geom_jitter(width = 0.15, alpha = 0.2, size = 0.8) +
  geom_point(
    data = gear_eps |> mutate(vessel_eps = eps),
    aes(x = gear_type, y = vessel_eps / 1e3),
    color = "red", size = 3, shape = 18
  ) +
  labs(
    x = "Gear type", y = "Estimated eps (km)",
    title = "Per-vessel eps estimates by gear",
    subtitle = "Red diamond = median (gear-level eps)"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  plot = p_box,
  filename = here("results/img/dbscan_eps_boxplot.png"),
  width = 7, height = 5, dpi = 200
)

# kNN distance curves for representative vessels
representative <- eps_results |>
  inner_join(gear_eps |> rename(median_eps = eps), by = "gear_type") |>
  mutate(dist_to_median = abs(vessel_eps - median_eps)) |>
  group_by(gear_type) |>
  slice_min(dist_to_median, n = 3, with_ties = FALSE) |>
  ungroup()

knn_curves <- representative |>
  purrr::pmap_dfr(function(gear_type, vessel_rnpa, vessel_eps, median_eps, dist_to_median) {
    vdata <- tracks |> filter(.data$vessel_rnpa == .env$vessel_rnpa)
    spat <- vdata |>
      sf::st_as_sf(coords = c("lon", "lat"), crs = "EPSG:4326") |>
      project_to_metric()
    dists <- sort(dbscan::kNNdist(sf::st_coordinates(spat), k = BASE_MINPTS))
    tibble(
      gear_type = gear_type, vessel_rnpa = vessel_rnpa,
      index = seq_along(dists), knn_dist = dists, elbow_eps = vessel_eps
    )
  })

p_curves <- ggplot(knn_curves, aes(x = index, y = knn_dist / 1e3)) +
  geom_line(aes(color = vessel_rnpa), linewidth = 0.4) +
  geom_hline(
    data = knn_curves |> distinct(gear_type, vessel_rnpa, elbow_eps),
    aes(yintercept = elbow_eps / 1e3, color = vessel_rnpa),
    linetype = "dashed", linewidth = 0.3
  ) +
  facet_wrap(~gear_type, scales = "free") +
  labs(
    x = "Points (sorted)", y = "k-NN distance (km)",
    title = "kNN distance curves for representative vessels",
    subtitle = "Dashed lines = detected elbow"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

ggsave(
  plot = p_curves,
  filename = here("results/img/dbscan_knn_curves.png"),
  width = 10, height = 5, dpi = 200
)

## EXPORT ######################################################################

dir.create(here("data/output"), showWarnings = FALSE, recursive = TRUE)

write_rds(gear_eps, here("data/output/gear_eps.rds"))
write_rds(eps_results, here("data/output/per_vessel_eps.rds"))

message("\nSaved: data/output/gear_eps.rds")
message("Saved: data/output/per_vessel_eps.rds")
message("Saved: results/img/dbscan_eps_boxplot.png")
message("Saved: results/img/dbscan_knn_curves.png")
