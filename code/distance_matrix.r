# This script computes the distance matrix between the ZCTA centroid
# and hospital locations.
#


library(sf)
library(data.table)
source("code/functions.r")

# Get and save CRS
uwc <- st_read("data/unweighted_centroids/zcta_unweighted_centroids.shp")
crs <- st_crs(uwc)
saveRDS(crs, "data/crs.rds")

# Run the distance matrix function
states <- c("CA", "CO", "FL", "LA", "MA", "MI", "NJ", "NY", "PA", "SC", "VA")
run_dist_mat(states, "weighted")
# pa_dist_mat <- distance_matrix("PA", "weighted")
