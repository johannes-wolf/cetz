#set page(width: auto, height: auto)
#import "/src/lib.typ": *
#import "/tests/helper.typ": *

#let union-path = cetz.draw.union-path
#let intersection-path = cetz.draw.intersection-path
#let difference-path = cetz.draw.difference-path

#let triangle = cetz.draw.line((-1,-.5), (0,1), (+1,-.5))
#let circle = cetz.draw.circle((0,0))
#let rect = cetz.draw.rect((0,0), (rel: (1,1)))

#test-case(((a, b)) => {
  union-path(a, b, fill: blue)
  intersection-path(a, b, fill: red)
  difference-path(a, b, fill: green)
}, args: (
  (triangle, rect),
  (circle, rect),
  (cetz.draw.circle((-.3,0)), cetz.draw.circle((.3,0)))
))
