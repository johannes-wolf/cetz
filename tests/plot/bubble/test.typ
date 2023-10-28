#set page(width: auto, height: auto)
#import "/src/lib.typ": *

#let data0 = (
  (1,1, 2),
  (1.5,2, 2),
  (2,2, (1)),
  (3,3, 1),
  (1,5, 1),
)

#let axis-range(axis, min, max, precision: 0) = {
    let x = (:)
    x.insert(axis + "-min", min)
    x.insert(axis + "-max", max)
    x.insert(axis + "-tick-step", calc.pow(10, calc.floor(calc.log(max - min - 0.00000000001) )))
    x.insert(axis + "-minor-tick-step", calc.pow(10, calc.floor(calc.log(max - min - 0.00000000001) ) - precision))
    return x
}

#box(stroke: 2pt + red, canvas({
  import draw: *

  plot.plot(size: (10, 10), ..axis-range("x", 0, 6),
                            ..axis-range("y", 0, 6),
  {
    plot.add-bubble(data0, scale-factor: 0.21)
  })
}))
