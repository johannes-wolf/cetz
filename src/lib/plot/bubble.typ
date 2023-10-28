#import "../../draw.typ"

#let _stroke(self, ctx) = {

  let (x,y) = (ctx.x, ctx.y)
  let plot-size = (10, 10)
  // Scale marks back to canvas scaling
  let (sx, sy) = plot-size
  sx = sx / (x.max - x.min)
  sy = sy / (y.max - y.min)

  for (idx, d) in self.data.enumerate() {
    let (pt-x,pt-y) = (d.at(self.x-key), d.at(self.y-key))
    if ( pt-x < x.min or pt-x > x.max ) { continue }
    if ( pt-y < y.min or pt-y > y.max ) { continue }

    let size = (self.mark-size)(idx)
    draw.circle(d, radius: self.scale-factor * size)
  }
}

#let add-bubble( data,
                 axes: ("x", "y"),
                 style: (:),
                 x-key: 0,
                 y-key: 1,
                 z-key: 2,
                 scale-factor: 1,
                 iterations: 0

) = {
  let pts = data.map(t=>{(t.at(x-key), t.at(y-key))})
  let sizes = array.at.with(data.map(t=>t.at(z-key)))

  // Calculate extent
  let calculate-extent(key, scale: 1) = (
    return (it) => {
      let size = it.at(z-key)
      if type(size) in (array, dictionary) {size = size.at(key)}
      return it.at(key) + scale * (scale-factor*size)
    }
  )
  
  // domains
  let calculate-domain(key) = {
    let min-most = calc.min(..data.map(calculate-extent(key, scale: -1)))
    let max-most = calc.max(..data.map(calculate-extent(key, scale: +1)))
    return (min-most, max-most)
  }

  let x-domain = calculate-domain(x-key)
  let y-domain = calculate-domain(y-key)

  return ((
    type: "bubble",
    data: pts,
    axes: axes,
    style: style,
    mark-size: sizes,
    mark-style: style,
    x-domain: x-domain,
    y-domain: y-domain,
    x-key: x-key,
    y-key: y-key,
    z-key: z-key,
    scale-factor: scale-factor,
    plot-stroke: _stroke
  ),)

}