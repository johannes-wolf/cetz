#set page(width: auto, height: auto)
#import "/src/lib.typ": *

#box(stroke: 2pt + red, canvas({
  import draw: *

  plot.plot(size: (10, 10),
    x-tick-step: auto,
    y-tick-step: auto,
    y-max: 100,
    x-max: 2,
  {
    plot.add-boxwhisker(
        (
            outliers: (7, 65, 69),
            x: 1,
            min: 15,
            q1: 25,
            q2: 35,
            q3: 50,
            max: 60
        )
    )
  })
}))