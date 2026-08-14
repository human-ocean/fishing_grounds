################################################################################
# Figures and tables: space utilization and overlap
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Produces:
#   - results/img/fig_space_utilization.png
#   - results/img/fig_pairwise_overlap.png
#   - results/tab/gear_summary_table.tex
#   - results/tab/gini_concentration.tex
#
# Inputs:
#   data/processed/vessel_area.rds
#   data/processed/pairwise_overlap.rds
#   data/processed/gini_concentration.rds
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

vessel_area <- read_rds(here("data/processed/vessel_area.rds"))
overlap_results <- read_rds(here("data/processed/pairwise_overlap.rds"))
gini <- read_rds(here("data/processed/gini_concentration.rds"))

gear_labels <- c(shrimp_trawl = "Shrimp trawl",
                 set_longline = "Set longline",
                 drifting_longline = "Drifting longline",
                 small_pelagic_purse_seine = "Purse seine",
                 tuna_purse_seine = "Tuna purse seine")

## 1. SPACE UTILIZATION ########################################################

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

message("Saved: results/img/fig_space_utilization.png")

## 2. OVERLAP ##################################################################

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

  message("Saved: results/img/fig_pairwise_overlap.png")
}

## 3. SUMMARY TABLES ###########################################################

writeLines(
  knitr::kable(gini |> mutate(gear_type = gear_labels[gear_type]),
               format = "latex", booktabs = TRUE),
  here("results/tab/gini_concentration.tex")
)

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
  left_join(gini, by = "gear_type") |>
  mutate(gear_type = gear_labels[gear_type])

writeLines(
  knitr::kable(gear_table, format = "latex", booktabs = TRUE),
  here("results/tab/gear_summary_table.tex")
)

message("Saved: results/tab/gini_concentration.tex")
message("Saved: results/tab/gear_summary_table.tex")
