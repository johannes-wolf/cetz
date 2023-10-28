#import "/src/util.typ": linear-gradient

#let show-gradient(stops) = {
  let step = 5
  let width = .5cm
  block(for t in range(0, 105, step: step) {
    place(dx: width * t/step, dy: 0cm,
      rect(fill: linear-gradient(stops, t / 100), width: width * 1.1))
  }, inset: .5cm)
}

#show-gradient((blue,))
#show-gradient((blue, red))
#show-gradient((blue, red, green))
#show-gradient((blue, red, green, yellow))

#show-gradient(((0, blue), (.7, blue), (1, red)))
#show-gradient(((.4, blue), (.5, red), (.6, green)))
