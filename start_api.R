library(plumber)

# Load the script as a plumber API
pr <- plumb("~/NAOMI-ScrapR/naomi_api_plumber.R")  # Make sure this file contains Plumber API functions

# Run the API on port 8000
pr$run(port = 8000)
