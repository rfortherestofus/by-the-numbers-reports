# Data visualizations for the "by the numbers" reports.
#
# Reads the tidy datasets written by R/import-data.R (from data_clean/) and
# builds the figures for a state report. The state's data (boundaries, the
# county population table, statewide race shares) is loaded once; the
# county-specific figures are functions of a county geoid, so report/report.qmd
# can call them in a loop, once per county.
#
# Figures are exported without titles or subtitles: those live in the Typst
# layout (report/report.qmd), which sources this script for the plots and data.
here::i_am("R/data-viz.R")

library(here)
library(tidyverse)
library(sf)

# ---- Parameters ----
# Default for running this script interactively. report/report.qmd sets
# focus_state from its YAML metadata before sourcing, so the report is
# parameterized in one place. Must match the `state` column in the data.
if (!exists("focus_state")) focus_state <- "California"

# ---- Palette ----
# The accent (highlight) color is per state, read from the curated table in
# data_raw/state_colors.csv. This is the single source of truth for the accent:
# the Typst layout imports the same value via report/_state-theme.typ, which the
# report.qmd setup chunk writes from `focus_color` below.
state_colors <- read_csv(here("data_raw", "state_colors.csv"), show_col_types = FALSE)
state_color_row <- state_colors |> filter(state == focus_state)
if (nrow(state_color_row) != 1) {
  stop("data_raw/state_colors.csv needs exactly one row for state: ", focus_state)
}
focus_color <- state_color_row$accent[[1]]

# Lighter tint of the accent, for the filled focus county on the map and the
# band subtitle. Blends the accent toward white; base R only, no new dependency.
lighten <- function(hex, amount = 0.6) {
  blended <- (1 - amount) * col2rgb(hex) + amount * 255
  rgb(blended[1], blended[2], blended[3], maxColorValue = 255)
}
focus_fill <- lighten(focus_color, 0.6)
other_color <- "grey70" # non-focus / context

# Flag filename stem, e.g. "California" -> "california", "New York" -> "new_york".
state_slug <- focus_state |>
  str_to_lower() |>
  str_replace_all("[^a-z]+", "_") |>
  str_remove("_$")

# ---- Shared setup ----
read_clean <- function(name) read_rds(here("data_clean", name))

# Three race/ethnicity groups are each under ~1% of the population; collapse them
# into "Other" so the comparison chart stays legible and every bar is readable.
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

# ---- State-level data (loaded once, shared by every county) ----
state_map_data <- read_clean("state_boundaries.rds") |>
  filter(state == focus_state)

# County geometries for the locator map, keyed by geoid (the ACS tables and the
# boundary files name counties differently, so geoid is the only reliable key).
county_map_data <- read_clean("county_boundaries.rds") |>
  filter(state == focus_state)

# Median household income for every county in the state (the strip plot's dots).
income_by_county <- read_clean("median_household_income_by_county.rds") |>
  filter(state == focus_state)

# Total population per county, ordered most to least populous. The report renders
# this as a multi-column Typst table with the focus county flagged.
population_by_county <- read_clean("total_population_by_county.rds") |>
  filter(state == focus_state) |>
  arrange(desc(total_population))
n_counties <- nrow(population_by_county)

# Counties in alphabetical order, the order the report walks them in.
counties_alpha <- population_by_county |>
  arrange(county) |>
  select(geoid, county)

# Race/ethnicity counts per county, filtered to the state once.
county_race <- read_clean("population_by_county_and_race_ethnicity.rds") |>
  filter(state == focus_state)

# Statewide race shares and total population come from the official state
# estimates (built in import-data.R), not summed from counties. Computed once.
state_race_raw <- read_clean("population_by_state_and_race_ethnicity.rds") |>
  filter(state == focus_state)
state_race_shares <- compute_shares(state_race_raw, focus_state)
state_total_population <- sum(state_race_raw$population)

# ---- Per-county lookups ----
# The focus county's display label ("Los Angeles County"), taken straight from
# the ACS table (already carries the " County" suffix).
county_label <- function(focus_geoid) {
  population_by_county |>
    filter(geoid == focus_geoid) |>
    pull(county)
}

# The big-number values for a county's page 1.
county_stats <- function(focus_geoid) {
  list(
    label = county_label(focus_geoid),
    population = population_by_county |>
      filter(geoid == focus_geoid) |>
      pull(total_population),
    income = income_by_county |>
      filter(geoid == focus_geoid) |>
      pull(median_household_income)
  )
}

# ---- Per-county figures ----

# County locator map: the whole state in grey, the focus county filled with the
# accent tint on top.
county_map <- function(focus_geoid) {
  focus_geom <- county_map_data |> filter(geoid == focus_geoid)
  ggplot() +
    geom_sf(data = state_map_data, fill = other_color, color = "white") +
    geom_sf(data = focus_geom, fill = focus_fill, color = "grey40") +
    theme_void()
}

# Median household income strip plot: one dot per county along the income axis,
# with the focus county highlighted so the reader can see where it sits in the
# state's distribution. The vertical jitter only spreads overlapping counties
# apart and carries no meaning (the report subtitle says so). The seed lives in
# position_jitter() because jitter is drawn at plot-build time (inside ggsave),
# not when the object is created.
income_plot <- function(focus_geoid) {
  d <- income_by_county |> mutate(is_focus = geoid == focus_geoid)
  ggplot(d, aes(x = median_household_income, y = 1)) +
    geom_jitter(
      data = \(x) filter(x, !is_focus),
      position = position_jitter(width = 0, height = 0.18, seed = 1),
      color = other_color,
      size = 2.5,
      alpha = 0.8
    ) +
    geom_point(
      data = \(x) filter(x, is_focus),
      color = focus_color,
      size = 4.5
    ) +
    scale_x_continuous(labels = scales::label_dollar()) +
    scale_y_continuous(limits = c(0.4, 1.6)) +
    labs(x = NULL, y = NULL) +
    theme_minimal() +
    theme(
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      panel.grid = element_blank(),
      panel.grid.major.x = element_line(color = "grey92"),
      # Room for the outermost axis labels, which otherwise clip at the edges.
      plot.margin = margin(5.5, 15, 5.5, 15)
    )
}

# Population by race/ethnicity: paired horizontal bars, the focus county's share
# (accent) above the statewide share (grey) for each group, ordered by the
# county's share with "Other" pinned last. Two colors only, which is inherently
# colorblind-safe. Direct labels at the bar ends carry the values, so no x axis.
race_plot <- function(focus_geoid) {
  focus_label <- county_label(focus_geoid)

  focus_shares <- county_race |>
    filter(geoid == focus_geoid) |>
    compute_shares(focus_label)

  race_order <- focus_shares |>
    arrange(desc(share)) |>
    pull(race_ethnicity)
  race_order <- c(setdiff(race_order, "Other"), "Other")

  race_shares <- bind_rows(focus_shares, state_race_shares) |>
    mutate(
      race_ethnicity = factor(race_ethnicity, levels = rev(race_order)),
      # state first so the accent focus bar dodges to the top of each pair.
      geo = factor(geo, levels = c(focus_state, focus_label))
    )

  race_fill_values <- set_names(
    c(focus_color, other_color),
    c(focus_label, focus_state)
  )

  # Instead of a legend, label the two bars of the top (largest) group directly:
  # focus county inside the accent bar, state inside the grey bar. White text
  # reads on the dark accent bar; dark text reads on the grey bar.
  race_direct_labels <- race_shares |>
    filter(race_ethnicity == race_order[1])
  race_label_colors <- set_names(
    c("white", "grey20"),
    c(focus_label, focus_state)
  )

  ggplot(race_shares, aes(x = share, y = race_ethnicity, fill = geo)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.65) +
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
    labs(x = NULL, y = NULL) +
    theme_minimal() +
    theme(
      panel.grid = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank()
    )
}
