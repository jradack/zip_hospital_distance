# Script for analyzing deviations between weighted and unweighted ZCTA centroids
#
#
#

# Filters a list of ZCTA GEOIDs to the state whose abbreviation is passed
filter_unweighted_centroids <- function(zcta_id, state_abb){
  zip_code_prefixes <- data.table::fread("data/zip_code_prefix.csv",
                                         colClasses = c(rep("character",4), rep("numeric",3)))
  state_zip_prefix <- zip_code_prefixes[zip_code_prefixes$state == state_abb, "zip_prefix"]$zip_prefix
  zcta_id_head <- substr(zcta_id,1,3)
  return(zcta_id_head %in% state_zip_prefix)
}

# Function for computing distances between the weighted and unweighted centroid
centroid_distances <- function(state){
  uwc <- st_read("data/unweighted_centroids/zcta_unweighted_centroids.shp")
  uwc <- uwc[filter_unweighted_centroids(uwc$ZCTA5CE20, state),]
  pwc <- read.csv(paste0("data/weighted_centroids/", state, "_2020_pwc.csv"))
  pwc <- st_as_sf(pwc, coords = c("lon_mean", "lat_mean"),
                  crs = st_crs(uwc), agr = "constant")
  
  # Calculate average distance between the unweighted and pop-weighted centroids
  zcta_cap <- intersect(pwc$GEOID_ZCTA5_20, uwc$ZCTA5CE20)
  zcta_cap <- sort(zcta_cap)
  uwc <- uwc[uwc$ZCTA5CE20 %in% zcta_cap,]
  uwc <- uwc[order(uwc$ZCTA5CE20),]
  pwc <- pwc[pwc$GEOID_ZCTA5_20 %in% zcta_cap,]
  pwc <- pwc[order(pwc$GEOID_ZCTA5_20),]
  centroid_dists <- st_distance(uwc, pwc, by_element = TRUE)
  return(centroid_dists)
}

# Load data
states <- c("CA", "CO", "FL", "LA", "MA", "MI", "NJ", "NY", "PA", "SC", "VA")
centroid_dists_ma <- centroid_distances("MA")
centroid_dists <- lapply(states, centroid_distances)

png("output/pa_distance_histogram.png")
hist(centroid_dists, xlab = "Distances between Weighted and Unweighted Centroids")
plot(density(centroid_dists), add = TRUE)
dev.off()
summary(centroid_dists)

# which ZCTA had the largest difference
zcta_cap[which(centroid_dists == max(centroid_dists))]
