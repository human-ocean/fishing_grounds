#' Detect the elbow (knee) of a sorted distance curve using the simplified
#' kneedle method (maximum perpendicular distance from the line connecting the
#' first and last points).
#'
#' @param sorted_dists Numeric vector of kNN distances sorted in ascending order
#' @return The distance value at the detected elbow
find_elbow <- function(sorted_dists) {
  n <- length(sorted_dists)
  if (n < 3) return(sorted_dists[n])

  x <- seq(0, 1, length.out = n)
  y <- (sorted_dists - min(sorted_dists)) /
    (max(sorted_dists) - min(sorted_dists) + .Machine$double.eps)

  dx <- x[n] - x[1]
  dy <- y[n] - y[1]
  denom <- sqrt(dx^2 + dy^2)
  perp_dist <- abs(dy * x - dx * y + x[n] * y[1] - y[n] * x[1]) / denom

  sorted_dists[which.max(perp_dist)]
}
