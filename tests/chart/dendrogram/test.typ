#set page(width: auto, height: auto)
#import "/src/lib.typ": *

#let data = (
/* x1, x2, h */
  (4,  5,  1), // blue
  (1,  3,  1), // red
  (6,  7,  2), // green
  (2,  8,  2.5)
)

#let settings = (
  size: (auto, 6),
  line-style: (idx)=>{
    if idx == 0 { return (stroke: blue) }
    if idx == 1 { return (stroke: red) }
    if idx == 2 { return (stroke: green) }
    return (stroke: black)
  },
  /*x-ticks: (
    (1,[4]),
    (2,[5]),
    (3,[1]),
    (4,[3]),
    (5,[2]),
  )*/
)

#box(stroke: 2pt + red, canvas({
  chart.dendrogram(
    mode: "vertical",
    data,
    ..settings)
}))

#box(stroke: 2pt + red, canvas({
  chart.dendrogram(
    mode:"horizontal",
    data,
    ..settings)
}))
