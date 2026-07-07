# Data visualizations for the "by the numbers" reports.
#
# Reads the tidy datasets written by R/import-data.R (from data_clean/) and
# builds the figures for a single-state report. Set `state` below to the state
# the report covers; everything downstream filters the nationwide data to it.
here::i_am("R/data-viz.R")

library(here)
library(tidyverse)
library(sf)

# ---- Parameters ----
focus_state <- "California" # state this report covers; must match the `state` column
focus_county <- "Los Angeles" # county to highlight; must match the `county` column

# ---- State map ----
# state_boundaries covers every state; filter to the report's state and draw it.
state_boundaries <- read_rds(here("data_clean", "state_boundaries.rds"))

state_map_data <- state_boundaries |>
  filter(state == focus_state)

state_map <- ggplot(state_map_data) +
  geom_sf() +
  theme_void()

state_map

# ---- County map ----
# county_boundaries covers every county; filter to the focus state, then pull
# out the focus county to highlight.
county_boundaries <- read_rds(here("data_clean", "county_boundaries.rds"))

county_map_data <- county_boundaries |>
  filter(state == focus_state)

focus_county_data <- county_map_data |>
  filter(county == focus_county)

# Draw the whole state in grey, then layer the focus county on top in green.
county_map <- ggplot() +
  geom_sf(data = state_map_data, fill = "grey70", color = "white") +
  geom_sf(data = focus_county_data, fill = "#A8C686", color = "grey40") +
  theme_void()

county_map
