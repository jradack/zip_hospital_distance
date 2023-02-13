# Plot map of ZCTAs and three versions of centroids
# 1. Text version of centroids
# 2. Centroid computed by sf function and shapefile polygons
# 3. Population-weighted centroids

library(sf)

zcta <- st_read("\\\\chop.edu/researchprd/CPHD/5. Data Support/Geographic Data/SHP files/ZCTA/2020/tl_2020_us_zcta520.shp")
pwc <- read.csv("data/centroids/PA_2020_pwc.csv")

state <- "PA"

in_pa <- function(zcta_id){
  head_val <- as.numeric(substr(zcta_id,1,3))
  ifelse(150 <= head_val & head_val <= 196, TRUE, FALSE)
}

# PA map
pa_map <- zcta[in_pa(zcta$ZCTA5CE10),]
# Highlight region
region <- zcta[zcta$ZCTA5CE10 == "17745",]
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

png("output/PA_centroids_map.png", width = 1440, height = 1440)
plot(st_geometry(pa_map), axes = TRUE)
plot(st_geometry(region), col = 'pink', add = TRUE)
# plot(pa_centroids, pch = 20, col = 'blue', cex = 0.5, add = TRUE)
plot(b, pch = 20, col = '#086fc4', cex = 0.5, add = TRUE)
plot(pwc_geom, pch = 20, col = '#cf3232', cex = 0.5, add = TRUE)
dev.off()


# Calculate average distance between the unweighted and pop-weighted centroids
zcta_cap <- intersect(pwc$GEOID_ZCTA5_20, a$ZCTA5CE10)
zcta_cap <- sort(zcta_cap)
a <- a[a$ZCTA5CE10 %in% zcta_cap,]
a <- a[order(a$ZCTA5CE10),]
pwc <- pwc[pwc$GEOID_ZCTA5_20 %in% zcta_cap,]
pwc <- pwc[order(pwc$GEOID_ZCTA5_20),]

centroid_dists <- st_distance(a, pwc, by_element = TRUE)

png("output/pa_distance_histogram.png")
hist(centroid_dists, xlab = "Distances between Weighted and Unweighted Centroids")
dev.off()
summary(centroid_dists)

# which ZCTA had the largest difference
zcta_cap[which(centroid_dists == max(centroid_dists))]

