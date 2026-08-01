################################################################################
# Figure: Map of fishing grounds by gear type
################################################################################
#
# Juan Carlos Villasenor-Derbez
# juancvd@stanford.edu
#
# Produces:
#   - results/img/fig_grounds_map.png
#
# Inputs:
#   data/output/fishing_grounds.rds
#
################################################################################

## SET UP ######################################################################

pacman::p_load(
  here,
  tidyverse,
  sf,
  rnaturalearth
)

sf_use_s2(FALSE)

dir.create(here("results/img"), showWarnings = FALSE, recursive = TRUE)

fishing_grounds <- read_rds(here("data/output/fishing_grounds.rds"))

gear_labels <- c(shrimp_trawl = "Shrimp trawl",
                 set_longline = "Set longline",
                 drifting_longline = "Drifting longline",
                 small_pelagic_purse_seine = "Purse seine",
                 tuna_purse_seine = "Tuna purse seine")

grounds <- fishing_grounds |> filter(fg_hours > 0)

## MAP #########################################################################

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

message("Saved: results/img/fig_grounds_map.png")
