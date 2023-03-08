#-------------------------------------------------------------------------------
# Script for determining which core-based statistical area each of the 
# population-weighted centroids belongs to. 
#
# 
#-------------------------------------------------------------------------------

library(sf)
library(stringr)

source('code/functions.r')

# Load CBSA shape file and CRS file
cbsa_shp <- st_read("data/raw/tl_2020_us_cbsa/tl_2020_us_cbsa.shp")
crs <- readRDS("data/crs.rds")

# Test get_cbsa()
get_cbsa("Philadelphia", cbsa_shp)
get_cbsa("Philadelphia-Dover", cbsa_shp)
get_cbsa("PHILADELPHIA", cbsa_shp)
get_cbsa("filadelfia", cbsa_shp)

# Execute code for finding the ZIP codes contained in a CBSA
philadelphia_zctas <- find_zcta_in_cbsa("Philadelphia-Camden-Wilmington",
                                        cbsa_shp, crs)
zcta_zip_cw <- readxl::read_excel("data/raw/ZIPCodetoZCTACrosswalk2020.xlsx")
philadelphia_zips <- merge(philadelphia_zctas, zcta_zip_cw,
                           by.x = "GEOID_ZCTA5_20", by.y = "ZCTA")
data.table::fwrite(philadelphia_zips, "output/philadelphia_zip_codes.csv")
