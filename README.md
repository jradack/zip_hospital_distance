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
- `zip_code_prefix_scrape.py`: Scrapes the Wikipedia page with a table that crosswalks three-digit ZIP code prefixes to states.

## Data

The following raw data files are not included in this repository.
- AHA birth hospital addresses
- National ZCTA - census block crosswalk from the [Census Bureau](https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_tabblock20_natl.txt).
- State-specific shapefiles for census block from the [Census Bureau](https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20/).
