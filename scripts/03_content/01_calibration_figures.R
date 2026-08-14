################################################################################
# Figures: DBSCAN parameter calibration diagnostics
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Produces:
#   - results/img/fig_minpts_distribution.png
#   - results/img/fig_eps_calibration.png
#   - results/tab/eps_summary.tex
#
# Inputs:
#   data/output/vessel_params.rds
#   data/output/gear_eps.rds
#   data/output/per_vessel_eps.rds
#   data/raw/mex_vms_tracks.rds  (for vessel-gear mapping)
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse
)

dir.create(here("results/img"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("results/tab"), showWarnings = FALSE, recursive = TRUE)

vessel_params <- read_rds(here("data/output/vessel_params.rds"))
gear_eps <- read_rds(here("data/output/gear_eps.rds"))
per_vessel_eps <- read_rds(here("data/output/per_vessel_eps.rds"))
tracks <- read_rds(here("data/raw/mex_vms_tracks.rds"))

gear_labels <- c(shrimp_trawl = "Shrimp trawl",
                 set_longline = "Set longline",
                 drifting_longline = "Drifting longline",
                 small_pelagic_purse_seine = "Purse seine",
                 tuna_purse_seine = "Tuna purse seine")

## 1. MINPTS DISTRIBUTION #####################################################

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

## 2. EPS CALIBRATION ##########################################################

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

## 3. EPS SUMMARY TABLE ########################################################

eps_summary <- per_vessel_eps |>
  group_by(gear_type) |>
  summarise(
    min = round(min(vessel_eps) / 1e3, 1),
    median = round(median(vessel_eps) / 1e3, 1),
    mean = round(mean(vessel_eps) / 1e3, 1),
    max = round(max(vessel_eps) / 1e3, 1),
    sd = round(sd(vessel_eps) / 1e3, 1),
    .groups = "drop"
  ) |>
  mutate(gear_type = gear_labels[gear_type])

writeLines(
  knitr::kable(eps_summary, format = "latex", booktabs = TRUE),
  here("results/tab/eps_summary.tex")
)

message("Saved: results/img/fig_minpts_distribution.png")
message("Saved: results/img/fig_eps_calibration.png")
message("Saved: results/tab/eps_summary.tex")
