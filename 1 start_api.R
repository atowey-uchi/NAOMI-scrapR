library(plumber)

# Load the script as a plumber API
pr <- plumb("~/NAOMI-ScrapR/2 scrape_naomi.R")  # Make sure this file contains Plumber API functions

# Run the API on port 8000
pr$run(port = 8000)