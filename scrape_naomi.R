library(httr)
library(dplyr)
library(purrr)

# Set your API endpoint
url <- "http://127.0.0.1:8000/scrape"

# Sample parameters
countries_sample <- c('Angola', 'Niger')
indicators_sample <- c('ART coverage', 'HIV prevalence')
age_groups_sample <- c('0-14', '60-64')
sex_options <- c('Male', 'Female')
period <- 'December 2023'
max_attempts <- 10

# Function to convert data to a DataFrame
convert_to_dataframe <- function(data, params) {
  df <- bind_rows(lapply(data, as.data.frame)) %>%
    mutate(across(c(Mean, Lower, Upper), as.numeric),
           Country = params$country,
           Indicator = params$indicator,
           Age_Group = params$age_group,
           Sex = params$sex) %>%
    rename(Level = 1, Area = 2, Mean = 3, Lower = 4, Upper = 5)
  return(df)
}

# Function to make an API call
make_api_call <- function(params) {
  response <- GET(url, query = params)
  if (response$status_code == 200) {
    data <- content(response, "parsed")
    if (!is.null(data) && length(data) > 0) {
      return(list(success = TRUE, data = data))
    }
  }
  return(list(success = FALSE, status_code = response$status_code))
}

# Function to fetch results
fetch_results <- function(countries, indicators, age_groups, sex_options) {
  param_combinations <- expand.grid(country = countries, 
                                    indicator = indicators, 
                                    age_group = age_groups, 
                                    sex = sex_options, 
                                    stringsAsFactors = FALSE)
  
  results <- param_combinations %>%
    pmap_dfr(function(country, indicator, age_group, sex) {
      params <- list(country = country, indicator = indicator, age_group = age_group, period = period, sex = sex, csv = FALSE)
      api_result <- safely(make_api_call)(params)
      
      if (is.null(api_result$error) && api_result$result$success) {
        return(convert_to_dataframe(api_result$result$data, params))
      } else {
        return(tibble(Country = country, Indicator = indicator, Age_Group = age_group, Sex = sex, Reason = ifelse(is.null(api_result$error), paste("Status code:", api_result$result$status_code), api_result$error$message)))
      }
    })
  
  successful_results <- results %>% filter(!is.na(Level))
  failed_cases <- results %>% filter(is.na(Level))
  
  return(list(successful = successful_results, failed = failed_cases))
}

# Retry logic for failed cases
retry_failed_cases <- function(failed_cases) {
  failed_cases %>%
    rowwise() %>%
    do({
      params <- list(Country = .$Country, Indicator = .$Indicator, Age_Group = .$Age_Group, Sex = .$Sex)
      for (attempt in 1:max_attempts) {
        api_result <- make_api_call(params)
        if (api_result$success) {
          return(convert_to_dataframe(api_result$data, params))
        }
        Sys.sleep(3)  # Wait before retrying
      }
      tibble(Country = params$Country, Indicator = params$Indicator, Age_Group = params$Age_Group, Sex = params$Sex, Reason = "Failed after max attempts")
    })
}

# Fetch results
results <- fetch_results(countries_sample, indicators_sample, age_groups_sample, sex_options)

# Retry failed cases
retry_results <- retry_failed_cases(results$failed)

# Combine successful results with retried successes
combined_results <- bind_rows(results$successful, retry_results)

# Function to display results
display_results <- function(combined_results) {
  successful_results <- combined_results %>% filter(!is.na(Level))
  failed_results <- combined_results %>% filter(is.na(Level))
  
  if (nrow(successful_results) > 0) {
    print("Successful Results:")
    print(successful_results)
  } else {
    print("No valid data was returned.")
  }
  
  if (nrow(failed_results) > 0) {
    print("Cases that never succeeded:")
    print(failed_results)
  } else {
    print("All cases were retried successfully or had no failures.")
  }
  
  # Check for expected tables
  actual_tables <- unique(paste(successful_results$Country, successful_results$Indicator, successful_results$Age_Group, successful_results$Sex))
  missing_tables <- setdiff(expected_tables, actual_tables)
  
  if (length(missing_tables) > 0) {
    print("The following expected tables are missing:")
    print(missing_tables)
  } else {
    print("All expected tables are present.")
  }
}

# Create expected tables
expected_tables <- expand.grid(country = countries_sample, 
                               indicator = indicators_sample, 
                               age_group = age_groups_sample, 
                               sex = sex_options, 
                               stringsAsFactors = FALSE) %>%
  mutate(table_id = paste(country, indicator, age_group, sex)) %>%
  pull(table_id)

# Display combined results
display_results(combined_results)
