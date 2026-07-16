# Data visualizations for the "by the numbers" reports.
#
# Reads the tidy datasets written by R/import-data.R (from data_clean/) and
# builds the figures for a single-state report. Set the focus parameters below;
# everything downstream filters the nationwide data to them.
#
# Figures are exported without titles or subtitles: those live in the Typst
# layout (report/report.qmd), which sources this script for the plots and data.
here::i_am("R/data-viz.R")

library(here)
library(tidyverse)
library(sf)

# ---- Parameters ----
# Defaults for running this script interactively. report/report.qmd sets both
# from its YAML metadata before sourcing, so the report is parameterized in
# one place (the qmd header). Values must match the `state`/`county` columns.
if (!exists("focus_state")) focus_state <- "California"
if (!exists("focus_county")) focus_county <- "Los Angeles"

# ---- Palette ----
focus_color <- "#4C7A2F" # highlight for dots, bars, and the table
focus_fill <- "#A8C686" # lighter green for the filled focus county on the map
other_color <- "grey70" # non-focus / context

# ---- Shared setup ----
# Every cleaned dataset lives in data_clean/.
read_clean <- function(name) read_rds(here("data_clean", name))

# Flag the focus county by geoid. The ACS tables and boundary files name
# counties differently ("Los Angeles County" vs. "Los Angeles"), so geoid is the
# only reliable key. Resolves `focus_geoid` from the global env when called.
mark_focus <- function(df) {
  df |> mutate(is_focus = geoid == focus_geoid)
}

# Boundaries, plus the focus county's geoid and label, reused throughout.
state_boundaries <- read_clean("state_boundaries.rds")
state_map_data <- state_boundaries |>
  filter(state == focus_state)

county_boundaries <- read_clean("county_boundaries.rds")
county_map_data <- county_boundaries |>
  filter(state == focus_state)
focus_county_data <- county_map_data |>
  filter(county == focus_county)

focus_geoid <- focus_county_data$geoid
focus_label <- paste0(focus_county, " County")

# ---- State map ----
state_map <- ggplot(state_map_data) +
  geom_sf() +
  theme_void()

state_map

# ---- County map ----
# Draw the whole state in grey, then layer the focus county on top in green.
county_map <- ggplot() +
  geom_sf(data = state_map_data, fill = other_color, color = "white") +
  geom_sf(data = focus_county_data, fill = focus_fill, color = "grey40") +
  theme_void()

county_map

# ---- Median household income: focus county vs. rest of state ----
# A strip plot: one dot per county along the income axis, with the focus county
# highlighted so it is easy to see where it sits in the state's distribution.
income_by_county <- read_clean("median_household_income_by_county.rds") |>
  filter(state == focus_state) |>
  mark_focus()

focus_income <- income_by_county |>
  filter(is_focus) |>
  pull(median_household_income)

# All dots sit on one row (y = 1); the vertical jitter only spreads overlapping
# counties apart and carries no meaning (the report subtitle says so). The seed
# lives in position_jitter() because jitter is drawn at plot-build time (e.g.
# inside ggsave), not when this object is created.
income_plot <- ggplot(
  income_by_county,
  aes(x = median_household_income, y = 1)
) +
  geom_jitter(
    data = \(d) filter(d, !is_focus),
    position = position_jitter(width = 0, height = 0.18, seed = 1),
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
    x = NULL,
    y = NULL
  ) +
  theme_minimal() +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid = element_blank(),
    panel.grid.major.x = element_line(color = "grey92"),
    # Room for the outermost axis labels, which otherwise clip at the edges.
    plot.margin = margin(5.5, 15, 5.5, 15)
  )

income_plot

# ---- Population by race/ethnicity: focus county vs. state ----
# Paired horizontal bars: for each race/ethnicity group, the focus county's
# share of the population (green) sits above the statewide share (grey), so the
# reader can see where the county's composition diverges from the state. Groups
# are ordered by their share in the focus county. The focus county is pulled
# from the county table (matched by geoid, not name); the statewide figures come
# from the separate state table (official state estimates, built in
# import-data.R) rather than being summed from counties here.

# Three groups are each under 1% of the population; collapse them into "Other"
# so the chart stays legible and every bar is readable.
small_race_groups <- c(
  "American Indian and Alaska Native",
  "Native Hawaiian and Other Pacific Islander",
  "Some other race"
)

collapse_small_race_groups <- function(df) {
  df |>
    mutate(
      race_ethnicity = if_else(
        race_ethnicity %in% small_race_groups,
        "Other",
        race_ethnicity
      )
    )
}

# Collapse small groups, then each group's share of the geography's population.
compute_shares <- function(df, geo_label) {
  df |>
    collapse_small_race_groups() |>
    summarise(population = sum(population), .by = race_ethnicity) |>
    mutate(share = population / sum(population), geo = geo_label)
}

# Focus county shares (county table) and statewide shares (state table).
focus_race_shares <- read_clean(
  "population_by_county_and_race_ethnicity.rds"
) |>
  filter(geoid == focus_geoid) |>
  compute_shares(focus_label)

state_race_shares <- read_clean("population_by_state_and_race_ethnicity.rds") |>
  filter(state == focus_state) |>
  compute_shares(focus_state)

# Order groups by their share in the focus county, with "Other" pinned last.
# `rev()` because the first factor level sits at the bottom of a discrete axis.
race_order <- focus_race_shares |>
  arrange(desc(share)) |>
  pull(race_ethnicity)
race_order <- c(setdiff(race_order, "Other"), "Other")

race_shares <- bind_rows(focus_race_shares, state_race_shares) |>
  mutate(
    race_ethnicity = factor(race_ethnicity, levels = rev(race_order)),
    # state first so the green focus bar dodges to the top of each pair.
    geo = factor(geo, levels = c(focus_state, focus_label))
  )

# Two colors only (green focus, grey context), which is inherently
# colorblind-safe, unlike a per-category categorical palette. Direct labels at
# the bar ends carry the exact values, so no x axis is needed. The title is
# added downstream in Quarto rather than here.
race_fill_values <- set_names(
  c(focus_color, other_color),
  c(focus_label, focus_state)
)

# Instead of a legend, label the two bars of the top (largest) group directly:
# focus county inside the green bar, state inside the grey bar. White text reads
# on the dark green bar; dark text reads on the grey bar.
race_direct_labels <- race_shares |>
  filter(race_ethnicity == race_order[1])

race_label_colors <- set_names(
  c("white", "grey20"),
  c(focus_label, focus_state)
)

race_plot <- ggplot(
  race_shares,
  aes(x = share, y = race_ethnicity, fill = geo)
) +
  geom_col(
    position = position_dodge(width = 0.7),
    width = 0.65
  ) +
  geom_text(
    aes(label = scales::percent(share, accuracy = 1)),
    position = position_dodge(width = 0.7),
    hjust = -0.2,
    size = 3.1,
    color = "grey30"
  ) +
  geom_text(
    data = race_direct_labels,
    aes(x = 0.008, label = geo, color = geo),
    position = position_dodge(width = 0.7),
    hjust = 0,
    size = 3,
    show.legend = FALSE
  ) +
  scale_x_continuous(
    labels = scales::label_percent(),
    expand = expansion(mult = c(0, 0.12))
  ) +
  scale_fill_manual(values = race_fill_values, guide = "none") +
  scale_color_manual(values = race_label_colors, guide = "none") +
  labs(
    x = NULL,
    y = NULL
  ) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )

race_plot

# ---- Total population by county ----
# Ordered most to least populous, with the focus county flagged (by geoid, not
# name). The report renders this as a native Typst table in a multi-column
# "newspaper" layout; that layout code lives in report/report.qmd.
population_by_county <- read_clean("total_population_by_county.rds") |>
  filter(state == focus_state) |>
  mark_focus() |>
  arrange(desc(total_population))

n_counties <- nrow(population_by_county)

focus_population <- population_by_county |>
  filter(is_focus) |>
  pull(total_population)
