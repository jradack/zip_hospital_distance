################################################################################
## Program: C:/Users/radackj/Documents/projects/zcta_centroid/code/pop_weight_centroid.R
## Date: 2023-02-07
## Created by: Josh Radack
## Description: Calculate population-weighted centroids for ZCTAs based on
##              census blocks
## Input: 
################################################################################

library(data.table)
library(sf)


source('code/functions.r')

# State FIPS codes where we have hospital data
# state_fips <- c("CA" = "06", "CO" = "08", "MI" = "26", "MO" = "29", 
#                 "NV" = "32", "NY" = "36", "OR" = "41", "PA" = "42",
#                 "SC" = "45", "VA" = "51")

# Load ZCTA - census block crosswalk, only keep the ZCTA and census block ID columns
zcta_cb_cw <- data.table::fread("data/raw/tab20_zcta520_tabblock20_natl.txt",
                                colClasses = c(rep("character",3), rep("numeric",2),
                                               rep("character",6), rep("numeric",2),
                                               rep("character",2), rep("numeric",2)),
                                select = c("GEOID_ZCTA5_20", "GEOID_TABBLOCK_20"))

states <- c("AZ", "CA", "CO", "FL", "LA", "MA", "MI", "NV",
            "NJ", "NY", "OR", "PA", "SC", "TN", "VA", "WV")
sapply(states, function(x) run_pwc(x, 2020))
# run_pwc("PA", 2020)
# a <- pop_weight_centroid("PA", 2020)

# Calculate ZCTA unweighted centroids
zcta_centroids <- st_centroid(zcta)
zcta_centroids <- zcta_centroids[,c("ZCTA5CE20","geometry")]
st_write(zcta_centroids, "data/unweighted_centroids/zcta_unweighted_centroids.shp", delete_layer = TRUE)
