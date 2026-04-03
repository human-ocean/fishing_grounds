#' Run DBSCAN on a single vessel's fishing tracks and return cluster-level
#' summaries with convex-hull geometries.
#'
#' @param data Data frame with columns: vessel_rnpa, gear_type, lon, lat, hours, date
#' @param eps DBSCAN neighbourhood radius in metres
#' @param min_pts DBSCAN minimum points threshold
#' @return An sf tibble with one row per cluster (or a plain tibble with zeros
#'   if clustering is not possible)
get_extensive <- function(data, eps, min_pts) {
  npts <- nrow(data)

  grounds <- data |>
    dplyr::select(vessel_rnpa) |>
    dplyr::distinct() |>
    dplyr::mutate(fg_hours = 0, n_pts = npts, fg_area_km = 0)


  if (npts >= min_pts) {
    spat <- data |>
      sf::st_as_sf(coords = c("lon", "lat"), crs = "EPSG:4326") |>
      project_to_metric()

    clusters <- spat |>
      sf::st_coordinates() |>
      dbscan::dbscan(eps = eps, minPts = min_pts)

    n_clust <- max(clusters$cluster)

    if (n_clust > 0) {
      grounds <- spat |>
        dplyr::mutate(cluster = clusters$cluster) |>
        dplyr::filter(cluster != 0) |>
        dplyr::group_by(vessel_rnpa, gear_type, cluster) |>
        dplyr::summarize(
          fg_hours = sum(hours, na.rm = TRUE),
          n_pts = dplyr::n(),
          first_use = min(date, na.rm = TRUE),
          n_visits = dplyr::n_distinct(date, na.rm = TRUE),
          .groups = "drop"
        ) |>
        sf::st_convex_hull() |>
        sf::st_transform(crs = "EPSG:4326") |>
        dplyr::mutate(fg_area_km = as.numeric(sf::st_area(geometry)) / 1e6) |>
        dplyr::select(
          vessel_rnpa, gear_type, cluster,
          first_use, fg_area_km, fg_hours, n_pts, n_visits
        )
    }
  }

  grounds
}
