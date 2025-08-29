# This script creates the pairwise hospital datasets used for computing driving distance between hospitals in the same state

library(sf)
library(data.table)
source("code/functions.r")

# Run the distance matrix function
sapply(states, run_pairwise_hosp)
