library(httr)

# Set your API endpoint
url <- "http://127.0.0.1:8000/scrape"

# Define your sample parameters
countries_sample <- c('Angola', 'Niger')
indicators_sample <- c('ART coverage')
age_groups_sample <- c('0-14', '60-64')
sex_options <- c('Male')

# Function to handle the conversion of data to a DataFrame
convert_to_dataframe <- function(data, country, indicator, age_group, sex) {
  # Convert the list to a DataFrame
  df <- do.call(rbind, lapply(data, as.data.frame))
  
  # Rename the columns for better readability
  colnames(df) <- c("Level", "Area", "Mean", "Lower", "Upper")
  
  # Convert the relevant columns to numeric
  df$Mean <- as.numeric(df$Mean)
  df$Lower <- as.numeric(df$Lower)
  df$Upper <- as.numeric(df$Upper)
  
  # Add new columns for country, indicator, age group, and sex
  df$Country <- country
  df$Indicator <- indicator
  df$Age_Group <- age_group
  df$Sex <- sex
  
  return(df)
}

# Function to rerun failed cases
retry_failed_cases <- function(failed_cases) {
  rerun_results <- list()
  for (case in failed_cases) {
    params <- list(
      country = case$country,
      indicator = case$indicator,
      age_group = case$age_group,
      period = 'December 2023',
      sex = case$sex,
      csv = FALSE
    )
    
    response <- GET(url, query = params)
    if (response$status_code == 200) {
      data <- content(response, "parsed")
      if (!is.null(data) && length(data) > 0) {
        rerun_results[[length(rerun_results) + 1]] <- convert_to_dataframe(
          data, case$country, case$indicator, case$age_group, case$sex
        )
      }
    }
  }
  return(rerun_results)
}

# Main logic to fetch and handle results
fetch_results <- function(countries, indicators, age_groups, sex_options) {
  results_list <- list()
  failed_cases <- list()
  
  # Loop through all combinations of parameters
  for (country in countries) {
    for (indicator in indicators) {
      for (age_group in age_groups) {
        for (sex in sex_options) {
          
          # Define the parameters for the current combination
          params <- list(
            country = country,
            indicator = indicator,
            age_group = age_group,
            period = 'December 2023',
            sex = sex,
            csv = FALSE
          )
          
          # Make the GET request
          response <- GET(url, query = params)
          
          # Check the status code
          if (response$status_code == 200) {
            # Parse the JSON response
            data <- content(response, "parsed")
            
            # Check if the data is NULL or empty
            if (is.null(data) || length(data) == 0) {
              # Add to failed cases if data is missing
              failed_cases[[length(failed_cases) + 1]] <- list(
                country = country,
                indicator = indicator,
                age_group = age_group,
                sex = sex,
                reason = "No data returned"
              )
            } else {
              # Convert the list to a DataFrame using the new function
              results_list[[length(results_list) + 1]] <- convert_to_dataframe(
                data, country, indicator, age_group, sex
              )
            }
          } else {
            # Add failed cases for non-200 status codes
            failed_cases[[length(failed_cases) + 1]] <- list(
              country = country,
              indicator = indicator,
              age_group = age_group,
              sex = sex,
              reason = paste("Status code:", response$status_code)
            )
          }
        }
      }
    }
  }
  
  # If there are failed cases, retry them
  if (length(failed_cases) > 0) {
    rerun_results <- retry_failed_cases(failed_cases)
    results_list <- c(results_list, rerun_results)
  }
  
  return(list(results = results_list, failed = failed_cases))
}

# Fetch the results
results <- fetch_results(countries_sample, indicators_sample, age_groups_sample, sex_options)

# Function to display the final results and failed cases
display_results <- function(results_list, failed_cases) {
  # Combine all DataFrames into one
  if (length(results_list) > 0) {
    final_results <- dplyr::bind_rows(results_list)
    print("Combined Results:")
    print(final_results)
  } else {
    print("No valid data was returned.")
  }
  
  # Print the failed cases
  if (length(failed_cases) > 0) {
    print("Failed Cases:")
    print(do.call(rbind, lapply(failed_cases, as.data.frame)))
  } else {
    print("No failed cases.")
  }
}

# Display the results
display_results(results$results, results$failed)
