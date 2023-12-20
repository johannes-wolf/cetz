#set page(width: auto, height: auto)
#import "/src/lib.typ": *

/* Draw different marks */
#box(stroke: 2pt + red, canvas({
  import draw: *

  plot.plot(size: (5, 4),
    axis-style: "scientific",
    y-max: 2,
    y-min: -2,
    x-tick-step: 360,
    y-tick-step: 1,
    style: plot.palette.red,
    mark-style: plot.palette.red,
    {
      for (i, m) in ("o", "square", "x", "triangle", "|", "-").enumerate() {
        plot.add(domain: (i * 180, (i + 1) * 180),
          samples: 12,
          style: (stroke: none),
          mark: m,
          mark-size: .3,
          x => calc.sin(x * 1deg))
      }
    })
}))
