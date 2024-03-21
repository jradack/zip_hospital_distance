# This script computes the distance matrix between hospital locations within the same state

library(sf)
library(data.table)
source("code/functions.r")

# Run the distance matrix function
sapply(states, run_dist_mat_hosp)
