#import "/src/util.typ": linear-gradient
#import "/src/draw.typ"
#import "sample.typ"

/// Predefined Colormaps
#let colormap = (
  blue-red: (blue, red),
)

/// Add a heatmap
///
#let add-heatmap(data,
                 colormap: colormap.blue-red,
                 x-domain: (0, 1),
                 y-domain: (0, 1),
                 x-samples: 25,
                 y-samples: 25,
                 axes: ("x", "y"),
                 style: (:)) = {
  // Sample a x/y function
  if type(data) == function {
    data = sample.sample-fn2(data,
                             x-domain, y-domain,
                             x-samples, y-samples)
  }

  assert(type(data) == array)
  let rows = data.len()
  let (min, max) = (none, none)

  let dx = x-domain.at(1) - x-domain.at(0)
  let dy = y-domain.at(1) - y-domain.at(0)

  for y in range(0, rows) {
    let row = data.at(y)
    if min == none and max == none {
      min = calc.min(..row)
      max = calc.max(..row)
    } else {
      min = calc.min(..row, min)
      max = calc.max(..row, max)
    }
  }

  let prepare(self, ctx) = {
    return self
  }

  let fill(self, ctx) = {
    let (x0, x1) = (ctx.x.min, ctx.x.max)
    let (y0, y1) = (ctx.y.min, ctx.y.max)

    let (min-x, max-x) = x-domain
    let (min-y, max-y) = y-domain

    let data = self.data
    let sx = dx / data.first().len() / 3
    let sy = dy / data.len() / 3

    for m in range(0, data.len()) {
      let row = data.at(m)
      let y = min-y + m / (data.len() - 1) * dy
      for n in range(0, row.len()) {
        let x = min-x + n / (row.len() - 1) * dx
        if x >= x0 and x <= x1 and y >= y0 and y <= y1 { 
          let a = (calc.max(x - sx, x0), calc.max(y - sy, y0))
          let b = (calc.min(x + sx, x1), calc.min(y + sy, y1))
          let v = data.at(m).at(n)
          let color = linear-gradient(self.colormap, (self.normalize)(v))

          draw.rect(a, b, stroke: none, fill: color)
        }
      }
    }
  }

  return ((
    type: "heatmap",
    data: data,
    axes: axes,
    colormap: colormap,
    min-z: min,
    max-z: max,
    normalize: (v) => { v / (max - min) },
    x-domain: x-domain,
    y-domain: y-domain,
    style: style,
    plot-prepare: prepare,
    plot-fill: fill,
  ),)
}
