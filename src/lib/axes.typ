// CeTZ Library for drawing graph axes
#import "../util.typ"
#import "../draw.typ"
#import "../vector.typ"
#import "../styles.typ"

#let typst-content = content

// Global defaults
#let default-style = (
  tick-limit: 100,
  minor-tick-limit: 1000,
  fill: none,
  stroke: black,
  label: (
    offset: .2,
    anchor: auto,
  ),
  tick: (
    fill: none,
    stroke: black,
    length: .1,
    minor-length: .08,
    label: (
      offset: .2,
      angle: 0deg,
      anchor: auto,
    )
  ),
  grid: (
    stroke: (paint: gray, dash: "dotted"),
    fill: none
  ),
  x: (
    fill: auto,
    stroke: auto,
    mark: auto,
    tick: auto
  ),
  y: (
    fill: auto,
    stroke: auto,
    mark: auto,
    tick: auto
  )
)

#let default-style-schoolbook = util.merge-dictionary(default-style, (
  tick: (label: (offset: .1)),
  mark: (end: ">"),
  padding: .4))

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
    for s in (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10) {
      s = s * scale

      let divs = calc.abs(dt / s)
      if divs >= best and divs <= n {
        step = s
        best = divs
      }
    }
    return step
  }

  if axis.ticks.step == auto {
    axis.ticks.step = find-max-n-ticks(axis, n: 11)
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

// Draw up to four axes in an "scientific" style at origin (0, 0)
//
// - left (axis): Left (y) axis
// - bottom (axis): Bottom (x) axis
// - right (axis): Right axis
// - top (axis): Top axis
// - size (array): Size (width, height)
// - name (string): Object name
// - padding (array): Padding (left, right, top, bottom)
// - frame (string): Frame mode:
//                   - true: Draw frame around all axes
//                   - auto: Draw line for set (!= none) axes
//                   - false: Draw no frame
// - ..style (any): Style
#let scientific(size: (1, 1),
                left: none,
                right: auto,
                bottom: none,
                top: auto,
                frame: true,
                padding: (left: 0, right: 0, top: 0, bottom: 0),
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

    anchor("origin",           (0, 0))
    anchor("data-bottom-left", (0, 0))
    anchor("data-top-right",   (w, h))

    let style = style.named()
    style = styles.resolve(ctx.style, merge: style, root: "axes",
                           base: default-style)

    let padding = (
      l: padding.at("west", default: 0),
      r: padding.at("east", default: 0),
      t: padding.at("north", default: 0),
      b: padding.at("south", default: 0),
    )

    let axis-settings = (
      // (axis, side, anchor, placement, tic-dir, name)
      (left,   "west",  "east",  (0, auto), ( 1, 0), "left"),
      (right,  "east",  "west",  (w, auto), (-1, 0), "right"),
      (bottom, "south", "north", (auto, 0), (0,  1), "bottom"),
      (top,    "north", "south", (auto, h), (0, -1), "top"),
    )

    group(name: "axes", {
      let (w, h) = (w - padding.l - padding.r,
                    h - padding.t - padding.b)
      anchor("origin", (0, 0))
      anchor("center", (w / 2, h / 2))

      for (axis, _, anchor, placement, tic-dir, name) in axis-settings {
        let style = style
        if name in style {
          style = styles.resolve(style, merge: style.at(name))
        }

        if axis != none {
          let grid-mode = axis.ticks.at("grid", default: false)
          grid-mode = (
            major: grid-mode == true or grid-mode in ("major", "both"),
            minor: grid-mode in ("minor", "both")
          )

          let is-mirror = axis.at("is-mirror", default: false)

          for (pos, label, major) in compute-ticks(axis, style) {
            let (x, y) = placement
            if x == auto { x = pos * w + padding.l }
            if y == auto { y = pos * h + padding.b }

            let length = if major {
              style.tick.length} else {
              style.tick.minor-length}
            let tick-start = (x, y)
            let tick-end = vector.add(tick-start,
              vector.scale(tic-dir, length))
            if (length < 0) {
              (tick-start, tick-end) = (tick-end, tick-start)
            }

            if not is-mirror {
              if label != none {
                let label-pos = vector.add(tick-start,
                  vector.scale(tic-dir, -style.tick.label.offset))
                content(label-pos, par(justify: false, [#label]),
                        anchor: if style.tick.label.anchor == auto {anchor}
                                else {style.tick.label.anchor},
                        angle: style.tick.label.angle)
              }

              if grid-mode.major and major or grid-mode.minor and not major {
                let (grid-begin, grid-end) = if name in ("top", "bottom") {
                  ((x, 0), (x, h))
                } else {
                  ((0, y), (w, y))
                }

                line(grid-begin, grid-end, ..style.grid)
              }
            }

            if length != none and length != 0 {
              line(tick-start, tick-end, ..style.tick)
            }
          }
        }
      }

      assert(frame in (true, false, auto),
        message: "Invalid frame mode")
      if frame == true {
        rect((0, 0), size, ..style, radius: 0)
      } else if frame == auto {
        let segments = ((),)

        if left != none {segments.last() += ((0,h), (0,0))}
        if bottom != none {segments.last() += ((0,0), (w,0))}
        else {segments.push(())}
        if right != none {segments.last() += ((w,0), (w,h))}
        else {segments.push(())}
        if top != none {segments.last() += ((w,h), (0,h))}
        else {segments.push(())}

        for s in segments {
          if s.len() > 1 {
            line(..s, ..style)
          }
        }
      }
    })

    for (axis, side, anchor, ..) in axis-settings {
      if axis == none or not "label" in axis or axis.label == none {continue}
      if not axis.at("is-mirror", default: false) {
        let is-left-right = side in ("west", "east")
        let angle = if is-left-right {
          90deg
        } else {
          0deg
        }
        let position = if is-left-right {
          ("axes." + side, "|-", "axes.center")
        } else {
          ("axes." + side, "-|", "axes.center")
        }
        // Use a group to get non-rotated anchors
        group(
          content(
            position,
            par(justify: false, axis.label),
            angle: angle,
            padding: style.label.offset
          ),
          anchor: anchor,
        )
      }
    }
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
      base: default-style-schoolbook
    )

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
                  vector.scale((1, 1), -style.tick.label.offset / 2)),
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
