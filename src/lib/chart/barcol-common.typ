// Valid bar- and columnchart modes
#let barchart-modes = (
  "basic", "clustered", "stacked", "stacked100"
)

// Functions for max value calculation
#let barchart-max-value-fn = (
  basic: (data, value-key) => {
    calc.max(0, ..data.map(t => t.at(value-key)))
  },
  clustered: (data, value-key) => {
    calc.max(0, ..data.map(t => calc.max(
      ..value-key.map(k => t.at(k)))))
  },
  stacked: (data, value-key) => {
    calc.max(0, ..data.map(t =>
      value-key.map(k => t.at(k)).sum()))
  },
  stacked100: (..) => {
    100
  }
)

// Functions for min value calculation
#let barchart-min-value-fn = (
  basic: (data, value-key) => {
    calc.min(0, ..data.map(t => t.at(value-key)))
  },
  clustered: (data, value-key) => {
    calc.min(0, ..data.map(t => calc.max(
      ..value-key.map(k => t.at(k)))))
  },
  stacked: (data, value-key) => {
    calc.min(0, ..data.map(t =>
      value-key.map(k => t.at(k)).sum()))
  },
  stacked100: (..) => {
    0
  }
)
