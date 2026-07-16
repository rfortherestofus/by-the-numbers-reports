# By the Numbers Reports

This repo pulls county-level U.S. Census data (American Community Survey, 5-year) and turns it into tidy datasets that can power "by the numbers" style reports and a published Quarto website.

The data covers every county in the country, so a single import produces datasets that any single-state (or multi-state) report can filter down from.

## How it works

1. `R/import-data.R` pulls data from the Census API via [`tidycensus`](https://walker-data.com/tidycensus/) and downloads boundary geometries via [`tigris`](https://github.com/walkerke/tigris).
2. Each table is cleaned into a tidy frame and written to `data_clean/` as an `.rds` file.
3. `R/data-viz.R` reads the cleaned datasets and builds the figures for a single-state report. The focus state and county are set as parameters at the top of the script. Figures carry no titles; those live in the report layout.
4. `report/report.qmd` (Quarto + Typst) sources `R/data-viz.R`, exports the figures as SVG, and lays out the PDF report. The focus county and state are set in its YAML header, which feeds both the Typst template and the R code. All Typst layout code lives in `report/typst-template.typ`, wired up by `report/typst-show.typ` via Quarto's `template-partials` (the structure from [this tutorial](https://rfortherestofus.com/2025/11/quarto-typst-pdf)). The Quarto site in `website/` also reads from the cleaned datasets.

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

4. **Render the report.**

   ```sh
   quarto render report/report.qmd
   ```

   This writes `report/report.pdf` (gitignored, along with the intermediate `report.typ` and `report/figures/`).

## Repo structure

- `R/`: All R code, including `import-data.R` (data import) and `data-viz.R` (report figures). May contain subdirectories.
- `data_raw/`: Raw, not-yet-cleaned files (for example, small files delivered by a client).
- `data_clean/`: Tidy datasets, written as `.rds`. For data spanning many years or lots of interconnected processing, consider a Neon Postgres database instead.
- `report/`: The PDF report. `report.qmd` holds the content and R chunks; `typst-template.typ` defines the layout (page setup, header band, helper functions); `typst-show.typ` passes the YAML metadata into the template. `wireframe.typ` is the standalone layout mockup the design came from (`typst compile report/wireframe.typ outputs/wireframe.pdf`).
- `outputs/`: Generated artifacts such as PDFs. Everything here is gitignored, so it is safe for local testing. Share data through a dedicated Cloudflare R2 bucket rather than committing it.
- `website/`: A Quarto website for publishing to the client. The rendered `_site/` directory is gitignored so auto-generated files do not bloat commits. See [Publishing the website](#publishing-the-website).
- `.github/workflows/`: GitHub Actions. Currently just `publish.yml`, which renders and deploys the website to Cloudflare.
