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
from pathlib import Path
import shutil

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
def makeRequest(gmaps, zcta_geoid, hospital_id, origin_lat, origin_lon, destination_lat, destination_lon, mode, dep_time):
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
        return {'zcta_geoid' : zcta_geoid, 'hospital_id' : hospital_id, distance_lab : reqResult.get('distance').get('value'), duration_lab : reqResult.get('duration').get('value')}
    else:
        return {'zcta_geoid' : zcta_geoid, 'hospital_id' : hospital_id, distance_lab : -1, duration_lab : -1}

@timer_func
def makeRequestState(gmaps, state_abbrev, dep_time, use_subset = False, subset_size = 10):
    print(f'Processing for {state_abbrev}:')
    # Set file paths
    input_csv = f'data/distance_matrix/{state_abbrev}_weighted_dist_mat.csv'
    output_csv = f'data/distance_matrix/{state_abbrev}_weighted_gmaps_dist_mat.csv'
    # Copy file if it doesn't exist yet
    output_file = Path(output_csv)
    if not output_file.is_file():
        shutil.copyfile(input_csv, output_csv)
    # Read in the distance matrix
    distMat = pd.read_csv(output_csv, dtype={'fips_state':'str', 'hospital_id':'str', 'zcta_geoid':'str'})
    # Take a random subset of the data
    if use_subset:
        # assign subset_size to be the whole matrix if it is bigger than the number of rows
        subset_size = len(distMat.index) if len(distMat.index) < subset_size else subset_size
        distMat = distMat.sample(n=subset_size, random_state=100)
    # Create columns for google maps results if they don't yet exist, populate with None
    distMat[["distance_driving_m", "duration_driving_sec", "distance_transit_m", "duration_transit_sec"]] = distMat.get(["distance_driving_m", "duration_driving_sec", "distance_transit_m", "duration_transit_sec"], None)
    # Get indices where there are None values
    inds = distMat[distMat['distance_driving_m'].isnull()].index.tolist()
    try:
        print(f'Making API requests for {state_abbrev}...')
        for ind in tqdm(inds):
            # if ind == 5:
            #     raise Exception("Test error")
            # if distMat["distance_driving_m"][ind] != None:
            #     next
            # Make API Requests
            result_driving = makeRequest(gmaps, distMat['zcta_geoid'][ind], distMat["hospital_id"][ind], distMat["zcta_latitude"][ind], distMat["zcta_longitude"][ind], distMat["hospital_latitude"][ind], distMat["hospital_longitude"][ind], "driving", dep_time)
            result_transit = makeRequest(gmaps, distMat['zcta_geoid'][ind], distMat["hospital_id"][ind], distMat["zcta_latitude"][ind], distMat["zcta_longitude"][ind], distMat["hospital_latitude"][ind], distMat["hospital_longitude"][ind], "transit", dep_time)
            # Save results
            distMat.at[ind, "distance_driving_m"] = result_driving["distance_driving_m"]
            distMat.at[ind, "duration_driving_sec"] = result_driving["duration_driving_sec"]
            distMat.at[ind, "distance_transit_m"] = result_transit["distance_transit_m"]
            distMat.at[ind, "duration_transit_sec"] = result_transit["duration_transit_sec"]
    except Exception as error:
        print("Encountered an error: " + repr(error))
    finally:
        print(f'Saving results for {state_abbrev}...')
        distMat.to_csv(output_csv, index=False)

def main():
    # Read in API key and set up states list
    # secret_file, states = ['secret_chop', ["OR", "SC", "WV", "CO", "MA", "NJ", "TN", "VA", "MI", "LA", "FL", "NY", "PA", "CA"]]
    # secret_file, states = ['secret_stanford', ["CA"]]
    secret_file, states = ['secret_test_account', ["ABC"]]
    with open(f'data/raw/{secret_file}.txt', 'r') as file:
        api_key = file.read().rstrip()
    # Create googlemaps object
    gmaps_obj = googlemaps.Client(key=api_key, requests_kwargs={"verify": False})
    # Set the departure time
    dep_time = datetime.strptime('2023-05-17 04:00PM','%Y-%m-%d %I:%M%p')
    # dep_time = datetime.now() + timedelta(minutes = 10)
    for state in states:
        makeRequestState(gmaps_obj, state, dep_time)
        # makeRequestState(gmaps_obj, state, dep_time, use_subset = True, subset_size=100)



if __name__ == "__main__":
    main()

