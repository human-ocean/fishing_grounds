################################################################################
# Figures: revisitation frequency and seasonality
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Produces:
#   - results/img/fig_revisitation.png
#   - results/img/fig_seasonality.png
#
# Inputs:
#   data/processed/visit_dates.rds
#   data/processed/inter_visit_intervals.rds
#   data/processed/ground_seasonality.rds
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  patchwork
)

dir.create(here("results/img"), showWarnings = FALSE, recursive = TRUE)

visit_dates <- read_rds(here("data/processed/visit_dates.rds"))
inter_visit <- read_rds(here("data/processed/inter_visit_intervals.rds"))
seasonality <- read_rds(here("data/processed/ground_seasonality.rds"))

gear_labels <- c(shrimp_trawl = "Shrimp trawl",
                 set_longline = "Set longline",
                 drifting_longline = "Drifting longline",
                 small_pelagic_purse_seine = "Purse seine",
                 tuna_purse_seine = "Tuna purse seine")

## 1. REVISITATION #############################################################

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

message("Saved: results/img/fig_revisitation.png")

## 2. SEASONALITY ##############################################################

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

message("Saved: results/img/fig_seasonality.png")
