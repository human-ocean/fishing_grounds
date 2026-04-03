#' Compute vessel-specific DBSCAN minPts based on domain knowledge.
#'
#' Rule: a fishing ground has at least 5 hours of activity on at least 5 days
#' per year.  At ~1 VMS ping per hour this translates to 25 pings per
#' vessel-year of data.
#'
#' @param n_years Numeric vector — years of data per vessel
#' @return Integer vector of minPts values
BASE_MINPTS <- 25L

compute_minpts <- function(n_years) {
  as.integer(ceiling(BASE_MINPTS * pmax(n_years, 1)))
}
