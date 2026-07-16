# Render one "by the numbers" report per state.
#
# Renders report/report.qmd once for each state in data_raw/state_colors.csv and
# writes the PDFs to outputs/<state-slug>-by-the-numbers.pdf. Run it with:
#
#   source("R/render-reports.R")
#
# To render only some states, set `states_to_render` below to a subset before
# sourcing (e.g. states_to_render <- c("California", "Oregon")).
here::i_am("R/render-reports.R")

library(here)
library(tidyverse)

# States to render. Defaults to every state in the color table; override by
# assigning `states_to_render` before sourcing this file.
all_states <- read_csv(
  here("data_raw", "state_colors.csv"),
  show_col_types = FALSE
)$state
if (!exists("states_to_render")) {
  states_to_render <- all_states
}

report_qmd <- here("report", "report.qmd")
rendered_pdf <- here("report", "report.pdf")
out_dir <- here("outputs")
dir.create(out_dir, showWarnings = FALSE)

# "New York" -> "new_york", matching the flag filenames and the state slug in
# R/data-viz.R.
state_slug <- function(s) {
  s |>
    str_to_lower() |>
    str_replace_all("[^a-z]+", "_") |>
    str_remove("_$")
}

render_one <- function(state) {
  message("Rendering ", state, " ...")
  # report.qmd reads BTN_STATE (see its setup chunk for why an env var rather
  # than -M); the child quarto process inherits it from this session.
  Sys.setenv(BTN_STATE = state)
  status <- system2(
    "quarto",
    c("render", report_qmd),
    stdout = TRUE,
    stderr = TRUE
  )
  # quarto always writes report/report.pdf; move it to a per-state name so the
  # next state does not overwrite it.
  if (!file.exists(rendered_pdf)) {
    warning("No PDF produced for ", state, ":\n", paste(status, collapse = "\n"))
    return(NA_character_)
  }
  dest <- file.path(out_dir, paste0(state_slug(state), "-by-the-numbers.pdf"))
  file.copy(rendered_pdf, dest, overwrite = TRUE)
  file.remove(rendered_pdf)
  dest
}

results <- tibble(state = states_to_render) |>
  mutate(pdf = map_chr(state, render_one))

message(
  "\nDone. ",
  sum(!is.na(results$pdf)),
  " of ",
  nrow(results),
  " reports written to ",
  out_dir,
  "."
)
failed <- results |> filter(is.na(pdf))
if (nrow(failed) > 0) {
  message("Failed: ", paste(failed$state, collapse = ", "))
}
