# This is a Plumber API. You can run the API by clicking
# the 'Run API' button above.
#
# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#

library(plumber)
library(RSelenium)
library(rvest)
library(dplyr)

#* @apiTitle Plumber Scraping API
#* @apiDescription An API for scraping data from the UNAIDS Naomi Spectrum website.

initialize_driver <- function() {
  # Set Chrome options
  chrome_options <- list(
    chromeOptions = list(
      args = c('--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage')
    )
  )

  # Initialize RSelenium driver with Chrome options
  rD <- rsDriver(browser = "chrome", chromever = "latest", extraCapabilities = chrome_options)
  remDr <- rD$client

  return(list(remDr = remDr, rD = rD))
}

click_element <- function(remDr, xpath, retries = 10, delay = 1) {
  for (attempt in 1:retries) {
    tryCatch({
      message(sprintf("Attempting to click element with XPath: %s", xpath))
      element <- remDr$findElement(using = 'xpath', xpath)
      element$clickElement()
      message(sprintf("Successfully clicked element with XPath: %s", xpath))
      return(TRUE)
    }, error = function(e) {
      message(sprintf("Attempt %d failed, retrying... XPath: %s", attempt, xpath))
      Sys.sleep(delay)
    })
  }
  stop("Element could not be clicked after ", retries, " attempts.")
}

select_option <- function(remDr, dropdown_xpath, option_xpath) {
  message(sprintf("Opening dropdown with XPath: %s", dropdown_xpath))
  click_element(remDr, dropdown_xpath)
  message(sprintf("Selecting option with XPath: %s", option_xpath))
  element <- remDr$findElement(using = 'xpath', option_xpath)
  remDr$executeScript("arguments[0].scrollIntoView(true);", list(element))
  element$clickElement()
  message(sprintf("Selected option with XPath: %s", option_xpath))
}

handle_overlay <- function(remDr) {
  overlay_xpath <- '//div[@class="MuiDialog-container"]'
  tryCatch({
    overlay <- remDr$findElement(using = 'xpath', overlay_xpath)
    if (!is.null(overlay)) {
      message("Overlay found, removing it.")
      remDr$executeScript("document.querySelector('.MuiDialog-container').style.display = 'none';")
      message("Overlay removed.")
    }
  }, error = function(e) {
    message("Overlay not found or already removed.")
  })
}

download_csv <- function(remDr) {
  message("Initiating CSV download.")
  click_element(remDr, '//div[@aria-label="Download CSV"]/a')
  message("CSV download initiated.")
  Sys.sleep(2)  # Adjust based on download time
}

parse_table <- function(remDr) {
  message("Parsing table.")
  table_element <- remDr$findElement(using = 'xpath', '//table')
  page_source <- remDr$getPageSource()[[1]]

  # Use rvest to parse HTML table
  page <- read_html(page_source)
  table <- page %>%
    html_table(fill = TRUE) %>%
    .[[1]]

  # Print table name for verification
  table_name_xpath <- '//*[@class="MuiTypography-root MuiTypography-caption css-1v8m1vc"]'
  table_name <- remDr$findElement(using = 'xpath', table_name_xpath)
  message(sprintf("Table Name: %s", table_name$getElementText()[[1]]))

  return(table)
}

#* Scrape data from the UNAIDS Naomi Spectrum website
#* @param country The country to scrape data for
#* @param indicator The indicator to scrape
#* @param age_group The age group to scrape
#* @param period The period for the data
#* @param sex The sex for the data
#* @param csv Whether to download CSV (TRUE/FALSE)
#* @get /scrape
function(country, indicator, age_group, period, sex, csv = FALSE) {
  driver_data <- initialize_driver()
  remDr <- driver_data$remDr

  tryCatch({
    message("Navigating to the website.")
    remDr$navigate("https://naomi-spectrum.unaids.org/")

    # Handle potential overlay
    #handle_overlay(remDr)

    # Select Country
    message("Selecting country.")
    click_element(remDr, '//button[contains(text(), "Select countries")]')
    Sys.sleep(1)  # Ensure dropdown is loaded

    country_option_xpath <- sprintf('//span[contains(text(), "%s")]', country)
    click_element(remDr, country_option_xpath)
    click_element(remDr, '//button[contains(text(), "Apply")]')
    Sys.sleep(1)

    # Select Indicator
    message("Selecting indicator.")
    select_option(remDr, '//div[@aria-controls=":r6:"]', sprintf('//li[contains(text(), "%s")]', indicator))
    Sys.sleep(1)

    # Select Age Group
    message("Selecting age group.")
    select_option(remDr, '//div[@aria-controls=":r7:"]', sprintf('//li[contains(text(), "%s")]', age_group))
    Sys.sleep(1)

    # Select Period
    message("Selecting period.")
    select_option(remDr, '//div[@aria-controls=":r8:"]', sprintf('//li[contains(text(), "%s")]', period))
    Sys.sleep(1)

    # Select Sex
    message("Selecting sex.")
    select_option(remDr, '//div[@aria-controls=":r9:"]', sprintf('//li[contains(text(), "%s")]', sex))
    Sys.sleep(1)

    # Select Area Level (Last in List is Most Specific)
    message("Selecting area level.")
    click_element(remDr, '//div[@aria-controls=":ra:"]')
    area_level_option_xpath <- '(//li[contains(@role, "option")])[last()]'
    select_option(remDr, '//div[@aria-controls=":ra:"]', area_level_option_xpath)
    Sys.sleep(1)

    # Toggle to Table View
    message("Toggling to table view.")
    toggle_switch_xpath <- '//span[contains(@class, "MuiSwitch-root")]'
    click_element(remDr, toggle_switch_xpath)
    Sys.sleep(1)

    # Optionally download CSV
    if (csv) {
      download_csv(remDr)
    }

    # Parse and return table
    df <- parse_table(remDr)
    return(df)

  }, finally = {
    remDr$close()
    driver_data$rD$server$stop()
  })
}

# Programmatically alter your API
#* @plumber
function(pr) {
  pr %>%
    # Overwrite the default serializer to return unboxed JSON
    pr_set_serializer(serializer_unboxed_json())
}
