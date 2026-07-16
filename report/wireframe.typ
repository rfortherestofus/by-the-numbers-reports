// Wireframe for the "by the numbers" report layout.
//
// Placeholder boxes stand in for the figures from R/data-viz.R; all titles,
// stat callouts, and the county table are real Typst so the typography and
// hierarchy can be judged. Compile with:
//   typst compile report/wireframe.typ outputs/wireframe.pdf

// ---- Palette (mirrors R/data-viz.R) ----
#let focus-color = rgb("#4C7A2F")
#let focus-fill = rgb("#A8C686")
#let other-color = rgb("#b3b3b3")
#let ink = rgb("#333333")

// ---- Report parameters ----
// These mirror focus_state / focus_county in R/data-viz.R. Values shown are
// approximate; the real report will interpolate computed numbers.
#let focus-state = "California"
#let focus-county = "Los Angeles County"
#let n-counties = "58"

// ---- Page setup ----
#set page(
  paper: "us-letter",
  margin: (x: 0.75in, top: 0.75in, bottom: 0.9in),
  footer: context [
    #set text(size: 8pt, fill: gray)
    #focus-county: By the Numbers
    #h(1fr)
    #counter(page).display()
  ],
)
#set text(font: "Helvetica Neue", size: 10pt, fill: ink)
#set par(leading: 0.6em)

// ---- Helpers ----

// Green highlight pill for the focus county, the Typst equivalent of the
// marquee `{.hl ...}` span. Doubles as an inline legend key for green bars.
#let hl(body) = box(
  fill: focus-color,
  radius: 0.2em,
  inset: (x: 0.35em, y: 0.1em),
  baseline: 0.25em,
  text(fill: white, body),
)

// Gray pill: inline legend key for the gray context marks (state figures,
// other counties).
#let hl-gray(body) = box(
  fill: other-color,
  radius: 0.2em,
  inset: (x: 0.35em, y: 0.1em),
  baseline: 0.25em,
  text(fill: rgb("#333333"), body),
)

// Dashed placeholder standing in for a figure exported from R.
#let placeholder(label, height: 2.2in) = rect(
  width: 100%,
  height: height,
  stroke: (paint: gray, thickness: 0.75pt, dash: "dashed"),
  fill: luma(250),
  radius: 4pt,
  align(center + horizon, text(fill: gray, size: 9pt, style: "italic", label)),
)

// Big-number stat tile.
#let stat(number, label) = block(
  width: 100%,
  inset: (y: 0.2em),
)[
  #text(size: 26pt, weight: "bold", fill: focus-color, number) \
  #text(size: 9pt, fill: luma(40%), upper(label))
]

// Section title + optional subtitle, replacing in-chart ggplot/gt titles.
#let section-title(title, subtitle: none) = block(above: 1.6em, below: 0.9em)[
  #text(size: 14pt, weight: "bold", title)
  #if subtitle != none [
    \ #text(size: 9pt, fill: luma(40%), subtitle)
  ]
]

// =====================================================================
// PAGE 1 — Big numbers, where the county is, and the full population list
// =====================================================================

// Header band, bleeding through the margins to the top and side page edges.
#block(
  width: 100%,
  fill: focus-color,
  inset: (x: 0.6in, bottom: 0.35in, top: 0.1in),
  outset: (x: 0.75in, top: 0.75in),
)[
  #text(fill: white, size: 26pt, weight: "bold")[#focus-county] \
  #text(fill: focus-fill, size: 16pt, weight: "medium")[By the Numbers] \
  #v(0.2em)
  #text(fill: white.transparentize(25%), size: 9pt)[
    A demographic and economic profile from the American Community Survey
    (5-year estimates)
  ]
]

#v(0.3in)

// Stat column on the left, locator map on the right. The map box is squarish
// so any state's shape fits inside it without redesigning the grid.
#grid(
  columns: (1fr, 2.5in),
  column-gutter: 0.4in,
  align: horizon,
  [
    #stat("9,936,690", "Total population")
    #v(0.25in)
    #stat("$83,411", "Median household income")
  ],
  placeholder(
    [County locator map \ (state in grey, #focus-county in green) \ squarish box: any state shape scales inside],
    height: 2.4in,
  ),
)

#section-title(
  [Total Population],
  subtitle: [Every #focus-state county, ordered from most to least populous],
)

// Native Typst version of the two-column "newspaper" table (replaces gt).
// Sample rows only; the real report generates one row per slot from
// population_table_data and will flow onto page 2 if it runs long. Focus
// county styled bold + green, keyed by geoid.
#let county-cell(name, pop, focus: false) = {
  let style = if focus { (weight: "bold", fill: focus-color) } else { (:) }
  (
    align(left, text(..style, name)),
    align(right, text(..style, pop)),
  )
}

#{
  set text(size: 9pt)
  table(
    columns: (1fr, auto, 0.35in, 1fr, auto),
    stroke: none,
    inset: (y: 0.45em),
    table.header(
      align(left, text(size: 8pt, fill: luma(40%), upper[County])),
      align(right, text(size: 8pt, fill: luma(40%), upper[Population])),
      [],
      align(left, text(size: 8pt, fill: luma(40%), upper[County])),
      align(right, text(size: 8pt, fill: luma(40%), upper[Population])),
    ),
    table.hline(stroke: 0.5pt + luma(70%)),
    ..county-cell("Los Angeles", "9,936,690", focus: true), [],
    ..county-cell("Placer", "404,739"),
    ..county-cell("San Diego", "3,298,634"), [],
    ..county-cell("Merced", "281,202"),
    ..county-cell("Orange", "3,186,989"), [],
    ..county-cell("Butte", "211,632"),
    ..county-cell("Riverside", "2,418,185"), [],
    ..county-cell("Yolo", "216,403"),
    align(center, text(fill: gray)[⋮]), [], [],
    align(center, text(fill: gray)[⋮]), [],
    ..county-cell("Sierra", "3,236"), [],
    ..county-cell("Alpine", "1,204"),
  )
}

#pagebreak()

// =====================================================================
// PAGE 2 — The comparison charts
// =====================================================================

#section-title(
  [Population by Race/Ethnicity],
  subtitle: [Share of total population in #hl[#focus-county] and #hl-gray[#focus-state] as a whole],
)

#placeholder(
  [Race/ethnicity paired-bar chart (race_plot) \ exported without title, axes labelled in-figure],
  height: 3.4in,
)

#section-title(
  [Median Household Income],
  subtitle: [#hl[#focus-county] among #hl-gray[all #n-counties #focus-state counties]; dots are spread vertically only to avoid overlap],
)

#placeholder(
  [Income strip plot (income_plot) \ full text width, short: do not put this in a column],
  height: 1.7in,
)

#v(1fr)

// Sources / methodology note anchors the bottom of the last page.
#line(length: 100%, stroke: 0.5pt + luma(85%))
#v(0.5em)
#text(size: 8pt, fill: luma(40%))[
  *Sources and notes.* All figures are American Community Survey 5-year
  estimates (table numbers here), retrieved via the Census Bureau API.
  Boundaries are Census cartographic files. Estimates carry margins of error,
  not shown. Report generated (date).
]
