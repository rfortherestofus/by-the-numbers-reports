// Bridges Quarto and Typst: passes the document's YAML metadata into the
// report() template defined in typst-template.typ.
#show: body => report(
  county: [$county$],
  state: [$state$],
  body,
)
