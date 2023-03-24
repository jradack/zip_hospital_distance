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
from datetime import datetime, timedelta
from tqdm import tqdm

# Set working directory
# os.chdir("Y:/5. Data Support/Geographic Data/ZIP Hospital Travel Time")

##################################
## FUNCTIONS FOR MAKING REQUEST
##################################
# Function for making a single API request
def makeRequest(gmaps, origin_id, origin_lat, origin_lon, destination_id, destination_lat, destination_lon, mode, depTime):
    origin = {"latitude" : origin_lat, "longitude" : origin_lon}
    destination = {"latitude" : destination_lat, "longitude" : destination_lon}
    req = gmaps.distance_matrix(origins = origin,
                                destinations = destination,
                                mode = mode,
                                units = 'metric',
                                departure_time = depTime)
    reqResult = req.get('rows')[0].get('elements')[0]
    distance_lab = "_".join(['distance', mode])
    duration_lab = "_".join(['duration', mode])
    if(reqResult.get('status') == 'OK'):
        return {'origin_id' : origin_id, 'destination_id' : destination_id, distance_lab : reqResult.get('distance').get('value'), duration_lab : reqResult.get('duration').get('value')}
    else:
        return {'origin_id' : origin_id, 'destination_id' : destination_id, distance_lab : -1, duration_lab : -1}

def makeRequestIter(gmaps, ds, mode, depTime):
    # Iterate over rows of the distance matrix, with a progress bar
    results = [
        makeRequest(gmaps, zcta_geoid, zcta_latitude, zcta_longitude, hospital_id, hospital_latitude, hospital_longitude, mode, depTime) 
        for zcta_geoid, zcta_latitude, zcta_longitude, hospital_id, hospital_latitude, hospital_longitude 
        in tqdm(zip(ds["zcta_geoid"], ds["zcta_latitude"], ds["zcta_longitude"], ds["hospital_id"], ds["hospital_latitude"], ds["hospital_longitude"]),
        total = len(ds.index))
        ]
    return results

def main():
    # Read in API key
    with open('data/raw/secret.txt', 'r') as file:
        api_key = file.read().rstrip()
    # Create googlemaps object
    gmaps_obj = googlemaps.Client(key=api_key, requests_kwargs={"verify": False})
    # Read in the distance matrix
    distMat = pd.read_csv('data/distance_matrix/PA_weighted_dist_mat.csv', dtype={'fips_state':'str', 'hospital_id':'str', 'zcta_geoid':'str', 'zip_code':'str'})
    distMat = distMat.sample(n=10, random_state=100)
    # Apply any necessary cleaning to the distance matrix (need a new function)
    # Set the departure time
    # depTime = datetime.strptime('2022-10-26 10:00AM','%Y-%m-%d %I:%M%p')
    depTime = datetime.now() + timedelta(minutes = 10) # as a datetime object
    # depTime = depTime.strftime("%Y-%m-%d %H:%M:%S") # Formats departure time as a string
    # Make API request
    driveTimes = makeRequestIter(gmaps = gmaps_obj, ds = distMat, mode = "driving", depTime = depTime)
    transitTimes = makeRequestIter(gmaps = gmaps_obj, ds = distMat, mode = "transit", depTime = depTime)
    # Clean up results
    driveTimes_df = pd.DataFrame.from_records(driveTimes)
    transitTimes_df = pd.DataFrame.from_records(transitTimes)
    distMat_gmaps = distMat.merge(driveTimes_df, how="left", left_on=["zcta_geoid","hospital_id"], right_on=["origin_id", "destination_id"]).merge(transitTimes_df, how="left", left_on=["zcta_geoid","hospital_id"], right_on=["origin_id", "destination_id"])
    distMat_gmaps = distMat_gmaps.drop(["origin_id_x", "destination_id_x", "origin_id_y", "destination_id_y"], axis=1)
    # Save Results
    distMat_gmaps.to_csv("data/distance_matrix/PA_weighted_gmaps_dist_mat.csv", index=False)



if __name__ == "__main__":
    main()

