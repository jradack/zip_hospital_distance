###############################################################################################
## Program: C:/Users/radackj/Documents/projects/zcta_centroid/code/state_query_count.R
## Date: 2022-03-29
## Created by: Josh Radack
## Description: Calculates the number of Google Maps queries will need to be made to by state
## Input: 
###############################################################################################
## Update: (2023-01-24) Added columns for census tract and ZCTA
##         (2023-02-07) Moved to new project folder
###############################################################################################

##############################################
## 					        Setup					          ##
##############################################
# Set path for R packages
# library(data.table)
library(haven)
library(readxl)
library(dplyr)

# Import the crosswalk and hospitals dataset
y <- 2015
cphd <- "Y:/5. Data Support/Geography crosswalks/"
zip_state <- fread(paste0(cphd, "ZIP-STATE/zip_state_cw.csv"), header = T, colClasses = c('character','character','integer'))
zip_tract_2015 <- read_excel(paste0(cphd, "ZIP-TRACT/ZIP_TRACT_032015.xlsx"))
zip_zcta_2015 <- read_excel(paste0(cphd, "Zip to ZCTA/UDS crosswalks/ZipCodetoZCTACrosswalk2015.xlsx"))
birth_hospitals_new <- read_dta("birth_hospitals_new.dta")


##############################################
## 				Processing					##
##############################################
# Aggregate the birth hospitals table into a table with state and count
# state_hosps <- data.table(birth_hospitals_new[,c('id','fstcd')])
# state_hosps <- state_hosps[, .(hosp_count = uniqueN(id)), by = .(fstcd)]

# Aggregate the number of unique ZIP codes in each state
# state_zips <- zip_state[, .(zip_count = uniqueN(zip)), by = .(state_fips)]

# Join the resulting tables
# state_data <- merge(state_hosps, state_zips, by.x = c('fstcd'), by.y = c('state_fips'))

# Number of necessary queries is the number of unique hospitals times the number of unique ZIP codes
# state_data <- state_data[, query_count := hosp_count * zip_count]




# Refactoring with dplyr
zip_dat <- zip_state %>% 
    filter(year == y) %>%
    inner_join(zip_zcta_2015 %>% select(ZIP, ZCTA), by = c("zip" = "ZIP")) %>%
    inner_join(zip_tract_2015 %>% select(ZIP, TRACT), by = c("zip" = "ZIP")) %>% 
    group_by(state_fips) %>%
    summarize(zip_unique = n_distinct(zip),
              zcta_unique = n_distinct(ZCTA),
              tract_unique = n_distinct(TRACT))
    
hosp_dat <- birth_hospitals_new %>%
    filter(year == y) %>%
    select(id, fstcd, state) %>%
    group_by(fstcd) %>%
    summarize(state = first(state),
              hosps_unique = n_distinct(id))

count_data <- zip_dat %>%
    inner_join(hosp_dat, by = c("state_fips" = "fstcd")) %>%
    mutate(calculations_zip = zip_unique * hosps_unique,
           calculations_zcta = zcta_unique * hosps_unique,
           calculations_tract = tract_unique * hosps_unique) %>%
    relocate(state_fips, state)





##############################
## 					Output					##
##############################
write.csv(count_data, 'output/state_query_count_20230124.csv', row.names = FALSE)
