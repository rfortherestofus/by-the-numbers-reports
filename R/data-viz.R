# Data visualizations for the "by the numbers" reports.
#
# Reads the tidy datasets written by R/import-data.R (from data_clean/) and
# builds the figures for a single-state report. Set `state` below to the state
# the report covers; everything downstream filters the nationwide data to it.
here::i_am("R/data-viz.R")

library(here)
library(tidyverse)
library(sf)
library(marquee)

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

# ---- Median household income: focus county vs. rest of state ----
# A strip plot: one dot per county along the income axis, with the focus county
# highlighted so it is easy to see where it sits in the state's distribution.
# The income and boundary datasets name counties differently ("Los Angeles
# County" vs. "Los Angeles"), so match the focus county by its geoid instead.
focus_geoid <- focus_county_data$geoid

income_by_county <- read_rds(
  here("data_clean", "median_household_income_by_county.rds")
) |>
  filter(state == focus_state) |>
  mutate(is_focus = geoid == focus_geoid)

focus_income <- income_by_county |>
  filter(is_focus) |>
  pull(median_household_income)

# A darker green than the map fill so a small dot reads clearly; grey dots are
# recessive context. `is_focus` (not color alone) also drives dot size.
focus_color <- "#4C7A2F"
other_color <- "grey70"

# marquee style for the title: highlight the focus value with the same green as
# the dot. Invoked with a `{.hl ...}` span in the title text below.
title_style <- modify_style(
  classic_style(),
  "hl",
  background = focus_color,
  color = "white",
  padding = trbl(em(0.1), em(0.1)),
  border_radius = em(0.25)
)

# All dots sit on one row (y = 1); the vertical jitter only spreads overlapping
# counties apart and carries no meaning (the subtitle says so). Seed keeps it
# reproducible across renders.
set.seed(1)
income_plot <- ggplot(
  income_by_county,
  aes(x = median_household_income, y = 1)
) +
  geom_jitter(
    data = \(d) filter(d, !is_focus),
    height = 0.18,
    width = 0,
    color = other_color,
    size = 2.5,
    alpha = 0.8
  ) +
  geom_point(
    data = \(d) filter(d, is_focus),
    color = focus_color,
    size = 4.5
  ) +
  scale_x_continuous(labels = scales::label_dollar()) +
  scale_y_continuous(limits = c(0.4, 1.6)) +
  labs(
    title = paste0(
      "Median household income in {.hl ",
      focus_county,
      " County",
      "}",
      " is ",
      scales::dollar(focus_income, accuracy = 1)
    ),
    subtitle = paste0(
      "Each gray dot is another ",
      focus_state,
      " county; dots are spread to random heights to avoid overlap"
    ),
    x = NULL,
    y = NULL
  ) +
  theme_minimal() +
  theme(
    plot.title = element_marquee(style = title_style),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid = element_blank(),
    panel.grid.major.x = element_line(color = "grey92")
  )

income_plot
