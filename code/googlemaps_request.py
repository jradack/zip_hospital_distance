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
def makeRequest(gmaps, origin_lat, origin_lon, destination_lat, destination_lon, mode, depTime):
    origin = {"latitude" : origin_lat, "longitude" : origin_lon}
    destination = {"latitude" : destination_lat, "longitude" : destination_lon}
    req = gmaps.distance_matrix(origins = origin,
                                destinations = destination,
                                mode = mode,
                                units = 'metric',
                                departure_time = depTime)
    reqResult = req.get('rows')[0].get('elements')[0]
    if(reqResult.get('status') == 'OK'):
        return {'distance' : reqResult.get('distance').get('value'), 'duration' : reqResult.get('duration').get('value')}
    else:
        return {'distance' : -1, 'duration' : -1}

def makeRequestIter(gmaps, ds, mode, depTime):
    # Iterate over rows of the distance matrix, with a progress bar
    results = [makeRequest(gmaps,a,b,c,d,mode,depTime) for a,b,c,d in tqdm(zip(ds["zcta_latitude"], ds["zcta_longitude"], ds["hospital_latitude"], ds["hospital_longitude"]), total = len(ds.index))]
    return results

def main():
    # Read in API key
    with open('data/raw/secret.txt', 'r') as file:
        api_key = file.read().rstrip()
    # Create googlemaps object
    gmaps_obj = googlemaps.Client(key=api_key, requests_kwargs={"verify": False})
    # Read in the distance matrix
    distMat = pd.read_csv('data/distance_matrix/PA_dist_mat.csv')
    # Apply any necessary cleaning to the distance matrix (need a new function)
    # Set the departure time
    # depTime = datetime.strptime('2022-10-26 10:00AM','%Y-%m-%d %I:%M%p')
    depTime = datetime.now() + timedelta(minutes = 10) # as a datetime object
    # depTime = depTime.strftime("%Y-%m-%d %H:%M:%S") # Formats departure time as a string
    # Make API request
    makeRequestIter(gmaps = gmaps_obj, ds = distMat, mode = "driving", depTime = depTime)
    # Save Results



if __name__ == "__main__":
    main()

