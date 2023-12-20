#import "util.typ"
#import "sample.typ"
#import "/src/draw.typ"

// Find contours of a 2D array by using marching squares algorithm
//
// - data (array): A 2D array of floats where the first index is the row and the second index is the column
// - offset (float): Z value threshold of a cell compare with `op` to, to count as true
// - op (auto,string,function): Z value comparison oparator:
//     / `">", ">=", "<", "<=", "!=", "=="`: Use the passed operator to compare z.
//     / `auto`: Use ">=" for positive z values, "<=" for negative z values.
//     / `<function>`: If set to a function, that function gets called
//       with two arguments, the z value `z1` to compare against and
//       the z value `z2` of the data and must return a boolean: `(z1, z2) => boolean`.
// - interpolate (bool): Enable cell interpolation for smoother lines
// - contour-limit (int): Contour limit after which the algorithm panics
// -> array: Array of contour point arrays
#let find-contours(data, offset, op: auto, interpolate: true, contour-limit: 50) = {
  assert(data != none and type(data) == array,
    message: "Data must be of type array")
  assert(type(offset) in (int, float),
    message: "Offset must be numeric")

  let n-rows = data.len()
  let n-cols = data.at(0).len()
  if n-rows < 2 or n-cols < 2 {
    return ()
  }

  assert(op == auto or type(op) in (str, function),
    message: "Operator must be of type auto, string or function")
  if op == auto {
    op = if offset < 0 { "<=" } else { ">=" }
  }
  if type(op) == str {
    assert(op in ("<", "<=", ">", ">=", "==", "!="),
      message: "Operator must be one of: <, <=, >, >=, != or ==")
  }

  // Return if data is set
  let is-set = if type(op) == function {
    v => op(offset, v)
  } else if op == "==" {
    v => v == offset
  } else if op == "!=" {
    v => v != offset
  } else if op == "<" {
    v => v < offset
  } else if op == "<=" {
    v => v <= offset
  } else if op == ">" {
    v => v > offset
  } else if op == ">=" {
    v => v >= offset
  }

  // Build a binary map that has 0 for unset and 1 for set cells
  let bin-data = data.map(r => r.map(is-set))

  // Get binary data at x, y
  let get-bin(x, y) = {
    if x >= 0 and x < n-cols and y >= 0 and y < n-rows {
      return bin-data.at(y).at(x)
    }
    return false
  }

  // Get data point for x, y coordinate
  let get-data(x, y) = {
    if x >= 0 and x < n-cols and y >= 0 and y < n-rows {
      return float(data.at(y).at(x))
    }
    return none
  }

  // Get case (0 to 15)
  let get-case(tl, tr, bl, br) = {
    int(tl) * 8 + int(tr) * 4 + int(br) * 2 + int(bl)
  }

  let lerp(a, b) = {
    if a == b { return a }
    else if a == none { return 1 }
    else if b == none { return 0 }
    return (offset - a) / (b - a)
  }

  // List of all found contours
  let contours = ()

  let segments = ()
  for y in range(-1, n-rows) {
    for x in range(-1, n-cols) {
      let tl = get-bin(x, y)
      let tr = get-bin(x+1, y)
      let bl = get-bin(x, y+1)
      let br = get-bin(x+1, y+1)

      // Corner data
      //
      // nw-----ne
      // |       |
      // |       |
      // |       |
      // sw-----se
      let nw = get-data(x, y)
      let ne = get-data(x+1, y)
      let se = get-data(x+1, y+1)
      let sw = get-data(x, y+1)

      // Interpolated edge points
      //
      // +-- a --+
      // |       |
      // d       b
      // |       |
      // +-- c --+
      let a = (x + .5, y)
      let b = (x + 1, y + .5)
      let c = (x + .5, y + 1)
      let d = (x, y + .5)
      if interpolate {
        a = (x + lerp(nw, ne), y)
        b = (x + 1, y + lerp(ne, se))
        c = (x + lerp(sw, se), y + 1)
        d = (x, y + lerp(nw, sw))
      }

      let case = get-case(tl, tr, bl, br)
      if case in (1, 14) {
        segments.push((d, c))
      } else if case in (2, 13) {
        segments.push((b, c))
      } else if case in (3, 12) {
        segments.push((d, b))
      } else if case in (4, 11) {
        segments.push((a, b))
      } else if case == 5 {
        segments.push((d, a))
        segments.push((c, b))
      } else if case in (6, 9) {
        segments.push((c, a))
      } else if case in (7, 8) {
        segments.push((d, a))
      } else if case == 10 {
        segments.push((a, b))
        segments.push((c, d))
      }
    }
  }

  // Join lines to one or more contours
  // This is done by searching for the next line
  // that starts at the current contours head or tail
  // point. If found, push the other coordinate to
  // the contour. If no line could be found, push a
  // new contour.
  let contours = ()
  while segments.len() > 0 {
    if contours.len() == 0 {
      contours.push(segments.remove(0))
    }

    let found = false

    let i = 0
    while i < segments.len() {
      let (a, b) = segments.at(i)
      let (h, t) = (contours.last().first(),
                    contours.last().last())
      if a == t {
        contours.last().push(b)
        segments.remove(i)
        found = true
      } else if b == t {
        contours.last().push(a)
        segments.remove(i)
        found = true
      } else if a == h {
        contours.last().insert(0, b)
        segments.remove(i)
        found = true
      } else if b == h {
        contours.last().insert(0, a)
        segments.remove(i)
        found = true
      } else {
        i += 1
      }
    }

    // Insert the next contour
    if not found {
      contours.push(segments.remove(0))
    }

    // Check limit
    assert(contours.len() <= contour-limit,
      message: "Countour limit reached! Raise contour-limit if you " +
                "think this is not an error")
  }

  return contours
}

// Prepare line data
#let _prepare(self, ctx) = {
  let (x, y) = (ctx.x, ctx.y)

  self.contours = self.contours.map(c => {
    c.stroke-paths = util.compute-stroke-paths(c.line-data,
      (x.min, y.min), (x.max, y.max))

    if self.fill {
      c.fill-paths = util.compute-fill-paths(c.line-data,
        (x.min, y.min), (x.max, y.max))
    }
    return c
  })

  return self
}

// Stroke line data
#let _stroke(self, ctx) = {
  for c in self.contours {
    for p in c.stroke-paths {
      draw.line(..p, fill: none, close: p.first() == p.last())
    }
  }
}

// Fill line data
#let _fill(self, ctx) = {
  if not self.fill { return }
  for c in self.contours {
    for p in c.fill-paths {
      draw.line(..p, stroke: none, close: p.first() == p.last())
    }
  }
}

/// Add a contour plot of a sampled function or a matrix.
///
/// #example(```
/// cetz.plot.plot(size: (2,2), x-tick-step: none, y-tick-step: none, {
///   cetz.plot.add-contour(x-domain: (-3, 3), y-domain: (-3, 3),
///     style: (fill: rgb(50,50,250,50)),
///     fill: true,
///     op: "<",        // Find contours where data < z
///     z: (2.5, 2, 1), // Z values to find contours for
///     (x, y) => calc.sqrt(x * x + y * y))
/// })
/// ```)
///
/// - data (array, function): A function of the signature `(x, y) => z`
///   or an array of arrays of floats (a matrix) where the first
///   index is the row and the second index is the column.
/// - z (float, array): Z values to plot. Contours containing values
///   above z (z >= 0) or below z (z < 0) get plotted.
///   If you specify multiple z values, they get plotted in the order of specification.
/// - x-domain (domain): X axis domain used if `data` is a function, that is the
///   domain inside the function gets sampled.
/// - y-domain (domain): Y axis domain used if `data` is a function, see `x-domain`.
/// - x-samples (int): X axis domain samples (2 < n). Note that contour finding
///   can be quite slow. Using a big sample count can improve accuracy but can
///   also lead to bad compilation performance.
/// - y-samples (int): Y axis domain samples (2 < n)
/// - interpolate (bool): Use linear interpolation between sample values which can
///   improve the resulting plot, especially if the contours are curved.
/// - op (auto,string,function): Z value comparison oparator:
///   / `">", ">=", "<", "<=", "!=", "=="`: Use the operator for comparison of `z` to
///     the values from `data`.
///   / `auto`: Use ">=" for positive z values, "<=" for negative z values.
///   / `<function>`: Call comparison function of the format `(plot-z, data-z) => boolean`,
///     where `plot-z` is the z-value from the plots `z` argument and `data-z`
///     is the z-value of the data getting plotted. The function must return true
///     if at the combinations of arguments a contour is detected.
/// - fill (bool): Fill each contour
/// - style (style): Style to use for plotting, can be used with a palette function. Note
///   that all z-levels use the same style!
/// - axes (axes): Name of the axes to use for plotting.
/// - limit (int): Limit of contours to create per z value before the function panics
/// - label (none,content): Plot legend label to show. The legend preview for
///   contour plots is a little rectangle drawn with the contours style.
#let add-contour(data,
                 label: none,
                 z: (1,),
                 x-domain: (0, 1),
                 y-domain: (0, 1),
                 x-samples: 25,
                 y-samples: 25,
                 interpolate: true,
                 op: auto,
                 axes: ("x", "y"),
                 style: (:),
                 fill: false,
                 limit: 50,
  ) = {
  // Sample a x/y function
  if type(data) == function {
    data = sample.sample-fn2(data,
                             x-domain, y-domain,
                             x-samples, y-samples)
  }

  // Find matrix dimensions
  assert(type(data) == array)
  let (x-min, x-max) = x-domain
  let dx = (x-max - x-min) / (data.at(0).len() - 1)
  let (y-min, y-max) = y-domain
  let dy = (y-max - y-min) / (data.len() - 1)

  let contours = ()
  let z = if type(z) == array { z } else { (z,) }
  for z in z {
    for contour in find-contours(data, z, op: op, interpolate: interpolate, contour-limit: limit) {
      let line-data = contour.map(pt => {
        (pt.at(0) * dx + x-min,
         pt.at(1) * dy + y-min)
      })

      contours.push((
        z: z,
        line-data: line-data,
      ))
    }
  }

  return ((
    type: "contour",
    label: label,
    contours: contours,
    axes: axes,
    x-domain: x-domain,
    y-domain: y-domain,
    style: style,
    fill: fill,
    mark: none,
    mark-style: none,
    plot-prepare: _prepare,
    plot-stroke: _stroke,
    plot-fill: _fill,
    plot-legend-preview: self => {
      if not self.fill { self.style.fill = none }
      draw.rect((0,0), (1,1), ..self.style)
    }
  ),)
}
