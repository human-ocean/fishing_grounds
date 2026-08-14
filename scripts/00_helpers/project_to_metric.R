#' Project an sf object to an appropriate metric CRS.
#'
#' Uses UTM when data spans at most two adjacent zones; otherwise falls back to
#' an Azimuthal Equidistant projection centered on the data centroid.
#'
#' @param spat An sf object in geographic coordinates (EPSG:4326)
#' @return The same sf object transformed to a metric CRS (metres)
project_to_metric <- function(spat) {
  coords <- sf::st_coordinates(spat)
  lons <- coords[, "X"]
  lats <- coords[, "Y"]

  lon_to_utm_zone <- function(lon) as.integer(floor((lon + 180) / 6) + 1L)

  zones <- sort(unique(lon_to_utm_zone(lons)))
  centroid_lon <- mean(lons, na.rm = TRUE)
  centroid_lat <- mean(lats, na.rm = TRUE)
  centroid_zone <- lon_to_utm_zone(centroid_lon)

  if (length(zones) <= 2 &&
      (length(zones) == 1 || abs(zones[2] - zones[1]) == 1)) {
    hemisphere_base <- if (centroid_lat >= 0) 32600L else 32700L
    crs <- sf::st_crs(hemisphere_base + centroid_zone)
  } else {
    aeqd_proj <- sprintf(
      "+proj=aeqd +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs",
      centroid_lat, centroid_lon
    )
    crs <- sf::st_crs(aeqd_proj)
  }

  sf::st_transform(spat, crs = crs)
}
