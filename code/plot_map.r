# Plot map of ZCTAs and three versions of centroids
# 1. Text version of centroids
# 2. Centroid computed by sf function and shapefile polygons
# 3. Population-weighted centroids

library(sf)

zcta <- st_read("\\\\chop.edu/researchprd/CPHD/5. Data Support/Geographic Data/SHP files/ZCTA/2018/tl_2018_us_zcta510.shp")
pwc <- read.csv("data/centroids/PA_2020_weighted_centroids.csv")

state <- "PA"

in_pa <- function(zcta_id){
  head_val <- as.numeric(substr(zcta_id,1,3))
  ifelse(150 <= head_val & head_val <= 196, TRUE, FALSE)
}

# PA map
pa_map <- zcta[in_pa(zcta$ZCTA5CE10),]
# Centroids from st_centroids function
a <- st_centroid(pa_map)
b <- st_geometry(a)
# Centroids from text columns
pa_centroids <- data.frame(LAT10_NUM = get_lat_lon(pa_map$INTPTLAT10),
                           LON10_NUM = get_lat_lon(pa_map$INTPTLON10))
pa_centroids <- st_as_sf(pa_centroids, coords = c("LON10_NUM", "LAT10_NUM"), 
                         crs = st_crs(a), agr = "constant")
pa_centroids <- st_geometry(pa_centroids)
# Population weighted centroids
pwc$GEOID_ZCTA5_20 <- as.character(pwc$GEOID_ZCTA5_20)
pwc <- pwc[pwc$GEOID_ZCTA5_20 %in% pa_map$ZCTA5CE10,]
pwc <- pwc[!is.na(pwc$lat_mean),]
pwc <- st_as_sf(pwc, coords = c("lon_mean", "lat_mean"),
                crs = st_crs(pa_map), agr = "constant")
pwc_geom <- st_geometry(pwc)

plot(st_geometry(pa_map), axes = TRUE)
plot(pa_centroids, pch = 20, col = 'blue', cex = 0.5, add = TRUE)
plot(b, pch = 20, col = 'red', cex = 0.5, add = TRUE)
plot(pwc_geom, pch = 20, col = 'purple', cex = 0.5, add = TRUE)




