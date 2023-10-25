#set page(width: auto, height: auto)
#import "/src/lib.typ": *

#let data0 = (
  (
    label: "A",
    min: 10,q1: 25,q2: 50,
    q3: 75,max: 90
  ),
  (
    label: "b",
    min: 32,q1: 54,q2: 60,
    q3: 69,max: 73,
    outliers: (18, 23, 78,)
  ),
)

#box( canvas({
  chart.boxwhisker(
    y-max: 100,
                 size: (5, 5),
                 label-key: "label",
                 data0)
}))