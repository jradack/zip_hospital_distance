##############################################################
# Name: code/transit_travel_time_visualization.r
# Date: 2024-06-27
# Created by: Josh Radack
# Purpose: Visualizes the transit time 
##############################################################

rm(list=ls())
library(tidyverse)

# Load data
gmaps_test_raw <- data.table::fread(
  "data/gmaps_test/pa_dist_mat_test_gmaps.csv",
  colClasses = list(character = c('hospital_id', 'zcta_geoid', 'zip_code'))
  )

# Do some data cleaning
gmaps_test <- gmaps_test_raw %>%
  mutate(
    # Error in one of the ZIP code labels
    zip_code_label = if_else(zip_code == "19144", "Germantown", zip_code_label),
    # Clean departure date time 
    dep_time = parse_date_time(dep_time, "%Y-%m-%d %I:%M %p"),
    dep_date = as_date(dep_time),
    dep_hour = hour(dep_time),
    # Convert travel time to minutes
    duration_transit_minutes = duration_transit_sec / 60
  )

# Create plot
transit_time_plot <- gmaps_test %>%
  ggplot(aes(x = dep_hour, y = duration_transit_minutes, color = hospital_id_label)) +
  geom_line() +
  scale_x_continuous(breaks = seq(0, 24, 3)) +
  labs(x = "Departure Hour", y = "Transit Time (Minutes)", color = "Destination Hospital") +
  facet_grid(rows = vars(zip_code_label), cols = vars(dep_date))

transit_time_plot

ggsave("output/transit_time_plot.png", transit_time_plot, height = 8, width = 10)
