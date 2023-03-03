#-------------------------------------------------------------------------------
# Script for determining which core-based statistical area each of the 
# population-weighted centroids belongs to. 
# 
# Add functionality where you can specify a CBSA by name (through partial match?
# need a way to select if multiple options, possibly interactivel) and get all
# the ZCTAs that belong to it, which can then be mapped to ZIP codes using the
# ZCTA-ZIP crosswalk.
#-------------------------------------------------------------------------------

library(sf)
library(stringr)

# Load CBSA shape file and population-weighted centroids and set the CRS
cbsa_shp <- st_read("data/raw/tl_2020_us_cbsa/tl_2020_us_cbsa.shp")

crs <- readRDS("data/crs.rds")
pa_pwc <- data.table::fread("data/weighted_centroids/PA_2020_pwc.csv",
                            colClasses = c("character","numeric","numeric")) |>
  st_as_sf(coords = c("lon_mean","lat_mean"), crs = crs)

# Perform intersection and get the name and GEOID of the CBSA
a <- st_intersects(pa_pwc, cbsa_shp)
b <- lapply(a, function(x){
  if (length(x) == 0) {
    return(c(NA, "Missing"))
  } else {
    return(c(cbsa_shp$GEOID[x], cbsa_shp$NAME[x]))
  }
})
b <- as.data.frame(do.call(rbind, b))
colnames(b) <- c("cbsa_geoid", "cbsa_name")
pa_pwc_w_cbsa <- cbind(pa_pwc, b)

table(pa_pwc_w_cbsa$cbsa_name, useNA = "always")

# Function for selecting 
get_location <- function(area_name){
  matches <- cbsa_shp[grep(area_name, cbsa_shp$NAME, ignore.case = TRUE),]
  matches_names <- matches$NAME
  if (length(matches_names) == 0) {
    stop("Could not find a matching CBSA.")
  } else if (length(matches_names) > 1) {
    cat("Found multiple matches. Please select one:\n")
    cat(paste0('[', seq(length(matches_names)), '] ', matches_names), sep = "\n")
    selection = as.integer(readline("Choice: "))
    return(matches[selection,])
  } else {
    return(matches)
  }
}

get_location("Philadelphia")
get_location("Philadelphia-Dover")
get_location("PHILADELPHIA")
get_location("filadelfia")

# Select the population-weighted centroids from required states
find_match_locations <- function(area_name) {
  # Get location name
  location <- get_location(area_name)
  
  # Get the states out of the match location
  states <- str_split(location$NAME, ', ', simplify = TRUE)[1,2] |>
    str_split('-', simplify = TRUE) |>
    as.vector()
  # Load states
  pwc <- lapply(states, 
                function(x) data.table::fread(paste0("data/weighted_centroids/", x, "_2020_pwc.csv"),
                                              colClasses = c("character", "numeric", "numeric"))
                ) |> 
    data.table::rbindlist() |>
    st_as_sf(coords = c("lon_mean","lat_mean"), crs = crs)
  # Calculate the intersection
  a <- st_intersects(pwc, location)
  b <- unlist(lapply(a, function(x) length(x) > 0))
  pwc_matches <- pwc[b,] |>
    st_drop_geometry()
  
  return(pwc_matches)
}

philadelphia_zctas <- find_match_locations("Philadelphia-Camden-Wilmington")
