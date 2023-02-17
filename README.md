# Hospital - ZIP Code Distance Project

Code and data for project calculating the distance and drive times between maternal delivery hospitals and maternal residence ZIP codes.


## Code

- `centroids_distances.r`: Computes and analyzes the distances between weighted and unweighted ZCTA centroids.
- `function.r`: Contains all of the R functions used within the other R scripts.
- `plot_map.r`: Maps ZCTAs and their centroid.
- `pop_weight_centroid.r`: Computes the population-weighted centroids for 2020 ZCTAs.
- `state_query_count.r`: Counts the number of queries would be needed at varying levels of geographic complexity.
- `zcta_block_group_cw.r`: Checks if census block groups map uniquely to a ZCTA.
- `zip_code_prefix_scrape.py`: Scrapes the Wikipedia page with a table that crosswalks three-digit ZIP code prefixes to states.
