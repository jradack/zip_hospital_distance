###########################################################################################################
## Name: CPHD\5. Data Support\Geographic Data\ZIP Hospital Travel Time\code\googlemaps_test_code.py
## Created by: Josh Radack
## Date: 2022-10-13
## Purpose: Program to test googlemaps API for getting travel time (car and transit) between ZCTA centroids
##          and hospital latitude and longitude. Includes code for cleaning the returned information.
## Update: (2023-01-04) Altered code so that a single origin-destination request is made per API call.
##         (2023-02-22) Cleaned up code for github upload.
###########################################################################################################

import googlemaps
import pandas as pd
from datetime import datetime
from tqdm import tqdm
from time import time

# Set working directory
# os.chdir("Y:/5. Data Support/Geographic Data/ZIP Hospital Travel Time")

##################################
## FUNCTIONS FOR MAKING REQUEST
##################################
# Timer decorator function
def timer_func(func):
    def wrap_func(*args, **kwargs):
        t1 = time()
        result = func(*args, **kwargs)
        t2 = time()
        print(f'> Function {func.__name__!r} executed in {(t2-t1):.4f}s')
        return result
    return wrap_func

# Function for making a single API request
def makeRequest(gmaps, zcta_geoid, zip_code, hospital_id, origin_lat, origin_lon, destination_lat, destination_lon, mode, dep_time):
    origin = {"latitude" : origin_lat, "longitude" : origin_lon}
    destination = {"latitude" : destination_lat, "longitude" : destination_lon}
    req = gmaps.distance_matrix(origins = origin,
                                destinations = destination,
                                mode = mode,
                                units = 'metric',
                                departure_time = dep_time)
    reqResult = req.get('rows')[0].get('elements')[0]
    distance_lab = "_".join(['distance', mode, 'm'])
    duration_lab = "_".join(['duration', mode, 'sec'])
    if(reqResult.get('status') == 'OK'):
        return {'zcta_geoid' : zcta_geoid, 'zip_code' : zip_code, 'hospital_id' : hospital_id, distance_lab : reqResult.get('distance').get('value'), duration_lab : reqResult.get('duration').get('value')}
    else:
        return {'zcta_geoid' : zcta_geoid, 'zip_code' : zip_code, 'hospital_id' : hospital_id, distance_lab : -1, duration_lab : -1}

@timer_func
def makeRequestIter(gmaps, ds, mode, dep_time):
    # Iterate over rows of the distance matrix, with a progress bar
    results = [
        makeRequest(gmaps, zcta_geoid, zip_code, hospital_id, zcta_latitude, zcta_longitude, hospital_latitude, hospital_longitude, mode, dep_time) 
        for zcta_geoid, zip_code, hospital_id, zcta_latitude, zcta_longitude, hospital_latitude, hospital_longitude 
        in tqdm(zip(ds["zcta_geoid"], ds["zip_code"], ds["hospital_id"], ds["zcta_latitude"], ds["zcta_longitude"], ds["hospital_latitude"], ds["hospital_longitude"]),
        total = len(ds.index))
        ]
    return results

@timer_func
def makeRequestState(gmaps, state_abbrev, dep_time, use_subset = False, subset_size = 10):
    print(f'Processing for {state_abbrev}:')
    # Set file paths
    input_csv = f'data/distance_matrix/{state_abbrev}_weighted_dist_mat.csv'
    output_csv = f'data/distance_matrix/{state_abbrev}_weighted_gmaps_dist_mat.csv'
    # Read in the distance matrix
    distMat = pd.read_csv(input_csv, dtype={'fips_state':'str', 'hospital_id':'str', 'zcta_geoid':'str', 'zip_code':'str'})
    # Take a random subset of the data
    if use_subset:
        # assign subset_size to be the whole matrix if it is bigger than the number of rows
        subset_size = len(distMat.index) if len(distMat.index) < subset_size else subset_size
        distMat = distMat.sample(n=subset_size, random_state=100)
    # Make API request
    print(f'Making API requests for {state_abbrev} drive times and distances...')
    driveTimes = makeRequestIter(gmaps = gmaps, ds = distMat, mode = "driving", dep_time = dep_time)
    print(f'Making API requests for {state_abbrev} transit times and distances...')
    transitTimes = makeRequestIter(gmaps = gmaps, ds = distMat, mode = "transit", dep_time = dep_time)
    # Clean up results
    print(f'Cleaning up and saving results for {state_abbrev}...')
    driveTimes_df = pd.DataFrame.from_records(driveTimes)
    transitTimes_df = pd.DataFrame.from_records(transitTimes)
    distMat_gmaps = distMat.merge(driveTimes_df, how="left", on=["zcta_geoid", "zip_code", "hospital_id"]).merge(transitTimes_df, how="left", on=["zcta_geoid", "zip_code", "hospital_id"])
    # Save Results
    distMat_gmaps.to_csv(output_csv, index=False)

def main():
    # Read in API key
    secret_file = 'secret'
    # secret_file = 'secret_test_account'
    with open(f'data/raw/{secret_file}.txt', 'r') as file:
        api_key = file.read().rstrip()
    # Create googlemaps object
    gmaps_obj = googlemaps.Client(key=api_key, requests_kwargs={"verify": False})
    # Set the departure time
    dep_time = datetime.strptime('2023-05-17 04:00PM','%Y-%m-%d %I:%M%p')
    # dep_time = datetime.now() + timedelta(minutes = 10)
    # states = ["AZ", "CA", "CO", "FL", "LA", "MA", "MI", "NJ", "NV", "NY", "OR", "PA", "SC", "TN", "VA", "WV"]
    states = ["CO", "FL", "LA", "MA", "MI", "NJ", "NY", "OR", "PA", "SC", "TN", "VA", "WV"]
    # states = ["ABC"]
    for state in states:
        makeRequestState(gmaps_obj, state, dep_time)
        # makeRequestState(gmaps_obj, state, dep_time, use_subset = True, subset_size=100)



if __name__ == "__main__":
    main()

