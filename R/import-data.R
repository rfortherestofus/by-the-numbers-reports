# Import county-level Census data (ACS 5-year) for all U.S. states.
#
# Pulls three measures from the American Community Survey via tidycensus, plus
# state and county boundary geometries via tigris, and saves a tidy .rds file
# per table to data_clean/. The data spans every county in the country; filter
# by the `state` column to build a single-state report.
here::i_am("R/import-data.R")

library(here)
library(tidycensus)
library(tigris)
library(tidyverse)

# Cache tigris downloads so reruns don't re-fetch the shapefiles.
options(tigris_use_cache = TRUE)

# ---- Parameters ----
acs_year <- 2023 # latest 5-year ACS vintage (2019-2023); bump as new releases land
acs_survey <- "acs5" # 5-year survey: only ACS dataset with full county coverage

# tidycensus reads the key from the CENSUS_API_KEY environment variable. Get a
# free key at https://api.census.gov/data/key_signup.html, then run once:
#   tidycensus::census_api_key("YOUR_KEY", install = TRUE)
if (Sys.getenv("CENSUS_API_KEY") == "") {
  stop("Set CENSUS_API_KEY before running (see tidycensus::census_api_key()).")
}

# Shared cleanup: snake_case id + split Census "County, State" into two columns.
clean_geo <- function(df) {
  df |>
    rename(geoid = GEOID) |>
    separate_wider_delim(NAME, delim = ", ", names = c("county", "state"))
}

# ---- 1. Median household income ----
median_household_income_by_county <- get_acs(
  geography = "county",
  variables = c(median_household_income = "B19013_001"),
  year = acs_year,
  survey = acs_survey
) |>
  clean_geo() |>
  select(geoid, county, state, median_household_income = estimate)

# ---- 2. Population by race and ethnicity ----
# B03002 = Hispanic or Latino by Race. The names below become the human-readable
# `race_ethnicity` values. Totals/subtotals (_001 total, _002 not-Hispanic) are
# excluded because they are derivable from the groups below.
race_ethnicity_vars <- c(
  "Hispanic or Latino" = "B03002_012",
  "White" = "B03002_003",
  "Black or African American" = "B03002_004",
  "American Indian and Alaska Native" = "B03002_005",
  "Asian" = "B03002_006",
  "Native Hawaiian and Other Pacific Islander" = "B03002_007",
  "Some other race" = "B03002_008",
  "Two or more races" = "B03002_009"
)

population_by_county_and_race_ethnicity <- get_acs(
  geography = "county",
  variables = race_ethnicity_vars,
  year = acs_year,
  survey = acs_survey
) |>
  clean_geo() |>
  select(geoid, county, state, race_ethnicity = variable, population = estimate)

# ---- 3. Total population ----
total_population_by_county <- get_acs(
  geography = "county",
  variables = c(total_population = "B01003_001"),
  year = acs_year,
  survey = acs_survey
) |>
  clean_geo() |>
  select(geoid, county, state, total_population = estimate)

# ---- 4. State boundaries ----
# Cartographic boundary files (cb = TRUE): generalized geometries that are far
# smaller than full TIGER/Line and render well for thematic maps. The 2-digit
# `geoid` is the state FIPS code.
state_boundaries <- states(cb = TRUE, year = acs_year) |>
  rename(geoid = GEOID, state = NAME) |>
  select(geoid, state, geometry)

# ---- 5. County boundaries ----
# The 5-digit `geoid` (state FIPS + county FIPS) joins directly to the ACS
# county tables above.
county_boundaries <- counties(cb = TRUE, year = acs_year) |>
  rename(geoid = GEOID, county = NAME) |>
  select(geoid, county, geometry)

# ---- Save tidy outputs ----
write_rds(
  median_household_income_by_county,
  here("data_clean", "median_household_income_by_county.rds")
)
write_rds(
  population_by_county_and_race_ethnicity,
  here("data_clean", "population_by_county_and_race_ethnicity.rds")
)
write_rds(
  total_population_by_county,
  here("data_clean", "total_population_by_county.rds")
)
write_rds(
  state_boundaries,
  here("data_clean", "state_boundaries.rds")
)
write_rds(
  county_boundaries,
  here("data_clean", "county_boundaries.rds")
)
