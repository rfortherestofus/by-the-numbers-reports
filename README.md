# By the Numbers Reports

This repo pulls county-level U.S. Census data (American Community Survey, 5-year) and turns it into tidy datasets that power a "by the numbers" PDF report for each state and a published Quarto website.

The data covers every county in the country, so a single import produces datasets every state's report filters down from. Each state report is a cover page (the state flag and statewide totals), a table ranking every county by population, then a single-page demographic and economic profile for each county, ordered alphabetically. Each state's report is styled in a state accent color (see [State accent colors and flags](#state-accent-colors-and-flags)). A [companion website](#website) links to all the reports for download.

## How it works

1. `R/import-data.R` pulls data from the Census API via [`tidycensus`](https://walker-data.com/tidycensus/) and downloads boundary geometries via [`tigris`](https://github.com/walkerke/tigris).
2. Each table is cleaned into a tidy frame and written to `data_clean/` as an `.rds` file.
3. `R/data-viz.R` reads the cleaned datasets. It loads the focus state's data once (boundaries, the county population table, statewide race shares) and exposes the per-county figures as functions of a county geoid, so the report can call them once per county. The accent color comes from `data_raw/state_colors.csv`. Figures carry no titles; those live in the report layout.
4. `report/report.qmd` (Quarto + Typst) sources `R/data-viz.R`, exports each county's charts as SVG and its locator map as PNG (the map embeds the state boundary, which as vector art repeats megabytes per county; a small raster keeps large states well under Cloudflare's file-size cap), and emits the Typst for the cover page, the ranked county table, and each county's single-page profile. The focus state comes from the `BTN_STATE` environment variable (an env var, not `-M`, because knitr reads the YAML before Quarto applies metadata overrides); unset, it falls back to the YAML `state`. The setup chunk writes the accent color and state name into `report/_state-theme.typ`, which the template imports. All Typst layout code lives in `report/typst-template.typ`, wired up by `report/typst-show.typ` via Quarto's `template-partials` (the structure from [this tutorial](https://rfortherestofus.com/2025/11/quarto-typst-pdf)).
5. `R/render-reports.R` renders one report per state into `website/reports/`, where the website links to them.

### Datasets produced

Running `R/import-data.R` writes the following files to `data_clean/`. All county tables share a `geoid` column (5-digit state + county FIPS) that joins to `county_boundaries`, and a 2-digit `geoid` links states to `state_boundaries`.

| File | Contents |
| --- | --- |
| `median_household_income_by_county.rds` | Median household income per county (ACS `B19013_001`) |
| `population_by_county_and_race_ethnicity.rds` | Population by county broken out by race/ethnicity (ACS `B03002`) |
| `population_by_state_and_race_ethnicity.rds` | Population by state broken out by race/ethnicity (ACS `B03002`), for comparing a county against its state without summing counties |
| `total_population_by_county.rds` | Total population per county (ACS `B01003_001`) |
| `state_boundaries.rds` | Generalized state boundary geometries (cartographic) |
| `county_boundaries.rds` | Generalized county boundary geometries (cartographic) |

The ACS vintage and survey are set near the top of `R/import-data.R` (`acs_year`, `acs_survey`); bump `acs_year` as new 5-year releases land.

## Getting started

This project targets **R 4.5.2** (the version recorded in `renv.lock`).

1. **Restore the R environment.** This project uses [`renv`](https://rstudio.github.io/renv/). From an R session at the repo root:

   ```r
   renv::restore()
   ```

2. **Set a Census API key.** `tidycensus` reads it from the `CENSUS_API_KEY` environment variable. Get a free key at <https://api.census.gov/data/key_signup.html>, then run once:

   ```r
   tidycensus::census_api_key("YOUR_KEY", install = TRUE)
   ```

3. **Import the data.**

   ```r
   source("R/import-data.R")
   ```

   This fetches from the Census API and rewrites the `.rds` files in `data_clean/`.

4. **Render the reports.** To render one PDF per state into `website/reports/` (where the website links to them), from an R session at the repo root:

   ```r
   source("R/render-reports.R")
   ```

   This takes several minutes (all 50 states plus DC and Puerto Rico). To render only some states, set `states_to_render` before sourcing (e.g. `states_to_render <- c("California", "Oregon")`).

   To render a single state on its own, set `BTN_STATE` and render `report.qmd` directly. This writes `report/report.pdf` (gitignored, along with the intermediate `report.typ`, the generated `report/_state-theme.typ`, and `report/figures/`):

   ```sh
   BTN_STATE=Oregon quarto render report/report.qmd
   ```

   To render just one county (a single-county report: the state band, that county's profile, and the full ranked table with the county flagged), also set `BTN_COUNTY` to the bare county name (no " County" suffix):

   ```sh
   BTN_STATE=California BTN_COUNTY="Los Angeles" quarto render report/report.qmd
   ```

### State accent colors and flags

Each state's report is styled in a single accent color from `data_raw/state_colors.csv` (one row per state: `state`, `accent` hex, `accent_source`, `notes`). The colors are curated: a statutory state color where one exists and is distinctive, otherwise the state flag's signature color, all chosen dark enough for white text on the header band. Edit a row's `accent` to restyle that state's report; nothing else needs to change (`R/data-viz.R` reads the CSV, and the Typst layout imports the same value).

State flag SVGs live in `report/flags/` (one per state, named by slug, e.g. `new_york.svg`); they are public-domain Wikimedia Commons renderings and appear on each state report's cover page. See `report/flags/SOURCES.md`.

## Repo structure

- `R/`: All R code, including `import-data.R` (data import), `data-viz.R` (report figures), and `render-reports.R` (renders one report per state). May contain subdirectories.
- `data_raw/`: Raw or curated inputs, including `state_colors.csv` (the per-state accent colors).
- `data_clean/`: Tidy datasets, written as `.rds`. For data spanning many years or lots of interconnected processing, consider a Neon Postgres database instead.
- `report/`: The PDF report. `report.qmd` holds the content and R chunks; `typst-template.typ` defines the layout (page setup, header band, cover page, helper functions); `typst-show.typ` wraps the body in the template; `flags/` holds the state flag SVGs. `wireframe.typ` is the standalone layout mockup the design came from (`typst compile report/wireframe.typ outputs/wireframe.pdf`); it keeps the original green as a static mockup and is not wired to the per-state accent colors.
- `outputs/`: Generated artifacts such as PDFs. Everything here is gitignored, so it is safe for local testing. Share data through a dedicated Cloudflare R2 bucket rather than committing it.
- `website/`: A Quarto website (see [Website](#website)). `index.qmd` builds the download grid; `reports/` holds the rendered PDFs and `flags/` the thumbnails. The built `_site/` directory is committed (Cloudflare Pages serves it directly).

## Website

`website/` is a one-page Quarto site: a grid of cards, one per state (flag thumbnail, state name in the state's accent color), each linking to that state's report PDF for download. `index.qmd` builds the grid from `data_raw/state_colors.csv`, so it stays in step with the reports.

The report PDFs (`website/reports/`) and flag thumbnails (`website/flags/`) are static files that the grid links to. Build the site with:

```sh
quarto render website
```

This writes `website/_site`, the fully static site (index page, the report PDFs, and the flags).

### Deployment

Deployment is a plain static host, no CI: Cloudflare Pages is connected to this repo with **no build command** and its output directory set to `website/_site`. It serves whatever is committed there, so `website/_site` is committed (not gitignored).

To publish an update: regenerate the reports if needed (`R/render-reports.R`), run `quarto render website`, and commit the updated `website/_site` (and `website/reports/`). Cloudflare redeploys on push. Because Cloudflare does not run R or Quarto, the built `_site` has to be committed rather than rendered in the cloud.
