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
  state_fips <- c("AZ" = "04", "CA" = "06", "CO" = "08", "DE" = "10", "FL" = "12",
                  "LA" = "22", "MD" = "24", "MA" = "25", "MI" = "26", "NV" = "32",
                  "NJ" = "34", "NY" = "36", "OR" = "41", "PA" = "42",
                  "SC" = "45", "TN" = "47", "VA" = "51", "WV" = "54")
  
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
distance_matrix <- function(state, centroid = c("weighted", "unweighted")){
  cat(paste0("Running function for ", state, "...\n"))
  
  centroid <- match.arg(centroid)
  
  cat("Reading in data...\n")
  # Read in the CRS information
  crs <- readRDS("data/crs.rds")
  
  # Read in the centroids
  if(centroid == "weighted"){
    cents <- fread(paste0("data/weighted_centroids/", state, "_2020_pwc.csv"),
                   colClasses = c("character", rep("numeric", 2)))
    cents <- st_as_sf(cents, coords = c("lon_mean", "lat_mean"),
                      crs = crs, agr = "constant")
  } else if(centroid == "unweighted"){
    cents <- read_sf("data/unweighted_centroids/zcta_unweighted_centroids.shp")
    cents <- cents[filter_unweighted_centroids(cents$ZCTA5CE20, state),]
  }
  colnames(cents) <- c("zcta_geoid", "geometry")
  
  # Read in hospital centroids
  hospitals <- fread("data/hospital_unique_aha_20230223.csv",
                     colClasses = c("ID"="character","FIPS_STATE"="character"))
  hospitals_sf <- st_as_sf(hospitals, coords = c("longitude","latitude"),
                           crs = crs)
  hospitals_sf <- hospitals_sf[which(hospitals_sf$state == state),]
  colnames(hospitals_sf) <- c("hospital_id", "year", "fips_state", "state", "geometry")
  
  # Calculate Haversine distance
  cat("Computing distance matrix...\n")
  dist_mat <- st_distance(cents, hospitals_sf)
  rownames(dist_mat) <- cents$zcta_geoid
  colnames(dist_mat) <- hospitals_sf$hospital_id
  
  # Create long-form distance matrix, merge in columns and clean up
  cat("Cleaning and returning output...\n")
  dist_mat_long <- as.data.frame(as.table(dist_mat))
  colnames(dist_mat_long) <- c("zcta_geoid", "hospital_id", "haversine_dist_m")
  dist_mat_long[c("zcta_geoid", "hospital_id")] <- sapply(dist_mat_long[c("zcta_geoid", "hospital_id")], as.character)
  
  dist_mat_long <- merge(dist_mat_long, cents, by = "zcta_geoid")
  dist_mat_long[,c("zcta_longitude", "zcta_latitude")] <- st_coordinates(dist_mat_long$geometry)
  dist_mat_long <- subset(dist_mat_long, select = -c(geometry))
  
  dist_mat_long <- merge(dist_mat_long, hospitals_sf, by = "hospital_id")
  dist_mat_long[,c("hospital_longitude", "hospital_latitude")] <- st_coordinates(dist_mat_long$geometry)
  dist_mat_long <- subset(dist_mat_long, select = -c(geometry))
  
  # Get ZIP code labels using ZCTA - ZIP crosswalk
  # zip_zcta_cw <- data.table::fread("data/raw/ZIPCodetoZCTACrosswalk_2010_2021.csv",
  #                                  colClasses = c(rep('character',6),'numeric')) |>
  #   dplyr::filter(year == 2020) |>
  #   dplyr::select(ZIP_CODE, ZCTA) |>
  #   dplyr::rename(zip_code = ZIP_CODE)
  
  # dist_mat_long <- merge(dist_mat_long, zip_zcta_cw, all.x = TRUE,
  #                        by.x = "zcta_geoid", by.y = "ZCTA")
  
  # Clean up column order
  # ordered_col <- c("state", "fips_state", "year", "hospital_id", "hospital_latitude",
  #                  "hospital_longitude", "zcta_geoid", "zip_code", "zcta_latitude",
  #                  "zcta_longitude", "haversine_dist_m")
  ordered_col <- c("state", "fips_state", "year", "hospital_id", "hospital_latitude",
                   "hospital_longitude", "zcta_geoid", "zcta_latitude",
                   "zcta_longitude", "haversine_dist_m")
  dist_mat_long <- dist_mat_long[,ordered_col]
  
  return(dist_mat_long)
}

# Run the distance_matrix function for a list of states
run_dist_mat <- function(state, centroid = c("weighted", "unweighted")){
  centroid = match.arg(centroid)
  dist_mat_long <- distance_matrix(state, centroid)
  file_name <- paste0("data/distance_matrix/", state, "_", centroid, "_dist_mat.csv")
  data.table::fwrite(dist_mat_long, file_name)
}

# Function for merging ZIP code into the distance matrix with google maps data
merge_zip <- function(state){
  dist_mat_long <- data.table::fread(
    paste0("data/distance_matrix_gmaps/", state, '_weighted_gmaps_dist_mat.csv'),
    colClasses = list(character=c("state","fips_state","hospital_id","zcta_geoid"))
  )
  
  # Get ZIP code labels using ZCTA - ZIP crosswalk
  zip_zcta_cw <- data.table::fread("data/raw/ZIPCodetoZCTACrosswalk_2010_2021.csv",
                                   colClasses = c(rep('character',6),'numeric')) |>
    dplyr::filter(year == 2020) |>
    dplyr::select(ZIP_CODE, ZCTA) |>
    dplyr::rename(zip_code = ZIP_CODE)
  
  dist_mat_long <- merge(dist_mat_long, zip_zcta_cw, all.x = TRUE,
                         by.x = "zcta_geoid", by.y = "ZCTA")
  dist_mat_long <- as.data.frame(dist_mat_long)
  
  ordered_col <- c("state", "fips_state", "year", "hospital_id", "hospital_latitude",
                   "hospital_longitude", "zcta_geoid", "zip_code", "zcta_latitude",
                   "zcta_longitude", "haversine_dist_m", "distance_driving_m",
                   "duration_driving_sec", "distance_transit_m", "duration_transit_sec")
  dist_mat_long <- dist_mat_long[,ordered_col]
  return(dist_mat_long)
}

run_merge_zip <- function(state){
  dist_mat_long <- merge_zip(state, centroid)
  file_name <- paste0("data/distance_matrix_gmaps/", state, "_ZIP_weighted_gmaps_dist_mat.csv")
  data.table::fwrite(dist_mat_long, file_name)
}


# Function for selecting a CBSA, with user-input in cases of ambiguity of selection
get_cbsa <- function(area_name, cbsa_shp){
  # Get list of matching CBSA names
  matches <- cbsa_shp[grep(area_name, cbsa_shp$NAME, ignore.case = TRUE),]
  matches_names <- matches$NAME
  if (length(matches_names) == 0) {
    stop("Could not find a matching CBSA.")
  } else if (length(matches_names) > 1) {
    # In case of multiple matches, let user choose the desired CBSA
    cat("Found multiple matches. Please select one:\n")
    cat(paste0('[', seq(length(matches_names)), '] ', matches_names), sep = "\n")
    while(TRUE){
      selection <- suppressWarnings(as.integer(readline("Choice: ")))
      if(selection %in% seq(length(matches_names))){
        break
      } else {
        cat("Improper input. Please try again.\n")
      }
    }
    return(matches[selection,])
  } else {
    return(matches)
  }
}

# Finds the population-weighted centroids that belong to a CBSA
find_zcta_in_cbsa <- function(area_name, cbsa_shp, crs) {
  # Get location name
  location <- get_cbsa(area_name, cbsa_shp)
  
  # Get the states out of the matched location
  states <- str_split(location$NAME, ', ', simplify = TRUE)[1,2] |>
    str_split('-', simplify = TRUE) |>
    as.vector()
  
  # Load population-weighted centroids for the matched states and combine
  pwc <- lapply(states, 
                function(x) data.table::fread(paste0("data/weighted_centroids/", x, "_2020_pwc.csv"),
                                              colClasses = c("character", "numeric", "numeric"))
  ) |> 
    data.table::rbindlist() |>
    st_as_sf(coords = c("lon_mean","lat_mean"), crs = crs)
  
  # Compute the intersection between the centroids and CBSA polygon
  a <- st_intersects(pwc, location)
  b <- unlist(lapply(a, function(x) length(x) > 0))
  pwc_matches <- pwc[b,] |>
    st_drop_geometry()
  
  return(pwc_matches)
}

# Function for computing the Haversine distance matrix between hospitals within a state
distance_matrix_hospital <- function(state) {
  cat(paste0("Running function for ", state, "...\n"))
  
  # Load CRS and hospitals dataset
  cat("Reading in data...\n")
  crs <- readRDS("data/crs.rds")
  hospitals <- fread("data/hospital_unique_aha_20230223.csv",
                     colClasses = c("ID"="character","FIPS_STATE"="character"))
  
  # Convert to sf object, filter to state
  hospitals_sf <- st_as_sf(hospitals, coords = c("longitude","latitude"),
                           crs = crs)
  hospitals_sf <- hospitals_sf[which(hospitals_sf$state == state),]
  colnames(hospitals_sf) <- c("hospital_id", "year", "fips_state", "state", "geometry")
  
  # Compute Haversine distance in meters
  cat("Computing distance matrix...\n")
  hospital_dist_mat <- st_distance(hospitals_sf, hospitals_sf)
  rownames(hospital_dist_mat) <- colnames(hospital_dist_mat) <- hospitals_sf$hospital_id
  
  # Convert matrix into long dataset, clean up
  cat("Cleaning and returning output...\n")
  hospital_dist_mat_long <- as.data.frame(as.table(hospital_dist_mat))
  colnames(hospital_dist_mat_long) <- c("src_hospital_id", "dest_hospital_id", "haversine_dist_m")
  
  return(hospital_dist_mat_long)
}

# Run the distance_matrix_hospital function for a list of states
run_dist_mat_hosp <- function(state){
  dist_mat_long_hosp <- distance_matrix_hospital(state)
  file_name <- paste0("data/distance_matrix_hospital/", state, "_dist_mat_hosp.csv")
  data.table::fwrite(dist_mat_long_hosp, file_name)
}

##############################################################
# Global variable definitions
##############################################################
states <- c("AZ", "CA", "CO", "FL", "LA", "MA", "MI", "NV",
            "NJ", "NY", "OR", "PA", "SC", "TN", "VA", "WV")
