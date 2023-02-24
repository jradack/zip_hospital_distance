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
sapply(states, function(x) run_dist_mat(x, "weighted"))
# test_dist_mat <- distance_matrix("AZ", "weighted")
