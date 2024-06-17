# This script creates a cut of the PA distance matrix limited to the following:
# start locations (find a good ZIP code centroid):
# - North Philly (19133)
# - South Philly (19148)
# - West Philly (19143)
# - Center City (19107)
# - Northeast Philly (19144)
# - Wynnewood (19096)
# 
# destination hospitals:
# - CHOP (6231730)
# - Jefferson (6230043)
# - Presby (6232170)
# - Lankenau (6231970)
# 
# departure times:
# - wednesday, friday, sunday
# - every hour
# 
# transit and driving times
# 
# total calculations: 6 * 4 * 24 * 3 * 2 = 3456

rm(list=ls())

library(tidyverse)

# Read in PA distance matrix
pa_dist_mat_raw <- data.table::fread(
  "data/distance_matrix_gmaps/PA_weighted_gmaps_dist_mat.csv",
  colClasses = list(character = c("fips_state", "hospital_id", "zcta_geoid", "zip_code"))
  )

# Perform data filtering and augmenting datetime
pa_dist_mat <- pa_dist_mat_raw %>%
  filter(
    hospital_id %in% c("6231730", "6230043", "6232170", "6231970"),
    zip_code %in% c("19133", "19148", "19143", "19107", "19144", "19096")
  ) %>%
  crossing(
    expand.grid(
      date = paste0("2024-06-", c("26", "28", "30")),
      time = paste0(sprintf("%0.2d", 1:12), ":00"),
      am_pm = c("AM", "PM")
    )
  ) %>%
  mutate(
    depTime = paste(date, time, am_pm),
    hospital_id_label = case_match(
      hospital_id,
      "6231730" ~ "CHOP",
      "6230043" ~ "Thomas Jefferson University Hospital",
      "6232170" ~ "Penn Presbyterian Medical Center",
      "6231970" ~ "Lankenau Hospital"
    ),
    zip_code_label = case_match(
      zip_code,
      "19133" ~ "North Philadelphia",
      "19148" ~ "South Philadelphia",
      "19143" ~ "West Philadelphia",
      "19107" ~ "Center City",
      "19144" ~ "Northeast Philadelphia",
      "19096" ~ "Wynnewood"
    )
  ) %>%
  rename_with(
    .fn = ~ paste0("orig_", .x),
    .cols = c(distance_driving_m, duration_driving_sec, distance_transit_m, duration_transit_sec)
  ) %>%
  select(
    -c(date, time, am_pm)
  ) %>%
  arrange(
    hospital_id, zip_code, strptime(depTime, format = "%Y-%m-%d %I:%M %p")
  )

# Write out dataset
data.table::fwrite(
  pa_dist_mat,
  "data/gmaps_test/pa_dist_mat_test.csv"
)
