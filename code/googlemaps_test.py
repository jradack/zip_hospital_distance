###########################################################################################################
## Name: CPHD\5. Data Support\Geographic Data\ZIP Hospital Travel Time\code\googlemaps_test.py
## Created by: Josh Radack
## Date: 2024-06-17
## Purpose: Tests the Google maps API using a select set of hospitals and ZIP codes
##          at different dates and times.
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
    req = gmaps.distance_matrix(
        origins = origin,
        destinations = destination,
        mode = mode,
        units = 'metric',
        departure_time = dep_time
    )
    reqResult = req.get('rows')[0].get('elements')[0]
    distance_lab = "_".join(['distance', mode, 'm'])
    duration_lab = "_".join(['duration', mode, 'sec'])
    if(reqResult.get('status') == 'OK'):
        return {'zcta_geoid' : zcta_geoid, 'hospital_id' : hospital_id, distance_lab : reqResult.get('distance').get('value'), duration_lab : reqResult.get('duration').get('value')}
    else:
        return {'zcta_geoid' : zcta_geoid, 'hospital_id' : hospital_id, distance_lab : -1, duration_lab : -1}

@timer_func
def makeRequestState(gmaps, use_subset = False, subset_size = 10):
    print(f'Processing test dataset cut:')
    # Set file paths
    input_csv = f'data/gmaps_test/pa_dist_mat_test.csv'
    output_csv = f'data/gmaps_test/pa_dist_mat_test_gmaps.csv'
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
        print(f'Making API requests for test dataset...')
        for ind in tqdm(inds):
            # if ind == 5:
            #     raise Exception("Test error")
            # if distMat["distance_driving_m"][ind] != None:
            #     next
            # Make API Requests
            dep_time = datetime.strptime(distMat['dep_time'][ind], '%Y-%m-%d %I:%M %p')
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
        print(f'Saving results...')
        distMat.to_csv(output_csv, index=False)

def main():
    # Read in API key and set up states list
    secret_file = 'secret_test_account'
    with open(f'data/raw/{secret_file}.txt', 'r') as file:
        api_key = file.read().rstrip()
    # Create googlemaps object
    gmaps_obj = googlemaps.Client(key=api_key, requests_kwargs={"verify": False})
    makeRequestState(gmaps_obj)



if __name__ == "__main__":
    main()

