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


# Functions for processing latitude/longitude
# Converts string latitude-longitude into numeric
get_lat_lon <- function(val){
  pos_neg <- ifelse(substr(val,1,1) == "-", -1, 1)
  val_num <- as.numeric(regmatches(val,gregexpr("[[:digit:]]+\\.*[[:digit:]]*",val)))
  return(pos_neg * val_num)
}

# Convert latitude and longitude to Cartesian xyz coordinates
coord_to_cartesian <- function(lat, lon, r = 6371){
  lat <- lat * pi / 180
  lon <- lon * pi / 180
  x <- r * cos(lat) * cos(lon)
  y <- r * cos(lat) * sin(lon)
  z <- r * sin(lat)
  
  return(data.frame(x = x, y = y, z = z))
}

# Convert Cartesian coordinates to latitude/longitude
cartesian_to_coord <- function(x, y, z, r = 6371){
  lat <- asin(z/r)
  lon <- atan2(y,x)
  
  lat <- lat * 180 / pi
  lon <- lon * 180 / pi
  
  return(data.frame(lat = lat, lon = lon))
}

weighted_mean <- function(x, w){
  if(sum(w) == 0){
    return(mean(x, na.rm = TRUE))
  }
  weighted.mean(x, w, na.rm = TRUE)
}

# Function for calculating the population-weighted centroid for ZCTA based on census block
pop_weight_centroid <- function(state, year){
  state_fips <- c("CA" = "06", "CO" = "08", "FL" = "12", "LA" = "22",
                  "MA" = "25", "MI" = "26", "NJ" = "34", "NY" = "36",
                  "PA" = "42", "SC" = "45", "VA" = "51")
  state_fips_num <- state_fips[state]
  
  # Setup - drop geometry (since centroid lat/lon are included as columns), convert to 
  #         data.table, and drop irrelevant columns
  file_name <- paste0("tl_", year, "_", state_fips_num, "_tabblock20")
  cb_shp <- st_read(paste0("data/raw/", file_name, "/", file_name, ".shp"))
  
  # Using text columns - drop geometry, convert to data.table, keep relevant columns, convert lat/lon to Cartesian xyz
  # cb_shp <- st_drop_geometry(cb_shp)
  # cb_shp <- data.table::setDT(cb_shp[,c("STATEFP20", "GEOID20", "INTPTLAT20", "INTPTLON20", "POP20")])
  # cb_weighted_centroids <- cb_shp[,c("x","y","z") := coord_to_cartesian(get_lat_lon(INTPTLAT20), get_lat_lon(INTPTLON20))]
  
  # Computational method - compute centroids, convert to data.table, keep relevant columns, convert lat/lon to Cartesian xyz
  cat("Computing centroids...\n")
  cb_shp <- st_centroid(cb_shp)
  cb_shp <- data.table::setDT(cb_shp)
  cb_shp <- cb_shp[, c("lon","lat") := data.frame(st_coordinates(geometry))]
  cb_shp <- cb_shp[,c("STATEFP20", "GEOID20", "lat", "lon", "POP20")]
  cb_weighted_centroids <- cb_shp[,c("x","y","z") := coord_to_cartesian(lat, lon)]
  
  # Merge ZCTA GEOID
  cb_weighted_centroids <- merge(cb_weighted_centroids, zcta_cb_cw, by.x = "GEOID20", by.y = "GEOID_TABBLOCK_20")
  
  # Calculate the population-weighted mean for xyz, grouped by ZCTA
  cat("Computing population-weighted centroids...\n")
  cb_weighted_centroids <- cb_weighted_centroids[, lapply(.SD, weighted_mean, w = POP20), by = GEOID_ZCTA5_20, .SDcols = c("x","y","z")]
  
  # convert the averaged xyz back to lat/lon
  cb_weighted_centroids <- cb_weighted_centroids[,c("lat_mean", "lon_mean") := cartesian_to_coord(x,y,z)]
  
  # Drop row where the ZCTA is missing
  cb_weighted_centroids <- cb_weighted_centroids[GEOID_ZCTA5_20 != ""]
  
  return(cb_weighted_centroids[,c("GEOID_ZCTA5_20", "lat_mean", "lon_mean")])
}

# Runs the pop_weight_centroid function for a state and year, saving the output
run_pwc <- function(state, year){
  cb_weighted_centroids <- pop_weight_centroid(state, year)
  file_name <- paste0("data/centroids/", state, "_", year, "_pwc.csv")
  write.csv(cb_weighted_centroids, file_name)
}


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

states <- c("CA", "CO", "FL", "LA", "MA", "MI", "NJ", "NY", "PA", "SC", "VA")
sapply(states, function(x) run_pwc(x, 2020))
# run_pwc("PA", 2020)
# a <- pop_weight_centroid("PA", 2020)

# Calculate ZCTA unweighted centroids
zcta_centroids <- st_centroid(zcta)
zcta_centroids <- zcta_centroids[,c("ZCTA5CE20","geometry")]
st_write(zcta_centroids, "data/unweighted_centroids/zcta_unweighted_centroids.shp", delete_layer = TRUE)
