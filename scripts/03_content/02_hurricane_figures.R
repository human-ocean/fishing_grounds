################################################################################
# Hurricane exposure figures and tables
################################################################################
#
# Juan Carlos Villasenor-Derbez
# jc_villasenor@miami.edu
#
# Produces descriptive figures and summary tables for hurricane exposure
# of Gulf of Mexico fishing grounds.
#
# Inputs:
#   data/processed/hurricane_ground_exposure.rds
#   data/processed/visit_dates.rds
#   data/output/fishing_grounds.rds
#
# Outputs:
#   results/img/fig_grounds_exposed_by_year.png
#   results/img/fig_hurricanes_per_ground.png
#   results/tab/grounds_exposure_summary.tex
#   results/tab/hurricanes_per_ground.tex
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  patchwork
)

dir.create(here("results/img"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("results/tab"), showWarnings = FALSE, recursive = TRUE)

## Load data -------------------------------------------------------------------

exposure <- read_rds(here("data/processed/hurricane_ground_exposure.rds"))
visit_dates <- read_rds(here("data/processed/visit_dates.rds"))
fishing_grounds <- read_rds(here("data/output/fishing_grounds.rds"))

gom_gears <- c("shrimp_trawl", "set_longline", "drifting_longline")

gear_labels <- c(
  shrimp_trawl = "Shrimp trawl",
  set_longline = "Set longline",
  drifting_longline = "Drifting longline"
)

## Build denominator: total active grounds per year × gear ---------------------

# A ground is "active" in a year if that year falls within [first_visit, last_visit]
grounds_with_visits <- fishing_grounds |>
  sf::st_drop_geometry() |>
  filter(fg_hours > 0, gear_type %in% gom_gears) |>
  inner_join(visit_dates |> select(gear_type, vessel_rnpa, cluster,
                                   first_visit, last_visit),
             by = c("gear_type", "vessel_rnpa", "cluster"))

years <- 2007:2024

active_by_year <- grounds_with_visits |>
  mutate(first_year = year(first_visit),
         last_year = year(last_visit)) |>
  rowwise() |>
  mutate(active_years = list(seq(first_year, last_year))) |>
  ungroup() |>
  unnest(active_years) |>
  filter(active_years %in% years) |>
  rename(year = active_years) |>
  group_by(year, gear_type) |>
  summarise(n_grounds_total = n(), .groups = "drop")

## 1. GROUNDS EXPOSED BY YEAR #################################################

# Exposed grounds: distinct vessel_rnpa × cluster per year × gear
exposed_by_year <- exposure |>
  mutate(year = storm_year) |>
  distinct(year, gear_type, vessel_rnpa, cluster) |>
  group_by(year, gear_type) |>
  summarise(n_grounds_exposed = n(), .groups = "drop")

exposure_summary <- active_by_year |>
  left_join(exposed_by_year, by = c("year", "gear_type")) |>
  replace_na(list(n_grounds_exposed = 0)) |>
  mutate(pct_exposed = 100 * n_grounds_exposed / n_grounds_total)

# Save table
writeLines(
  knitr::kable(exposure_summary |> mutate(gear_type = gear_labels[gear_type]),
               format = "latex", booktabs = TRUE),
  here("results/tab/grounds_exposure_summary.tex")
)
message("Saved: results/tab/grounds_exposure_summary.tex")

# Figure: number and % of grounds exposed
p_n <- exposure_summary |>
  ggplot(aes(x = year, y = n_grounds_exposed, fill = gear_type)) +
  geom_col(alpha = 0.8) +
  facet_wrap(~gear_type, scales = "free_y",
             labeller = as_labeller(gear_labels)) +
  scale_fill_brewer(palette = "Set2", guide = "none") +
  labs(x = NULL, y = "Grounds exposed") +
  theme_minimal(base_size = 12)

p_pct <- exposure_summary |>
  ggplot(aes(x = year, y = pct_exposed, fill = gear_type)) +
  geom_col(alpha = 0.8) +
  facet_wrap(~gear_type, scales = "free_y",
             labeller = as_labeller(gear_labels)) +
  scale_fill_brewer(palette = "Set2", guide = "none") +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(x = NULL, y = "Grounds exposed (%)") +
  theme_minimal(base_size = 12)

p_combined <- p_n / p_pct +
  plot_annotation(title = "Fishing grounds exposed to tropical storm force winds")

ggsave(here("results/img/fig_grounds_exposed_by_year.png"),
       p_combined, width = 10, height = 8, dpi = 300, bg = "transparent")
message("Saved: results/img/fig_grounds_exposed_by_year.png")

## 2. HURRICANES PER GROUND ###################################################

# Count distinct hurricanes per ground per year
hur_per_ground <- exposure |>
  distinct(storm_year, storm_name, gear_type, vessel_rnpa, cluster) |>
  group_by(storm_year, gear_type, vessel_rnpa, cluster) |>
  summarise(n_hurricanes = n(), .groups = "drop") |>
  rename(year = storm_year)

# Summary table
hur_summary <- hur_per_ground |>
  group_by(year, gear_type) |>
  summarise(
    n_grounds = n(),
    mean_hurricanes = mean(n_hurricanes),
    median_hurricanes = median(n_hurricanes),
    max_hurricanes = max(n_hurricanes),
    .groups = "drop"
  )

writeLines(
  knitr::kable(hur_summary |> mutate(gear_type = gear_labels[gear_type]),
               format = "latex", booktabs = TRUE),
  here("results/tab/hurricanes_per_ground.tex")
)
message("Saved: results/tab/hurricanes_per_ground.tex")

# Figure: distribution of hurricanes per ground
p_hur <- hur_per_ground |>
  ggplot(aes(x = n_hurricanes, fill = gear_type)) +
  geom_histogram(binwidth = 1, alpha = 0.8, color = "white") +
  facet_grid(gear_type ~ year,
             labeller = labeller(gear_type = gear_labels),
             scales = "free_y") +
  scale_fill_brewer(palette = "Set2", guide = "none") +
  labs(x = "Number of hurricanes per ground",
       y = "Count of grounds",
       title = "Hurricane exposure frequency by gear type and year") +
  theme_minimal(base_size = 12) +
  theme(strip.text.y = element_text(angle = 0))

ggsave(here("results/img/fig_hurricanes_per_ground.png"),
       p_hur, width = 16, height = 6, dpi = 300, bg = "transparent")
message("Saved: results/img/fig_hurricanes_per_ground.png")
