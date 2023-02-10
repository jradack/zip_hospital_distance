#
# This script pulls data from the tables on the Wikipedia page for ZIP code prefixes.
# It creates a dataset which will serve as a lookup table for determining which
# state a given ZIP code belongs to.
#


import pandas as pd # library for data analysis
import requests # library to handle requests
from bs4 import BeautifulSoup # library to parse HTML documents

# get the response in the form of html
wikiurl="https://en.wikipedia.org/wiki/List_of_ZIP_Code_prefixes"
table_class="wikitable sortable jquery-tablesorter"
response=requests.get(wikiurl)
print(response.status_code)

# parse data from the html into a beautifulsoup object
response_edit = response.text.replace('<br />', ' ; ') # replace break tags with a dash so that all the cell text can be easily parsed
soup = BeautifulSoup(response_edit, 'html.parser')
zip_tabs = soup.find_all('table')

# Read the tables into pandas data frames
df = pd.read_html(str(zip_tabs))
df_comb = pd.concat(df[0:10], axis = 0).stack()
df_comb.reset_index(drop=True, inplace=True)

# Function for cleaning the cell contents
g = '000 ; Placeholders for areas with no proper zip code or addresses ;'
a = "049 ME ; Waterville ;"
b = "010 MA† ; Springfield ; Vicinity"
c = "029 RI* ; Providence ; Main"
d = "201 VA‡ ; Dulles ;"
def clean_cell(x):
    # Split up the string into ZIP prefix, state, USPS SCF, and sub-SCF
    str_list = x.split(";")
    zip_state_substr = str_list[0].strip()
    zip_state_substr = [zip_state_substr, ""] if zip_state_substr.isnumeric() else zip_state_substr.split(" ")
    
    str_list = [zip_state_substr, str_list[1:]]
    str_list = [item for sublist in str_list for item in sublist]
    str_list = [a.strip() for a in str_list]
    # print(str_list)
    str_list = str_list if len(str_list) == 4 else str_list[0:4]
    
    # Handle special characters on the state string
    state, indicators = str_list[1][:2], str_list[1][2:]
    ast_ind = 1 if "*" in indicators else 0
    dag_ind = 1 if "†" in indicators else 0
    ddag_ind = 1 if "‡" in indicators else 0
    str_list[1] = state
    str_list.extend([ast_ind, dag_ind, ddag_ind])
    
    return pd.Series(str_list)

clean_cell(g)
clean_cell(a)
clean_cell(b)
clean_cell(c)
clean_cell(d)

# Clean the data and store as a dataframe
df_clean = df_comb.apply(clean_cell)
df_clean.columns = ["zip_prefix", "state", "usps_scf", "usps_scf_sub", "default_place_name", "scf_different_state", "not_original_zip"]

# Export the dataframe
df_clean.to_csv("C:/Users/radackj/Documents/projects/zcta_centroid/data/zip_code_prefix.csv", index = False)

