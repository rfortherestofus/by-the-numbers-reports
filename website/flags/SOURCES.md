# State flag images

SVG flags for all 50 states, the District of Columbia, and Puerto Rico, one per
file, named by the state slug the report uses (lowercase, spaces to underscores:
`new_york.svg`, `district_of_columbia.svg`).

U.S. state flags are official government insignia and the SVG renderings on
Wikimedia Commons are in the public domain, so they can be embedded in the
reports without attribution. Crediting Wikimedia Commons is good practice.

`R/data-viz.R` derives the flag filename from the state name; the state cover
page in `report/typst-template.typ` (`state-cover()`) embeds it.
