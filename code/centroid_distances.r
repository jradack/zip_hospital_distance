# Script for analyzing deviations between weighted and unweighted ZCTA centroids
#
#
#

library(ggplot2)
library(units)

source("code/functions.r")

# Load data
states <- c("CA", "CO", "FL", "LA", "MA", "MI", "NJ", "NY", "PA", "SC", "VA")
# centroid_dists_ma <- centroid_distances("MA")
centroid_dists <- do.call(rbind,lapply(states, centroid_distances))

formatter <- function(...){
  function(x) format(x, ..., scientific = T, digit = 2)
}

centroid_dist_plot <- ggplot(centroid_dists, aes(x = dists)) + 
  geom_histogram(aes(y = ..density..), colour = 1, fill = "white") +
  geom_density(color = "red") + 
  facet_wrap(~ state, scales = "free") +
  scale_y_continuous(labels = formatter(nsmall = 1)) +
  labs(title = "Histogram and density of distances between weighted and unweighted centroids by state",
       x = "Distance")
ggsave("output/centroid_dist_plot.png", centroid_dist_plot, width = 10, height = 6)

# sum_tab <- do.call(rbind, tapply(centroid_dists$dists, centroid_dists$state, summary))
sum_tab <- do.call(rbind, tapply(centroid_dists$dists, centroid_dists$state, quantile, probs = c(0,0.05,0.25,0.5,0.75,0.95,1)))
round(sum_tab, 1)

# which ZCTA had the largest difference
zcta_cap[which(centroid_dists == max(centroid_dists))]
