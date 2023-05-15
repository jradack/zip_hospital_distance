# This script merges in the ZIP codes to the google maps distance matrices.

source("code/functions.r")

# Run the distance matrix function
sapply(states, run_dist_mat)
