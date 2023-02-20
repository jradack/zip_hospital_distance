##############################################################
# Set of functions for the Hospital - ZIP distance project
##############################################################

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
  file_name <- paste0("data/weighted_centroids/", state, "_", year, "_pwc.csv")
  data.table::fwrite(cb_weighted_centroids, file_name)
}

# Function determines if a ZCTA belongs to Pennsylvania
in_pa <- function(zcta_id){
  head_val <- as.numeric(substr(zcta_id,1,3))
  ifelse(150 <= head_val & head_val <= 196, TRUE, FALSE)
}

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
  pwc <- data.table::fread(paste0("data/weighted_centroids/", state, "_2020_pwc.csv"),
                           colClasses = c("numeric","character","numeric","numeric"))
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
  centroid_dists <- data.frame(state = state, dists = centroid_dists)
  return(centroid_dists)
}

# Function sets up the long-form distance matrix between hospital and centroids
setup_dist_matrix <- function(){
  
}

