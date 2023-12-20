#set page(width: auto, height: auto)
#import "../../src/lib.typ": *

#box(stroke: 2pt + red, canvas({
  import draw: *

  content(
    (0,0),
    image("image.png", width: 2cm),
    anchor: "north-west",
    name: "i"
  )

  set-style(radius: .1, fill: blue)
  for-each-anchor("i", anchor => {
    circle("i." + anchor)
  })

  fill(red);
  circle(("i.north-west", 0.75, "i.north-east"))
}))
