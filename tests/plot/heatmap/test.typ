#set page(width: auto, height: auto)
#import "/src/lib.typ": *

#let peaks(x, y) = (
  3 * calc.pow(1 - x, 2) * calc.exp(-(x*x) - calc.pow(y + 1, 2)) -
  10 * (x/5 - calc.pow(x, 3) - calc.pow(y, 5)) *
  calc.exp(-(x * x) - (y * y)) - 1/3 * calc.exp(-calc.pow(x + 1, 2) - (y * y))
)

/* Scientific Style */
#box(stroke: 2pt + red, canvas({
  import draw: *

  plot.plot(size: (6,4), {
    plot.add-heatmap(
      peaks,
      x-samples: 10,
      y-samples: 10,
      x-domain: (-4, 4),
      y-domain: (-4, 4))
  })
}))

