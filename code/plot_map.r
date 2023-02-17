# Plot map of ZCTAs and three versions of centroids
# 1. Text version of centroids
# 2. Centroid computed by sf function and shapefile polygons
# 3. Population-weighted centroids

library(sf)

source("code/functions.r")

zcta <- st_read("\\\\chop.edu/researchprd/CPHD/5. Data Support/Geographic Data/SHP files/ZCTA/2020/tl_2020_us_zcta520.shp")
pwc <- read.csv("data/centroids/PA_2020_pwc.csv")

# PA map
pa_map <- zcta[in_pa(zcta$ZCTA5CE10),]
# Highlight region
region <- zcta[zcta$ZCTA5CE10 == "17745",]
# Centroids from st_centroids function
a <- st_centroid(pa_map)
b <- st_geometry(a)
# Population weighted centroids
pwc$GEOID_ZCTA5_20 <- as.character(pwc$GEOID_ZCTA5_20)
pwc <- pwc[pwc$GEOID_ZCTA5_20 %in% pa_map$ZCTA5CE10,]
pwc <- pwc[!is.na(pwc$lat_mean),]
pwc <- st_as_sf(pwc, coords = c("lon_mean", "lat_mean"),
                crs = st_crs(pa_map), agr = "constant")
pwc_geom <- st_geometry(pwc)

png("output/PA_centroids_map.png", width = 1440, height = 1440)
plot(st_geometry(pa_map), axes = TRUE)
plot(st_geometry(region), col = 'pink', add = TRUE)
plot(b, pch = 20, col = '#086fc4', cex = 0.5, add = TRUE)
plot(pwc_geom, pch = 20, col = '#cf3232', cex = 0.5, add = TRUE)
dev.off()
