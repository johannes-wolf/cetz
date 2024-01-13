#set page(width: auto, height: auto)
#import "/src/lib.typ": *

#let data = (
    (0, -0.12849636866747284), (1, 0.49277902517155295), (2, 2.350777963147003), (3, 3.887666049342328), (4, 3.864011102317047), (5, 4.352149160789927)
)

/* Simple plot */
#box(stroke: none, canvas({
  import draw: *

  plot.plot(size: (9, 6),
    x-tick-step: 1,
    y-tick-step: 1,
  {
    plot.add-fit(data, domain: (-1, 6),)
    plot.add(data, style: (stroke: none,), mark: "*")
  })
}))