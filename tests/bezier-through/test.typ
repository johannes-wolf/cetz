#set page(width: auto, height: auto)
#import "../../src/lib.typ": *

#block(stroke: 2pt + red, canvas(length: .5cm, {
  import draw: *

  let curve-through(a, b, c) = {
    group(name: "g", {
      line(a, b, c, stroke: gray)
      bezier-through(a, b, c)
    })
    set-origin((c.at(0) + .1, 0))
  }

  curve-through((0,0), (1,0), (2,0))
  curve-through((0,0), (1,2), (2,0))
  curve-through((0,0), (1,-2), (2,0))
  curve-through((0,0), (0,2), (2,0))
  curve-through((0,0), (2,2), (2,0))
}))

#block(stroke: 2pt + red, canvas(length: .5cm, {
  import draw: *

  merge-path(close: true, {
    bezier-through((-1, 0), (-calc.cos(45deg), calc.sin(45deg)), (0, 1))
    bezier-through((0, 1), (calc.cos(45deg), calc.sin(45deg)), (1, 0))
    bezier-through((1, 0), (calc.cos(45deg), -calc.sin(45deg)), (0, -1))
    bezier-through((0, -1), (-calc.cos(45deg), -calc.sin(45deg)), (-1, 0))
  })
}))

#block(stroke: 2pt + red, canvas(length: .5cm, {
  import draw: *

  set-style(mark: (start: "<", end: ">", fill: none, size: .3))
  bezier-through((.5,0), (1,1), (1.5,0))
  bezier-through((0,0), (1,-2), (2,0), mark: (start: "|", end: "<", size: .5))
  bezier-through((-1,0), (1,0), (3,0), mark: (start: "<", end: "o", size: .2))
}))
