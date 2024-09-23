# NAOMI-ScrapR

**NAOMI-ScrapR** is a web scraping tool designed to extract data from the NAOMI Spectrum website. It consists of two components: an API to handle scraping requests and a script that scrapes data based on specified parameters. Currently, the API runs locally.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
  - [Running the API](#running-the-api)
  - [Running the Scraper](#running-the-scraper)
- [Planned Improvements](#planned-improvements)

## Installation

1. **Clone the repository:**

```bash
git clone git@github.com:atowey-uchi/NAOMI-ScrapR.git
cd NAOMI-ScrapR
```
2. **Install R dependencies:**

Before running the scripts, make sure you have the necessary R packages installed. You can do this by executing the following command in your R console:

  ```r
  install.packages(c("httr", "dplyr", "jsonlite", "purrr"))
  ```
## Usage

### Running the API

To start the API, run the following script:

  ```bash
  Rscript start_api.R
  ```

2. This will start a local API that listens for HTTP requests on http://127.0.0.1:8000/scrape.

### Running the Scraper
Once the API is running, you can run the scraper to extract data using the provided script:

1. Open `scrape_naomi.R` and configure the parameters (such as `country`, `indicator`, `age_group`, and `sex`) for the scraping task.
   *Note*: Currently, sample parameters are set for testing purposes.

3. Run the `scrape_naomi.R` script:
  ```bash
  Rscript scrape_naomi.R
  ```

## Planned Improvements
- Turn into an R package for ease of use
- Host API non-locally
- Explore parallelization
- Fine tuning output and output format (currently a DF for testing purposes)

