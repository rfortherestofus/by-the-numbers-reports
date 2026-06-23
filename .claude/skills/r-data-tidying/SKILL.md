---
name: r-data-tidying
description: Use when importing and tidying raw data (Excel, CSV, API dumps) into tidy RDS/parquet outputs in R. Covers directory conventions, pivoting patterns, problem-sheet tactics, and the "one tidy frame per relationship, not per source file" mindset.
---

# R Data Tidying

Guidance for turning messy source data (especially Excel workbooks) into a set of clean, tidy, saved tables. Pairs with `r-guidance` (which covers general tidyverse style). This skill is about the *shape* and *organization* of the output, not just the syntax.

## Core mindset

**One tidy frame per relationship, not one per source sheet.**

The natural temptation is "there are 6 sheets, so I'll make 6 RDS files." Resist it. The right unit is a **relationship between entities**, not a source tab. A single sheet may contain three relationships stacked side-by-side as column groups, and two sheets may be subsets of the same relationship.

Before writing any code, list the entities (places, ZIPs, counties, FAR levels, …) and the relationships between them. Each relationship → one tidy table.

## Tidy data checklist

A frame is tidy when:

1. Each variable is a column.
2. Each observation is a row.
3. One observational unit per table.
4. No derivable columns (drop totals that are sums of other columns — they'll go stale).
5. Column **names** are snake_case; column **values** are human-readable (often Title Case for categorical labels).

## Directory convention

```
project/
  data-raw/     # source files, never edited by scripts
  data-clean/   # outputs — safe to delete and rebuild
```

Rebuild `data-clean/` from scratch every run so stale outputs can't pollute downstream analysis:

```r
library(fs)
dir_delete("data-clean")
dir_create("data-clean")
```

Never write RDS alongside the raw source — you want one-click reproducibility and a clear provenance arrow (raw → clean).

## Standard import pipeline

```r
raw <- read_excel("data-raw/workbook.xlsx", sheet = "Sheet Name") |>
  clean_names() |>          # snake_case column names
  rename(                   # rename to domain-friendly terms
    place    = truncated_name,
    rurality = tfff_rural_urban_designation
  ) |>
  select(-c(census_geographic_area_name, notes))  # drop noise
```

Three steps every time: `clean_names()` → `rename()` for clarity → `select()` to drop columns you don't need downstream. Do this *before* splitting into relationship tables so every derived table inherits the cleanup.

## Pivot patterns for "wide family" columns

These are untidy patterns to watch for. Each has the same fix: pivot longer.

### 1. Ordered-suffix families → long

```
usps_city_1, usps_city_2, usps_city_3
main_county, additional_counties
primary_county, secondary_county, tertiary_county
```

These are the same variable repeated. Pivot into one column plus a rank/type column:

```r
zips_by_place <- zip_codes |>
  select(zip, starts_with("usps")) |>
  pivot_longer(-zip, names_to = "city_number", values_to = "place") |>
  mutate(city_number = parse_number(city_number)) |>
  drop_na(place)
```

### 2. Role-labeled families → long with role column

```r
places_by_county <- places |>
  select(place, main_county, additional_counties) |>
  pivot_longer(-place, names_to = "county_type", values_to = "county") |>
  mutate(county_type = case_when(
    county_type == "main_county"         ~ "Main",
    county_type == "additional_counties" ~ "Secondary"
  )) |>
  drop_na(county)
```

### 3. Mutually-exclusive 0/1 flags → single level column

If you see `far_level_1`, `far_level_2`, `far_level_3`, `far_level_4` and each row has exactly one `1`, those aren't four variables — they're one variable (the level) encoded as indicators. Collapse with `sum()`:

```r
zips_by_far_level <- zip_codes |>
  select(zip, starts_with("far")) |>
  pivot_longer(-zip) |>
  summarize(far_level = sum(value), .by = zip)
```

This is easy to miss when the columns arrive from a wide export. If every row sums to 1 across a family, collapse.

### 4. Grouped headers (Count block + Percentage block) → long with metric column

Either pivot twice (once per block) and `pivot_wider(names_from = metric)` to get them paired, or — often simpler — **just don't read the second block**. If the percentages are derivable from the counts, skip them.

## Tactical escape hatches for messy sheets

### Use `range =` instead of fighting `skip`/`col_names`

When a sheet has a two-row merged header, a spacer column, and a trailing metadata block, don't try to name all 18 columns and filter. Just grab the rectangle you want:

```r
pop <- read_excel(
  "data-raw/workbook.xlsx",
  sheet = "County-Based Pop Summaries",
  range = "A2:G40"     # header row + data rows, only the columns you need
) |>
  clean_names()
```

This sidesteps spacer columns and grouped headers in one line. Prefer this over `skip = 2` + explicit `col_names` whenever the shape is stable.

### Drop derivable columns on sight

`total` columns, subtotal rows, percentage-of-total columns — if they're a function of other columns, drop them. They rot the moment the underlying data changes.

### `set_names()` after pivoting for compact renames

When you need to rename a bunch of columns at once in a known order:

```r
pop |> set_names(c(
  "geography", "geography_type", "population_total",
  "population_rural_cities_towns", "population_rural_cdps",
  "population_urban_cities_towns", "population_urban_cdps",
  "population_outside_cdps"
))
```

Then `pivot_longer()` on a shared prefix (`starts_with("population_")`) + `str_remove("population_")` + `case_when()` to split into `urban_rural` × `place_type`.

## Value-level cleaning

Column names are snake_case. Values are for humans.

```r
|>
  mutate(geography = str_to_title(geography)) |>           # "oregon" -> "Oregon"
  mutate(geography = str_remove(geography, ", Ca")) |>     # strip state suffix
  mutate(county_type = str_to_title(county_type))          # "main" -> "Main"
```

Common value cleaners:

- `str_to_title()` — categorical labels and place names
- `str_remove()` / `str_replace()` — strip noise suffixes like `", CA"` or trailing footnote markers
- `parse_number()` — pull numbers out of strings like `"far_level_3"` or `"$1,234"`
- `as.integer()` — after `parse_number()` when you want integer storage

## Add derived columns that encode analytical decisions

Don't make downstream analysts re-derive the same grouping every time. Bake it in:

```r
|>
  mutate(geography_type = case_when(
    geography == "Oregon" ~ "State",
    .default = "County"
  ))
```

Other common ones: `urban_rural`, `region`, `size_bucket`. If a categorical split will be used in every downstream analysis, add it in the cleaning layer.

**Judgment calls belong here, not in every analysis file.** e.g. "outside CDPs counts as Rural" is a decision — make it once, document it, and embed it in the clean data.

## Saving outputs

```r
output |> write_rds("data-clean/places_by_county.rds")
```

File name = object name = the relationship the table represents. `places_by_county`, `zips_by_place`, `zips_by_far_level` — reading the filename should tell you the grain.

For larger data, `arrow::write_parquet()` is a drop-in replacement with better cross-language support.

## Worked example shape

For a workbook with places, ZIP codes, and population summaries, a good output set looks like:

```
data-clean/
  places_by_type_and_rurality.rds   # one row per place
  places_by_county.rds              # one row per (place, county) — long
  zips_by_place.rds                 # one row per (zip, place) — long
  zips_by_far_level.rds             # one row per zip, single far_level
  zips_by_county.rds                # one row per (zip, county) — long
  population_summaries.rds          # one row per (geography, urban_rural, place_type)
```

Note what's *not* there: no `or_cities.rds` + `or_cdps.rds` + `siskiyou_places.rds` (those were subsets of a combined sheet — redundant). No `county_percentages.rds` (derivable from counts). No wide tables with `_1/_2/_3` column families.

## Anti-patterns

- **One file per source sheet.** Groups data by where it came from, not by what it means.
- **Keeping `total` columns alongside the parts.** They go stale.
- **Leaving wide families wide** (`col_1`, `col_2`, `col_3`). Untidy and awkward to filter/summarize.
- **Writing RDS files into the same directory as the source `.xlsx`.** Breaks the raw/clean split.
- **`skip =` + explicit `col_names` on every messy sheet** when `range = "A2:G40"` would be three characters and zero debugging.
- **Snake_casing value strings** (`"rural_cities_towns"` as a cell value). Snake_case is for names, not labels.
- **Leaving mutually-exclusive indicator columns un-collapsed.** Four `far_level_*` columns is the un-tidy form of one `far_level` column.

## Quick review checklist

When reviewing a cleaning script, ask:

1. Are raw inputs and clean outputs in separate directories?
2. Is the clean directory rebuilt from scratch?
3. Does each output file correspond to one relationship, not one source sheet?
4. Are column names snake_case and values human-readable?
5. Are all wide families (`_1/_2/_3`, `main/secondary`, `primary/secondary/tertiary`, mutually-exclusive flags) pivoted long?
6. Are derivable columns (totals, percentages of totals) dropped?
7. Are analytical groupings (urban/rural buckets, geography types) baked in as columns?
8. Did the script use `range =` when it would have been simpler than `skip =` + `col_names`?
