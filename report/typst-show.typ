// Bridges Quarto and Typst: wraps the document body in the report() template
// defined in typst-template.typ. The report is branded to the state via
// report-state (from _state-theme.typ); the county spreads are emitted from
// report.qmd.
#show: body => report(body)
