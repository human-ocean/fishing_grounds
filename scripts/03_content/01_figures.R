################################################################################
# Figures: parameter diagnostics and descriptive results
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Generates all exploratory and paper-ready figures:
#   - eps boxplot and kNN curves (from calibration)
#   - minPts distribution across vessels
#   - Map of fishing grounds by gear
#   - Space utilization (area, n grounds)
#   - Pairwise overlap
#   - Revisitation frequency and inter-visit intervals
#   - Seasonality
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  sf,
  rnaturalearth,
  patchwork
)

sf_use_s2(FALSE)

dir.create(here("results/img"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("results/tab"), showWarnings = FALSE, recursive = TRUE)

fishing_grounds <- read_rds(here("data/output/fishing_grounds.rds"))
vessel_params <- read_rds(here("data/output/vessel_params.rds"))
gear_eps <- read_rds(here("data/output/gear_eps.rds"))
per_vessel_eps <- read_rds(here("data/output/per_vessel_eps.rds"))
vessel_area <- read_rds(here("data/processed/vessel_area.rds"))
overlap_results <- read_rds(here("data/processed/pairwise_overlap.rds"))
gini <- read_rds(here("data/processed/gini_concentration.rds"))
visit_dates <- read_rds(here("data/processed/visit_dates.rds"))
inter_visit <- read_rds(here("data/processed/inter_visit_intervals.rds"))
seasonality <- read_rds(here("data/processed/ground_seasonality.rds"))
tracks <- read_rds(here("data/raw/mex_vms_tracks.rds"))

gear_labels <- c(shrimp_trawl = "Shrimp trawl",
                 set_longline = "Set longline",
                 drifting_longline = "Drifting longline",
                 small_pelagic_purse_seine = "Purse seine",
                 tuna_purse_seine = "Tuna purse seine")

grounds <- fishing_grounds |> filter(fg_hours > 0)

## 1. MINPTS DISTRIBUTION #####################################################

# Add gear type to vessel params
vessel_gear <- tracks |>
  distinct(vessel_rnpa, gear_type)

vp_with_gear <- vessel_params |>
  inner_join(vessel_gear, by = "vessel_rnpa")

p_minpts <- vp_with_gear |>
  ggplot(aes(x = min_pts, fill = gear_type)) +
  geom_histogram(bins = 30, alpha = 0.7) +
  scale_fill_brewer(palette = "Set2", labels = gear_labels) +
  facet_wrap(~gear_type, scales = "free_y", labeller = as_labeller(gear_labels)) +
  labs(
    x = "minPts (25 x years of data)",
    y = "Number of vessels",
    title = "Distribution of vessel-specific minPts by gear type",
    subtitle = "Domain rule: 5 hours x 5 days per year of data"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

ggsave(
  here("results/img/fig_minpts_distribution.png"),
  plot = p_minpts, width = 10, height = 6, dpi = 300
)

## 2. EPS CALIBRATION (paper-ready versions) ###################################

p_eps_box <- per_vessel_eps |>
  ggplot(aes(x = gear_type, y = vessel_eps / 1e3)) +
  geom_boxplot(outlier.alpha = 0.3, fill = "grey90") +
  geom_jitter(width = 0.15, alpha = 0.15, size = 0.6) +
  geom_point(
    data = gear_eps |> mutate(vessel_eps = eps),
    aes(x = gear_type, y = vessel_eps / 1e3),
    color = "red", size = 3, shape = 18
  ) +
  scale_x_discrete(labels = gear_labels) +
  labs(
    x = NULL, y = "Estimated eps (km)",
    title = "Per-vessel eps estimates",
    subtitle = "Red diamond = gear-level median"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  here("results/img/fig_eps_calibration.png"),
  plot = p_eps_box, width = 7, height = 5, dpi = 300
)

## 3. MAP OF FISHING GROUNDS ##################################################

mexico <- rnaturalearth::ne_countries(
  scale = 50, country = "Mexico", returnclass = "sf"
)

bbox <- grounds |>
  filter(!sf::st_is_empty(geometry)) |>
  sf::st_bbox()

p_map <- ggplot() +
  geom_sf(data = mexico, fill = "grey90", color = "grey50", linewidth = 0.3) +
  geom_sf(
    data = grounds |> filter(!sf::st_is_empty(geometry)),
    aes(fill = gear_type), color = NA, alpha = 0.4
  ) +
  scale_fill_brewer(palette = "Set2", labels = gear_labels) +
  coord_sf(
    xlim = c(bbox["xmin"] - 1, bbox["xmax"] + 1),
    ylim = c(bbox["ymin"] - 1, bbox["ymax"] + 1)
  ) +
  facet_wrap(~gear_type, labeller = as_labeller(gear_labels)) +
  labs(title = "Identified fishing grounds", fill = "Gear type") +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid = element_line(color = "grey95")
  )

ggsave(
  here("results/img/fig_grounds_map.png"),
  plot = p_map, width = 10, height = 8, dpi = 300
)

## 4. SPACE UTILIZATION ########################################################

p_vessel_area <- vessel_area |>
  ggplot(aes(x = gear_type, y = total_area_km2, fill = gear_type)) +
  geom_boxplot(outlier.alpha = 0.3, alpha = 0.7) +
  scale_fill_brewer(palette = "Set2", labels = gear_labels) +
  scale_x_discrete(labels = gear_labels) +
  labs(
    x = NULL,
    y = expression("Total fishing area per vessel (km"^2*")"),
    title = "Fishing area distribution by gear"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

p_ngrounds <- vessel_area |>
  ggplot(aes(x = gear_type, y = n_grounds, fill = gear_type)) +
  geom_boxplot(outlier.alpha = 0.3, alpha = 0.7) +
  scale_fill_brewer(palette = "Set2", labels = gear_labels) +
  scale_x_discrete(labels = gear_labels) +
  labs(
    x = NULL, y = "Number of fishing grounds",
    title = "Grounds per vessel by gear"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

p_space <- p_vessel_area | p_ngrounds

ggsave(
  here("results/img/fig_space_utilization.png"),
  plot = p_space, width = 10, height = 5, dpi = 300
)

## 5. OVERLAP ##################################################################

if (nrow(overlap_results) > 0) {
  p_overlap <- overlap_results |>
    filter(!is.na(jaccard)) |>
    ggplot(aes(x = jaccard, fill = gear_type)) +
    geom_histogram(bins = 40, alpha = 0.7, position = "identity") +
    scale_fill_brewer(palette = "Set2", labels = gear_labels) +
    facet_wrap(~gear_type, scales = "free_y", labeller = as_labeller(gear_labels)) +
    labs(
      x = "Pairwise Jaccard overlap", y = "Count",
      title = "Spatial overlap between vessels"
    ) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none")

  ggsave(
    here("results/img/fig_pairwise_overlap.png"),
    plot = p_overlap, width = 10, height = 4, dpi = 300
  )
}

## 6. REVISITATION #############################################################

p_visits <- visit_dates |>
  ggplot(aes(x = n_visits, fill = gear_type)) +
  geom_histogram(bins = 40, alpha = 0.7, position = "identity") +
  scale_fill_brewer(palette = "Set2", labels = gear_labels) +
  facet_wrap(~gear_type, scales = "free", labeller = as_labeller(gear_labels)) +
  labs(
    x = "Number of distinct visit dates", y = "Count",
    title = "Revisitation frequency by gear"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

p_intervals <- inter_visit |>
  ggplot(aes(x = median_interval_days, fill = gear_type)) +
  geom_histogram(bins = 40, alpha = 0.7, position = "identity") +
  scale_fill_brewer(palette = "Set2", labels = gear_labels) +
  facet_wrap(~gear_type, scales = "free", labeller = as_labeller(gear_labels)) +
  labs(
    x = "Median inter-visit interval (days)", y = "Count",
    title = "Time between revisits"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

p_revisit <- p_visits / p_intervals

ggsave(
  here("results/img/fig_revisitation.png"),
  plot = p_revisit, width = 10, height = 8, dpi = 300
)

## 7. SEASONALITY ##############################################################

p_season <- seasonality |>
  count(gear_type, ground_type) |>
  group_by(gear_type) |>
  mutate(frac = n / sum(n)) |>
  ungroup() |>
  ggplot(aes(x = gear_type, y = frac, fill = ground_type)) +
  geom_col(alpha = 0.8) +
  scale_x_discrete(labels = gear_labels) +
  scale_y_continuous(labels = scales::percent_format()) +
  scale_fill_manual(values = c(seasonal = "#fc8d62", year_round = "#66c2a5"),
                    labels = c(seasonal = "Seasonal", year_round = "Year-round")) +
  labs(
    x = NULL, y = "Fraction of grounds",
    title = "Seasonality of fishing grounds",
    fill = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(
  here("results/img/fig_seasonality.png"),
  plot = p_season, width = 6, height = 5, dpi = 300
)

## 8. SUMMARY TABLES ###########################################################

write_csv(gini, here("results/tab/gini_concentration.csv"))

gear_table <- vessel_area |>
  group_by(gear_type) |>
  summarise(
    n_vessels = n(),
    total_grounds = sum(n_grounds),
    median_grounds = median(n_grounds),
    median_area_km2 = round(median(total_area_km2), 1),
    median_hours = round(median(total_fg_hours), 1),
    .groups = "drop"
  ) |>
  left_join(gini, by = "gear_type")

write_csv(gear_table, here("results/tab/gear_summary_table.csv"))

message("Saved all figures to results/img/ and tables to results/tab/")
