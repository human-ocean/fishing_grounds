################################################################################
# Space utilization analysis
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Descriptive analysis of fishing ground use:
#   - Total fishing area per vessel and gear
#   - Overlap / shared use of grounds across vessels
#   - Spatial concentration (Gini of fishing hours across grounds)
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  sf,
  ineq
)

sf_use_s2(FALSE)

fishing_grounds <- read_rds(here("data/output/fishing_grounds.rds"))

# Keep only valid grounds with positive fishing hours
grounds <- fishing_grounds |>
  filter(fg_hours > 0)

## PER-VESSEL AREA #############################################################

vessel_area <- grounds |>
  st_drop_geometry() |>
  group_by(gear_type, vessel_rnpa) |>
  summarise(
    n_grounds = n(),
    total_area_km2 = sum(fg_area_km, na.rm = TRUE),
    total_fg_hours = sum(fg_hours, na.rm = TRUE),
    mean_ground_area_km2 = mean(fg_area_km, na.rm = TRUE),
    .groups = "drop"
  )

gear_area_summary <- vessel_area |>
  group_by(gear_type) |>
  summarise(
    n_vessels = n(),
    median_n_grounds = median(n_grounds),
    median_total_area_km2 = median(total_area_km2),
    mean_total_area_km2 = mean(total_area_km2),
    median_fg_hours = median(total_fg_hours),
    .groups = "drop"
  )

message("--- Total fishing area by gear ---")
print(gear_area_summary)

## OVERLAP / SHARED USE ########################################################

compute_gear_overlap <- function(gear_grounds) {
  vessels <- unique(gear_grounds$vessel_rnpa)
  if (length(vessels) < 2) return(tibble())

  vessel_polys <- gear_grounds |>
    group_by(vessel_rnpa) |>
    summarise(geometry = sf::st_union(geometry), .groups = "drop") |>
    sf::st_make_valid()

  pairs <- combn(seq_len(nrow(vessel_polys)), 2)

  purrr::map_dfr(seq_len(ncol(pairs)), \(i) {
    a <- vessel_polys[pairs[1, i], ]
    b <- vessel_polys[pairs[2, i], ]

    if (!sf::st_intersects(a, b, sparse = FALSE)[1, 1]) {
      return(tibble(
        vessel_a = a$vessel_rnpa,
        vessel_b = b$vessel_rnpa,
        intersection_km2 = 0,
        union_km2 = NA_real_,
        jaccard = 0
      ))
    }

    inter <- tryCatch(
      sf::st_intersection(a, b) |> sf::st_area() |> sum() |> as.numeric(),
      error = function(e) 0
    )
    union_area <- tryCatch(
      sf::st_union(a, b) |> sf::st_area() |> sum() |> as.numeric(),
      error = function(e) NA_real_
    )

    tibble(
      vessel_a = a$vessel_rnpa,
      vessel_b = b$vessel_rnpa,
      intersection_km2 = inter / 1e6,
      union_km2 = union_area / 1e6,
      jaccard = if (!is.na(union_area) && union_area > 0) inter / union_area else NA_real_
    )
  })
}

gear_groups <- grounds |>
  filter(!sf::st_is_empty(geometry)) |>
  group_by(gear_type) |>
  group_split()

gc()

overlap_results <- purrr::map_dfr(gear_groups, \(g) {
  gt <- unique(g$gear_type)
  message(sprintf("[%s] computing pairwise overlap (%d vessels) ...", gt, n_distinct(g$vessel_rnpa)))
  result <- compute_gear_overlap(g) |> mutate(gear_type = gt, .before = 1)
  gc()
  result
})

overlap_summary <- overlap_results |>
  group_by(gear_type) |>
  summarise(
    n_pairs = n(),
    mean_jaccard = mean(jaccard, na.rm = TRUE),
    median_jaccard = median(jaccard, na.rm = TRUE),
    frac_nonzero_overlap = mean(jaccard > 0, na.rm = TRUE),
    .groups = "drop"
  )

message("\n--- Pairwise overlap summary ---")
print(overlap_summary)

## SPATIAL CONCENTRATION (GINI) ################################################

gini_by_gear <- grounds |>
  st_drop_geometry() |>
  group_by(gear_type) |>
  summarise(
    gini_hours = ineq::Gini(fg_hours),
    gini_area = ineq::Gini(fg_area_km),
    .groups = "drop"
  )

message("\n--- Gini coefficients ---")
print(gini_by_gear)

## EXPORT ######################################################################

dir.create(here("data/processed"), showWarnings = FALSE, recursive = TRUE)

write_rds(vessel_area, here("data/processed/vessel_area.rds"))
write_rds(overlap_results, here("data/processed/pairwise_overlap.rds"))
write_rds(gini_by_gear, here("data/processed/gini_concentration.rds"))

message("\nSaved: data/processed/vessel_area.rds")
message("Saved: data/processed/pairwise_overlap.rds")
message("Saved: data/processed/gini_concentration.rds")
