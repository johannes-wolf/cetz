// CeTZ Library for drawing graph axes
#import "/src/util.typ"
#import "/src/draw.typ"
#import "/src/vector.typ"
#import "/src/styles.typ"
#import "/src/process.typ"
#import "/src/drawable.typ"
#import "/src/path-util.typ"

#let typst-content = content

// Global defaults
#let default-style = (
  tick-limit: 100,
  minor-tick-limit: 1000,
  auto-tick-factors: (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10), // Tick factor to try
  auto-tick-count: 11, // Number of ticks the plot tries to place
  fill: none,
  stroke: auto,
  label: (
    offset: .2cm,       // Axis label offset
    anchor: auto,       // Axis label anchor
    angle:  auto,       // Axis label angle
  ),
  axis-layer: 0,
  grid-layer: 0,
  background-layer: 0,
  tick: (
    fill: none,
    stroke: black + 1pt,
    minor-stroke: black + .5pt,
    offset: 0,
    minor-offset: 0,
    length: .1cm,       // Tick length: Number
    minor-length: 80%,  // Minor tick length: Number, Ratio
    label: (
      offset: .2cm,     // Tick label offset
      angle: 0deg,      // Tick label angle
      anchor: auto,     // Tick label anchor
    )
  ),
  grid: (
    stroke: (paint: gray.lighten(50%), thickness: 1pt),
  ),
  minor-grid: (
    stroke: (paint: gray.lighten(50%), thickness: .5pt),
  ),
)

// Scientific Style
#let default-style-scientific = (
  ..default-style,
  stroke: (cap: "square"),
  outset: 0,
)

#let _prepare-style(ctx, style) = {
  if type(style) != dictionary { return style }
  let n = util.resolve-number.with(ctx)

  style.label.offset = n(style.label.offset)
  style.tick.length = n(style.tick.length)
  style.tick.minor-length = n(style.tick.minor-length)
  if type(style.tick.minor-length) == ratio {
    style.tick.minor-length = style.tick.minor-length * style.tick.length / 100%
  }
  style.tick.label.offset = n(style.tick.label.offset)

  if "padding" in style {
    style.padding = n(style.padding)
  }

  if "origin" in style {
    style.origin.label.offset = n(style.origin.label.offset)
  }

  return style
}

#let _get-axis-style(ctx, style, name) = {
  if not name in style {
    return style
  }

  style = styles.resolve(style, merge: style.at(name))
  return _prepare-style(ctx, style)
}

#let _get-grid-type(axis) = {
  let grid = axis.ticks.at("grid", default: false)
  if grid == "major" or grid == true { return 1 }
  if grid == "minor" { return 2 }
  if grid == "both" { return 3 }
  return 0
}

#let default-style-schoolbook = util.merge-dictionary(default-style, (
  x: (stroke: auto, fill: none, mark: (end: "straight")),
  y: (stroke: auto, fill: none, mark: (end: "straight")),
  origin: (label: (offset: .05cm)),
  tick: (label: (offset: .1cm)),
  padding: .4cm))

// Construct Axis Object
//
// - min (number): Minimum value
// - max (number): Maximum value
// - ticks (dictionary): Tick settings:
//     - step (number): Major tic step
//     - minor-step (number): Minor tic step
//     - unit (content): Tick label suffix
//     - decimals (int): Tick float decimal length
// - label (content): Axis label
#let axis(min: -1, max: 1, label: none,
          ticks: (step: auto, minor-step: none,
                  unit: none, decimals: 2, grid: false,
                  format: "float")) = (
  min: min, max: max, ticks: ticks, label: label,
)

// Format a tick value
#let format-tick-value(value, tic-options) = {
  // Without it we get negative zero in conversion
  // to content! Typst has negative zero floats.
  if value == 0 { value = 0 }

  let round(value, digits) = {
    calc.round(value, digits: digits)
  }

  let format-float(value, digits) = {
    $#round(value, digits)$
  }

  let format-sci(value, digits) = {
    let exponent = if value != 0 {
      calc.floor(calc.log(calc.abs(value), base: 10))
    } else {
      0
    }

    let ee = calc.pow(10, calc.abs(exponent + 1))
    if exponent > 0 {
      value = value / ee * 10
    } else if exponent < 0 {
      value = value * ee * 10
    }

    value = round(value, digits)
    if exponent <= -1 or exponent >= 1 {
      return $#value times 10^#exponent$
    }
    return $#value$
  }

  if type(value) != typst-content {
    let format = tic-options.at("format", default: "float")
    if type(format) == function {
      value = (format)(value)
    } else if format == "sci" {
      value = format-sci(value, tic-options.at("decimals", default: 2))
    } else {
      value = format-float(value, tic-options.at("decimals", default: 2))
    }
  } else if type(value) != typst-content {
    value = str(value)
  }

  if tic-options.at("unit", default: none) != none {
    value += tic-options.unit
  }
  return value
}

// Get value on axis [0, 1]
//
// - axis (axis): Axis
// - v (number): Value
// -> float
#let value-on-axis(axis, v) = {
  if v == none { return }
  let (min, max) = (axis.min, axis.max)
  let dt = max - min; if dt == 0 { dt = 1 }

  return (v - min) / dt
}

/// Compute list of linear ticks for axis
///
/// - axis (axis): Axis
#let compute-linear-ticks(axis, style) = {
  let (min, max) = (axis.min, axis.max)
  let dt = max - min; if (dt == 0) { dt = 1 }
  let ticks = axis.ticks
  let ferr = util.float-epsilon
  let tick-limit = style.tick-limit
  let minor-tick-limit = style.minor-tick-limit

  let l = ()
  if ticks != none {
    let major-tick-values = ()
    if "step" in ticks and ticks.step != none {
      assert(ticks.step >= 0,
             message: "Axis tick step must be positive and non 0.")
      if axis.min > axis.max { ticks.step *= -1 }

      let s = 1 / ticks.step

      let num-ticks = int(max * s + 1.5)  - int(min * s)
      assert(num-ticks <= tick-limit,
             message: "Number of major ticks exceeds limit " + str(tick-limit))

      let n = range(int(min * s), int(max * s + 1.5))
      for t in n {
        let v = (t / s - min) / dt
        if v >= 0 - ferr and v <= 1 + ferr {
          l.push((v, format-tick-value(t / s, ticks), true))
          major-tick-values.push(v)
        }
      }
    }

    if "minor-step" in ticks and ticks.minor-step != none {
      assert(ticks.minor-step >= 0,
             message: "Axis minor tick step must be positive")

      let s = 1 / ticks.minor-step

      let num-ticks = int(max * s + 1.5) - int(min * s)
      assert(num-ticks <= minor-tick-limit,
             message: "Number of minor ticks exceeds limit " + str(minor-tick-limit))

      let n = range(int(min * s), int(max * s + 1.5))
      for t in n {
        let v = (t / s - min) / dt
        if v in major-tick-values {
          // Prefer major ticks over minor ticks
          continue
        }

        if v != none and v >= 0 and v <= 1 + ferr {
          l.push((v, none, false))
        }
      }
    }

  }

  return l
}

/// Get list of fixed axis ticks
///
/// - axis (axis): Axis object
#let fixed-ticks(axis) = {
  let l = ()
  if "list" in axis.ticks {
    for t in axis.ticks.list {
      let (v, label) = (none, none)
      if type(t) in (float, int) {
        v = t
        label = format-tick-value(t, axis.ticks)
      } else {
        (v, label) = t
      }

      v = value-on-axis(axis, v)
      if v != none and v >= 0 and v <= 1 {
        l.push((v, label, true))
      }
    }
  }
  return l
}

/// Compute list of axis ticks
///
/// A tick triple has the format:
///   (rel-value: float, label: content, major: bool)
///
/// - axis (axis): Axis object
#let compute-ticks(axis, style) = {
  let find-max-n-ticks(axis, n: 11) = {
    let dt = calc.abs(axis.max - axis.min)
    let scale = calc.pow(10, calc.floor(calc.log(dt, base: 10) - 1))
    if scale > 100000 or scale < .000001 {return none}

    let (step, best) = (none, 0)
    for s in style.auto-tick-factors {
      s = s * scale

      let divs = calc.abs(dt / s)
      if divs >= best and divs <= n {
        step = s
        best = divs
      }
    }
    return step
  }

  if axis == none or axis.ticks == none { return () }
  if axis.ticks.step == auto {
    axis.ticks.step = find-max-n-ticks(axis, n: style.auto-tick-count)
  }
  if axis.ticks.minor-step == auto {
    axis.ticks.minor-step = if axis.ticks.step != none {
      axis.ticks.step / 5
    } else {
      none
    }
  }

  let ticks = compute-linear-ticks(axis, style)
  ticks += fixed-ticks(axis)
  return ticks
}

/// Draw inside viewport coordinates of two axes
///
/// - size (vector): Axis canvas size (relative to origin)
/// - origin (coordinates): Axis Canvas origin
/// - x (axis): Horizontal axis
/// - y (axis): Vertical axis
/// - name (string,none): Group name
#let axis-viewport(size, x, y, origin: (0, 0), name: none, body) = {
  size = (rel: size, to: origin)

  draw.group(name: name, {
    draw.set-viewport(origin, size,
      bounds: (x.max - x.min,
               y.max - y.min,
               0))
    draw.translate((-x.min, -y.min))
    body
  })
}

// Draw grid lines for the ticks of an axis
//
// - axis (dictionary): The axis
// - ticks (array): The computed ticks
// - low (vector): Start position of a grid-line at tick 0
// - high (vector): End position of a grid-line at tick 0
// - dir (vector): Normalized grid direction vector along the grid axis
// - style (style): Axis style
#let draw-grid-lines(axis, ticks, low, high, dir, style) = {
  let kind = _get-grid-type(axis)
  if kind > 0 {
    for (distance, label, is-major) in ticks {
      let offset = vector.scale(dir, distance)
      let start = vector.add(low, offset)
      let end = vector.add(high, offset)
        
      // Draw a major line
      if is-major and (kind == 1 or kind == 3) {
        draw.line(start, end, stroke: style.grid.stroke)
      }
      // Draw a minor line
      if not is-major and kind >= 2 {
        draw.line(start, end, stroke: style.minor-grid.stroke)
      }
    }
  }
}

// Place a list of tick marks and labels along a path
#let place-ticks-on-path(ticks, path, style, flip: false, start: 0%, stop: 100%) = {
  return (ctx => {
    let (ctx, bounds, drawables) = process.many(ctx, path)
    let path = drawables.first().segments

    let len = path-util.length(path)
    let start = if type(start) == ratio {
      len * start / 100%
    } else { start }
    let stop = if type(stop) == ratio {
      len * (100% - stop) / 100%
    } else { stop }

    let drawables = ()

    let tick-range = len - start - stop
    for (distance, label, is-major) in ticks {
      let absolute-distance = start + distance * tick-range

      let (tick-pos, tick-dir) = path-util.direction(path, absolute-distance)
      let tick-dir = vector.scale((-tick-dir.at(1), tick-dir.at(0), tick-dir.at(2)), if flip { -1 } else { 1 })
      let (tick-pos, tick-dir) = util.apply-transform(ctx.transform, tick-pos, tick-dir)

      let length = if is-major {
        style.tick.length
      } else {
        style.tick.minor-length
      }

      let p0 = vector.add(tick-pos,
        vector.scale(tick-dir, if is-major {
          style.tick.offset
        } else {
          style.tick.minor-offset
        }))

      let p1 = vector.add(p0,
        vector.scale(tick-dir, length))

      drawables.push(
        drawable.path(path-util.line-segment((p0, p1)),
          stroke: if is-major { style.tick.stroke } else { style.tick.minor-stroke }))

      // Draw label
      if label != none {
        let label-pos = vector.add(if length >= 0 {
          p0
        } else {
          p1
        }, vector.scale(tick-dir, style.tick.label.offset))
        label-pos = util.revert-transform(ctx.transform, label-pos)

        let label-anchor = if style.tick.label.anchor in (none, auto) {
          let dir = tick-dir
          if dir == (0,+1,0) {
            "north"
          } else if dir == (0,-1,0) {
            "south"
          } else if dir == (+1,0,0) {
            "west"
          } else if dir == (-1,0,0) {
            "east"
          } else {
            "center"
          }
        } else {
          style.tick.label.anchor
        }

        let label-angle = if style.tick.label.angle in (none, auto) {
          0deg
        } else {
          style.tick.label.angle
        }

        let (drawables: label, ..) = process.many(ctx,
          draw.content(label-pos, label,
            anchor: label-anchor,
            angle: label-angle))

        drawables += label
      }
    }

    return (
      ctx: ctx,
      drawables: drawable.apply-transform(
        ctx.transform,
        drawables
      ),
    )
  },)
}

// Draw up to four axes in an "scientific" style at origin (0, 0)
//
// - size (array): Size (width, height)
// - left (axis): Left (y) axis
// - bottom (axis): Bottom (x) axis
// - right (axis): Right axis
// - top (axis): Top axis
// - name (string): Object name
// - draw-unset (bool): Draw unset axes
// - ..style (any): Style
#let scientific(size: (1, 1),
                left: none,
                right: auto,
                bottom: none,
                top: auto,
                draw-unset: true,
                name: none,
                ..style) = {
  import draw: *

  if right == auto {
    if left != none {
      right = left; right.is-mirror = true
    } else {
      right = none
    }
  }
  if top == auto {
    if bottom != none {
      top = bottom; top.is-mirror = true
    } else {
      top = none
    }
  }

  group(name: name, ctx => {
    let (w, h) = size
    anchor("origin", (0, 0))

    let style = style.named()
    style = styles.resolve(ctx.style, merge: style, root: "axes",
                           base: default-style-scientific)
    style = _prepare-style(ctx, style)

    // Compute ticks
    let x-ticks = compute-ticks(bottom, style)
    let y-ticks = compute-ticks(left, style)
    let x2-ticks = compute-ticks(top, style)
    let y2-ticks = compute-ticks(right, style)

    // Draw frame
    if style.fill != none {
      on-layer(style.background-layer, {
        rect((0,0), (w,h), fill: style.fill, stroke: none)
      })
    }

    // Draw grid
    group(name: "grid", ctx => {
      let axes = (
        ("bottom", (0,0), (0,h), (+w,0), x-ticks,  bottom),
        ("top",    (0,h), (0,0), (+w,0), x2-ticks, top),
        ("left",   (0,0), (w,0), (0,+h), y-ticks,  left),
        ("right",  (w,0), (0,0), (0,+h), y2-ticks, right),
      )

      for (name, start, end, direction, ticks, axis) in axes {
        if axis == none { continue }

        let style = _get-axis-style(ctx, style, name)
        let is-mirror = axis.at("is-mirror", default: false)

        if not is-mirror {
          on-layer(style.grid-layer, {
            draw-grid-lines(axis, ticks, start, end, direction, style)
          })
        }
      }
    })

    // Draw axes
    group(name: "axes", {
      let axes = (
        ("bottom", (0, 0), (w, 0), (0, -1), x-ticks,  false, bottom,),
        ("top",    (0, h), (w, h), (0, +1), x2-ticks, true,  top,),
        ("left",   (0, 0), (0, h), (-1, 0), y-ticks,  true,  left,),
        ("right",  (w, 0), (w, h), (+1, 0), y2-ticks, false, right,)
      )
      let label-placement = (
        bottom: ("south", "north", 0deg),
        top:    ("north", "south", 0deg),
        left:   ("west", "south", 90deg),
        right:  ("east", "north", 90deg),
      )

      for (name, start, end, outsides, ticks, flip, axis) in axes {
        let style = _get-axis-style(ctx, style, name)
        let is-mirror = axis == none or axis.at("is-mirror", default: false)

        if style.outset != 0 {
          let outset = vector.scale(outsides, style.outset)
          start = vector.add(start, outset)
          end = vector.add(end, outset)
        }

        let path = draw.line(start, end, ..style)
        on-layer(style.axis-layer, {
          group(name: "axis", {
            if draw-unset or axis != none {
              path;
              if not is-mirror {
                place-ticks-on-path(ticks, path, style, flip: flip)
              }
            }
          })

          if axis != none and axis.label != none {
            let offset = vector.scale(outsides, style.label.offset)
            let (group-anchor, content-anchor, angle) = label-placement.at(name)

            if style.label.anchor != auto {
              content-anchor = style.label.anchor
            }
            if style.label.angle != auto {
              angle = style.label.angle
            }

            content((rel: offset, to: "axis." + group-anchor),
              [#axis.label],
              angle: angle,
              anchor: content-anchor)
          }
        })
      }
    })
  })
}

// Draw two axes in a "school book" style
//
// - x-axis (axis): X axis
// - y-axis (axis): Y axis
// - size (array): Size (width, height)
// - x-position (number): X Axis position
// - y-position (number): Y Axis position
// - name (string): Object name
// - ..style (any): Style
#let school-book(x-axis, y-axis,
                 size: (1, 1),
                 x-position: 0,
                 y-position: 0,
                 name: none,
                 ..style) = {
  import draw: *

  group(name: name, ctx => {
    let style = style.named()
    style = styles.resolve(
      ctx.style,
      merge: style,
      root: "axes",
      base: default-style-schoolbook)
    style = _prepare-style(ctx, style)

    let x-position = calc.min(calc.max(y-axis.min, x-position), y-axis.max)
    let y-position = calc.min(calc.max(x-axis.min, y-position), x-axis.max)

    let padding = (
      left: if y-position > x-axis.min {style.padding} else {style.tick.length},
      right: style.padding,
      top: style.padding,
      bottom: if x-position > y-axis.min {style.padding} else {style.tick.length}
    ) 

    let (w, h) = size

    let x-y = value-on-axis(y-axis, x-position) * h
    let y-x = value-on-axis(x-axis, y-position) * w

    let axis-settings = (
      (x-axis, "north", (auto, x-y), (0, 1), "x"),
      (y-axis, "east",  (y-x, auto), (1, 0), "y"),
    )

    line((-padding.left, x-y), (w + padding.right, x-y), ..style.x, name: "x-axis")
    if "label" in x-axis and x-axis.label != none {
      let anchor = style.label.anchor
      if style.label.anchor == auto {
        anchor = "north-west"
      }
      content((rel: (0, -style.label.offset), to: "x-axis.end"),
        anchor: anchor, par(justify: false, x-axis.label))
    }

    line((y-x, -padding.bottom), (y-x, h + padding.top), ..style.y, name: "y-axis")
    if "label" in y-axis and y-axis.label != none {
      let anchor = style.label.anchor
      if style.label.anchor == auto {
        anchor = "south-east"
      }
      content((rel: (-style.label.offset, 0), to: "y-axis.end"),
        anchor: anchor, par(justify: false, y-axis.label))
    }

    // If both axes cross at the same value (mostly 0)
    // draw the tick label for both axes together.
    let origin-drawn = false
    let shared-origin = x-position == y-position

    for (axis, anchor, placement, tic-dir, name) in axis-settings {
      if axis != none {
        let style = style
        if name in style {
          style = styles.resolve(style, merge: style.at(name))
          style = _prepare-style(ctx, style)
        }

        let grid-mode = axis.ticks.at("grid", default: false)
        grid-mode = (
          major: grid-mode == true or grid-mode in ("major", "both"),
          minor: grid-mode in ("minor", "both")
        )

        for (pos, label, major) in compute-ticks(axis, style) {
          let (x, y) = placement
          if x == auto { x = pos * w }
          if y == auto { y = pos * h }

          let dir = vector.scale(tic-dir,
            if major {style.tick.length} else {style.tick.minor-length})
          let tick-begin = vector.sub((x, y), dir)
          let tick-end = vector.add((x, y), dir)

          let is-origin = x == y-x and y == x-y

          if not is-origin {
            if grid-mode.major and major or grid-mode.minor and not major {
              let (grid-begin, grid-end) = if name == "x" {
                ((x, 0), (x, h))
              } else {
                ((0, y), (w, y))
              }
              line(grid-begin, grid-end, ..style.grid)
            }

            line(tick-begin, tick-end, ..style.tick)
          }

          if label != none {
            if is-origin and shared-origin {
              if not origin-drawn {
                origin-drawn = true
                content(vector.add((x, y),
                  (-style.origin.label.offset, -style.origin.label.offset)),
                  par(justify: false, [#label]), anchor: "north-east")
              }
            } else {
              content(vector.add(tick-begin,
                vector.scale(tic-dir, -style.tick.label.offset)),
                par(justify: false, [#label]), anchor: anchor)
            }
          }
        }
      }
    }
  })
}
