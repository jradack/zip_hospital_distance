# Hospital - ZIP Code Distance Project

Code and data for project calculating the distance and drive times between maternal delivery hospitals and maternal residence ZIP codes.


## Code

- `centroids_distances.r`: Computes and analyzes the distances between weighted and unweighted ZCTA centroids.
- `distance_matrix.r`: Computes the long-form (Haversine) distance matrix between ZCTA centroids and hosptial addresses. The output dataset is fed to the script for querying the googlemaps API.
- `function.r`: Contains all of the R functions used within the other R scripts.
- `googlemaps_request.py`: Makes the API calls for driving/transit distance and time between ZCTA centroids and hospital addresses.
- `plot_map.r`: Maps ZCTAs and their centroid.
- `pop_weight_centroid.r`: Computes the population-weighted centroids for 2020 ZCTAs.
- `state_query_count.r`: Counts the number of queries would be needed at varying levels of geographic complexity.
- `zcta_block_group_cw.r`: Checks if census block groups map uniquely to a ZCTA.
- `zcta_cbsa_cw.r`: Creates a crosswalk between ZCTAs and core-based statistical areas (metropolitan and micropolitan statistical areas).
- `zip_code_prefix_scrape.py`: Scrapes the Wikipedia page with a table that crosswalks three-digit ZIP code prefixes to states.

To generate the distance matrix output from scratch, run the scripts in the following order:
1. `pop_weight_centroid.r`
2. `distance_matrix.r`
3. `googlemaps_request.py`

## Data

### Raw Data Files

The following raw data files are not included in this repository.
- AHA birth hospital addresses
- National ZCTA - census block crosswalk from the [Census Bureau](https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_tabblock20_natl.txt).
- State-specific shapefiles for census block from the [Census Bureau](https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20/).
- Core-Based Statistical Area shapefile from the [Census Bureau](https://www2.census.gov/geo/tiger/TIGER2020/CBSA/).
- ZIP Code - ZCTA crosswalk from [UDS Mapper](https://udsmapper.org/zip-code-to-zcta-crosswalk/).

### Distance Matrix Data Dictionary

- `state`: (chr) 2-letter state abbreviation 
- `fips_state`: (chr) 2-digit state FIPS code
- `year`: (int) Year of the hospital address
- `hospital_id`: (chr) AHA ID of the hospital
- `hospital_latitude`: (num) Hospital latitude
- `hospital_longitude`: (num) Hospital longitude
- `zcta_geoid`: (chr) 5-digit ZCTA GEOID
- `zip_code`: (chr) 5-digit ZIP code matched to the ZCTA
- `zcta_latitude`: (num) ZCTA centroid latitude
- `zcta_longitude`: (num) ZCTA centroid longitude
- `haversine_dist_m`: (num) Crow-flies (Haversine) distance between the ZCTA centroid and the hospital address, in meters

