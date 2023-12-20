#let typst-angle = angle
#let typst-rotate = rotate

#import "/src/coordinate.typ"
#import "/src/drawable.typ"
#import "/src/styles.typ"
#import "/src/path-util.typ"
#import "/src/util.typ"
#import "/src/vector.typ"
#import "/src/matrix.typ"
#import "/src/process.typ"
#import "/src/bezier.typ" as bezier_
#import "/src/hobby.typ" as hobby_
#import "/src/anchor.typ" as anchor_
#import "/src/mark.typ" as mark_
#import "/src/aabb.typ"

#import "transformations.typ": *
#import "styling.typ": *
#import "grouping.typ": *

/// Draws a circle or ellipse.
///
/// #example(```
/// circle((0,0))
/// // Draws an ellipse
/// circle((0,-2), radius: (0.75, 0.5))
/// ```)
/// = parameters
///
/// = Styling
/// *Root:* `circle`
/// == Keys
///   #show-parameter-block("radius", ("number", "array"), [A number that defines the size of the circle's radius. Can also be set to a tuple of two numbers to define the radii of an ellipse, the first number is the `x` radius and the second is the `y` radius.], default: 1)
///
/// = Anchors
///   Supports compass anchors. The "center" anchor is the default.
///
/// - position (coordinate): The position to place the circle on.
/// - name (none,string):
/// - anchor (none,string):
/// - ..style (style):
#let circle(position, name: none, anchor: none, ..style) = {
  // No extra positional arguments from the style sink
  assert.eq(
    style.pos(),
    (),
    message: "Unexpected positional arguments: " + repr(style.pos()),
  )
  let style = style.named()

  (ctx => {
    let (ctx, pos) = coordinate.resolve(ctx, position)
    let style = styles.resolve(ctx.style, merge: style, root: "circle")
    let (rx, ry) = util.resolve-radius(style.radius).map(util.resolve-number.with(ctx))
    let (cx, cy, cz) = pos
    let (ox, oy) = (calc.cos(45deg) * rx, calc.sin(45deg) * ry)

    let (transform, anchors) = anchor_.setup(
      (anchor) => {
        (
          north: (cx, cy + ry),
          north-east: (cx + ox, cy + oy),
          east: (cx + rx, cy),
          south-east: (cx + ox, cy - oy),
          south: (cx, cy - ry),
          south-west: (cx - ox, cy - oy),
          west: (cx - rx, cy),
          north-west: (cx - ox, cy + oy),
          center: (cx, cy)
        ).at(anchor)
        (cz,)
      },
      (
        "north",
        "north-east",
        "east",
        "south-east",
        "south",
        "south-west",
        "west",
        "north-west",
        "center",
      ),
      default: "center",
      name: name,
      offset-anchor: anchor,
      transform: ctx.transform
    )

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      // anchors: calculate-anchor.with(transform: transform),
      drawables: drawable.apply-transform(transform, drawable.ellipse(
        cx, cy, cz,
        rx, ry,
        fill: style.fill,
        stroke: style.stroke,
      )),
    )
  },)
}

/// Draws a circle through three coordinates
///
/// #example(
/// ```
/// let (a, b, c) = ((0,0), (2,-.5), (1,1))
/// line(a, b, c, close: true, stroke: gray)
/// circle-through(a, b, c, name: "c")
/// circle("c.center", radius: .05, fill: red)
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root:* `circle`
/// == Keys
///   `circle-through` has the same styling keys as @@circle() except for `radius` as the circle's radius is calculated by the given coordinates.
///
/// = Anchors
///   Supports the same anchors as `circle` as well as:
///   / a: Coordinate a
///   / b: Coordinate b
///   / c: Coordinate c
///
/// - a (coordinate): Coordinate a
/// - b (coordinate): Coordinate b
/// - c (coordinate): Coordinate c
/// - name (none,string):
/// - anchor (none,string):
/// - ..style (style):
#let circle-through(a, b, c, name: none, anchor: none, ..style) = {
  assert.eq(style.pos(), (), message: "Unexpected positional arguments: " + repr(style.pos()))
  style = style.named()

  (a, b, c).map(coordinate.resolve-system)

  return (ctx => {
    let (ctx, a, b, c) = coordinate.resolve(ctx, a, b, c)

    let center = util.calculate-circle-center-3pt(a, b, c)

    let style = styles.resolve(ctx.style, merge: style, root: "circle")
    let (cx, cy, cz) = center
    let r = vector.dist(a, (cx, cy))
    let (ox, oy) = (calc.cos(45deg) * r, calc.sin(45deg) * r)

    let (transform, anchors) = anchor_.setup(
      anchor => {
        (
          north: (cx, cy + r),
          north-east: (cx + ox, cy + oy),
          east: (cx + r, cy),
          south-east: (cx + ox, cy - oy),
          south: (cx, cy - r),
          south-west: (cx - ox, cy - oy),
          west: (cx - r, cy),
          north-west: (cx - ox, cy + oy),
          center: (cx, cy)
        ).at(anchor)
        (cz,)
      },
      (
        "north",
        "north-east",
        "east",
        "south-east",
        "south",
        "south-west",
        "west",
        "north-west",
        "center",
      ),
      default: "center",
      name: name,
      offset-anchor: anchor,
      transform: ctx.transform
    )

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(
        transform,
        drawable.ellipse(
          cx, cy, 0,
          r, r,
          fill: style.fill,
          stroke: style.stroke
        )
      )
    )
  },)
}

/// Draws a circular segment.
///
/// #example(```
/// arc((0,0), start: 45deg, stop: 135deg)
/// arc((0,-0.5), start: 45deg, delta: 90deg, mode: "CLOSE")
/// arc((0,-1), stop: 135deg, delta: 90deg, mode: "PIE")
/// ```)
///
/// Note that two of the three angle arguments (`start`, `stop` and `delta`) must be set.
/// The current position `()` gets updated to the arc's end coordinate (anchor `arc-end`).
///
/// == parameters
///
/// = Styling
/// *Root:* `arc`\
/// == Keys
///   #show-parameter-block("radius", ("number", "array"), [The radius of the arc. An elliptical arc can be created by passing a tuple of numbers where the first element is the x radius and the second element is the y radius.], default: 1)
///   #show-parameter-block("mode", ("string",), [The options are: "OPEN" no additional lines are drawn so just the arc is shown; "CLOSE" a line is drawn from the start to the end of the arc creating a circular segment; "PIE" lines are drawn from the start and end of the arc to the origin creating a circular sector.], default: "OPEN")
///   #show-parameter-block("update-position", ("bool",), [Update the current canvas position to the arc's end point (anchor `"arc-end"`).
///     This overrides the default of `true`, that allows chaining of (arc) elements.], default: true)
///
/// = Anchors
///   Supports compass anchors when `mode` is "PIE"
///   / center: The center of the arc, this is the default anchor.
///   / arc-center: The midpoint of the arc's curve.
///   / chord-center: Center of chord of the arc drawn between the start and end point.
///   / origin: The origin of the arc's circle.
///   / arc-start: The position at which the arc's curve starts.
///   / arc-end: The position of the arc's curve end.
///
/// - position (coordinate): Position to place the arc at.
/// - start (auto,angle): The angle at which the arc should start. Remember that `0deg` points directly towards the right and `90deg` points up.
/// - stop (auto,angle): The angle at which the arc should stop.
/// - delta (auto,angle): The change in angle away start or stop.
/// - name (none,string):
/// - anchor (none, string):
/// - ..style (style):
#let arc(
  position,
  start: auto,
  stop: auto,
  delta: auto,
  name: none,
  anchor: none,
  ..style,
) = {
  // Start, stop, delta check
  assert(
    (start, stop, delta).filter(it => { it == auto }).len() == 1,
    message: "Exactly two of three options start, stop and delta should be defined.",
  )

  // No extra positional arguments from the style sink
  assert.eq(
    style.pos(),
    (),
    message: "Unexpected positional arguments: " + repr(style.pos()),
  )
  let style = style.named()

  // Coordinate check
  let t = coordinate.resolve-system(position)

  let start-angle = if start == auto { stop - delta } else { start }
  let stop-angle = if stop == auto { start + delta } else { stop }
  // Border angles can break if the angle is 0.
  assert.ne(start-angle, stop-angle, message: "Angle must be greater than 0deg")

  return (ctx => {
    let style = styles.resolve(ctx.style, merge: style, root: "arc")
    assert(style.mode in ("OPEN", "PIE", "CLOSE"))

    let (ctx, arc-start) = coordinate.resolve(ctx, position)
    let (rx, ry) = util.resolve-radius(style.radius).map(util.resolve-number.with(ctx))

    // Calculate marks and optimized angles
    let (marks, draw-arc-start, draw-start-angle, draw-stop-angle) = if style.mark != none {
      mark_.place-marks-along-arc(ctx, start-angle, stop-angle,
        arc-start, rx, ry, style, style.mark)
    } else {
      (none, arc-start, start-angle, stop-angle)
    }

    let (x, y, z) = arc-start
    let path = (drawable.arc(
      ..draw-arc-start,
      draw-start-angle,
      draw-stop-angle,
      rx,
      ry,
      stroke: style.stroke,
      fill: style.fill,
      mode: style.mode,
    ),)

    if marks != none {
      path += marks
    }

    let sector-center = (
      x - rx * calc.cos(start-angle),
      y - ry * calc.sin(start-angle),
      z
    )
    let arc-end = (
      sector-center.first() + rx * calc.cos(stop-angle),
      sector-center.at(1) + ry * calc.sin(stop-angle),
      z
    )
    let chord-center = vector.lerp(arc-start, arc-end, 0.5)
    let arc-center = (
      sector-center.first() + rx * calc.cos((stop-angle + start-angle)/2),
      sector-center.at(1) + ry * calc.sin((stop-angle + start-angle)/2),
      z
    )

    // Set the last position to arc-end
    if style.update-position {
      ctx.prev.pt = arc-end
    }

    // Center is calculated based on observations of tikz's circular sector and semi circle shapes.
    let center = if style.mode != "CLOSE" {
      // A circular sector's center anchor is placed half way between the sector-center and arc-center when the angle is 180deg. At 60deg it is placed 1/3 of the way between, this is mirrored at 300deg.
      vector.lerp(
        arc-center,
        sector-center,
        if (stop-angle + start-angle) > 180deg { (stop-angle + start-angle) } else { (stop-angle + start-angle) + 180deg } / 720deg
      )
    } else {
      // A semi circle's center anchor is placed half way between the sector-center and arc-center, so that is always `center` when the arc is closed. Otherwise the point at which compass anchors are calculated from will be outside the lines.
      vector.lerp(
        arc-center,
        chord-center,
        0.5
      )
    }

    // compass anchors are placed on the shapes border in tikz so prototype version is setup for use here
    let border = anchor_.border.with(
      center,
      2*rx, 2*ry,
      path + if style.mode == "OPEN" {
        (
          drawable.path((
            path-util.line-segment((arc-start, sector-center, arc-end)),
          ))
        ,)
      }
    )

    let (transform, anchors) = anchor_.setup(
      anchor => {
        if anchor in anchor_.compass-angle {
          return border(anchor_.compass-angle.at(anchor))
        }
        (
          arc-start: arc-start,
          origin: sector-center,
          arc-end: arc-end,
          arc-center: arc-center,
          chord-center: chord-center,
          center: center,
        ).at(anchor)
      },
      (
        "north",
        "north-east",
        "east",
        "south-east",
        "south",
        "south-west",
        "west",
        "north-west",
        "center",
        "arc-center",
        "chord-center",
        "origin",
        "arc-start",
        "arc-end"
      ),
      default: "arc-start",
      name: name,
      offset-anchor: anchor,
      transform: ctx.transform,
    )

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(
        transform,
        path,
      )
    )
  },)
}

/// Draw an arc that passes through three points a, b and c.
///
/// Note that all three points must not lay on a straight line, otherwise
/// the function fails.
///
/// #example(```
/// arc-through((0,1), (1,1), (1,0))
/// ```)
///
/// *Style Root* `arc` \
/// *Style Keys* \
///   Uses the same style keys as @@arc()
///
/// *Anchors* \
///   For anchors see `arc`.
///
/// - a (coordinate): Start position of the arc
/// - b (coordinate): Position the arc passes through
/// - c (coordinate): End position of the arc
/// - name (none,string): The arc elements node name that, if set can be used to query anchors
/// - ..style (style): Style key value pairs. The function `arc-through` uses
///   all keys that `arc` uses, but `radius`, as this is determined by the
///   three input points.
#let arc-through(
  a,
  b,
  c,
  name: none,
  ..style,
) = get-ctx(ctx => {
  let (ctx, a, b, c) = coordinate.resolve(ctx, a, b, c)
  assert(a.at(2) == b.at(2) and b.at(2) == c.at(2),
    message: "The z coordinate of all points must be equal, but is: " + repr((a, b, c).map(v => v.at(2))))

  // Calculate the circle center from three points or fails if all
  // three points are on one straight line.
  let center = util.calculate-circle-center-3pt(a, b, c)
  let radius = vector.dist(center, a)

  // Find the start and inner angle between a-center-c
  let start = vector.angle2(center, a)
  let delta = vector.angle(a, center, c)

  // Returns a negative number if pt is left of the line a-b,
  // if pt is right to a-b, a positive number is returned,
  // otherwise zero.
  let side-on-line(a, b, pt) = {
    let (x1, y1, ..) = a
    let (x2, y2, ..) = b
    let (x,  y, ..)  = pt
    return (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1)
  }

  // Center & b     b is left,
  //  are left      center not
  //
  //    +-b-+          +-b-+
  //   /     \        /     \
  //  |   C   |    --a-------c--
  //   \     /        \  C  /
  // ---a---c---       +---+
  //
  // If b and C are on the same side of a-c, the arcs radius is >= 180deg,
  // otherwise the radius is < 180deg.
  let center-is-left = side-on-line(a, c, center) < 0
  let b-is-left = side-on-line(a, c, b) < 0

  // If the center and point b are on the same side of a-c,
  // the arcs delta must be > 180deg. Note, that delta is
  // the inner angle between a-center-c, so we need to calculate
  // the outer angle by subtracting from 360deg.
  if center-is-left == b-is-left {
    delta = 360deg - delta
  }

  // If b is left of a-c, swap a-c to c-a by using a negative delta
  if b-is-left {
    delta *= -1
  }

  return arc(a, start: start, delta: delta, radius: radius,
    anchor: "arc-start", name: name, ..style)
})

/// Draws a single mark pointing at a target coordinate
///
/// #example(```
/// mark((0,0), (1,0), symbol: ">", fill: black)
/// mark((0,0), (1,1), symbol: ">", scale: 3, fill: black)
/// ```)
///
/// Or as part of a path based element that supports the `mark` style key:
///
/// #example(vertical: true, ```
/// rotate(-90deg)
/// set-style(mark: (fill: black))
/// line((1, -1), (1, 9), stroke: (paint: gray, dash: "dotted"))
/// line((0, 8), (rel: (1, 0)), mark: (end: "left-harpoon"))
/// line((0, 7), (rel: (1, 0)), mark: (end: "right-harpoon"))
/// line((0, 6), (rel: (1, 0)), mark: (end: "<>"))
/// line((0, 5), (rel: (1, 0)), mark: (end: "o"))
/// line((0, 4), (rel: (1, 0)), mark: (end: "|"))
/// line((0, 3), (rel: (1, 0)), mark: (end: "<"))
/// line((0, 2), (rel: (1, 0)), mark: (end: ">"))
/// set-style(mark: (fill: none))
/// line((0, 1), (rel: (1, 0)), mark: (end: "<"))
/// line((0, 0), (rel: (1, 0)), mark: (end: ">"))
/// ```)
///
/// = parameters
///
/// = Styling <mark-styling>
/// *Root:* `mark`
/// == Keys
///   #show-parameter-block("symbol", "string", [The type of mark to draw when using the `mark` function.], default: ">")
///   #show-parameter-block("start", ("string", "none", "array"), [The type of mark to draw at the start of a path.])
///   #show-parameter-block("end", ("string", "none", "array"), [The type of mark to draw at the end of a path.])
///   #show-parameter-block("length", "number", [The length of the mark along its direction it is pointing.], default: 0.2)
///   #show-parameter-block("width", "number", [The width of the mark along the normal of its direction.], default: 0.15)
///   #show-parameter-block("inset", "number", [The distance by which something inside the arrow tip is set inwards.], default: 0.05)
///   #show-parameter-block("scale", "float", [A factor that is applied to the mark's length, width and inset.], default: 1)
///   #show-parameter-block("sep", "number", [The distance between multiple marks along their path.], default: 1)
///   #show-parameter-block("flex", "boolean", [Only applicable when marks are used on curves such as bezier and hobby. If true, the mark will point along the secant of the curve. If false, the tangent at the marks tip is used.], default: true)
///   #show-parameter-block("position-samples", "integer", [Only applicable when marks are used on curves such as bezier and hobby. The maximum number of samples to use for calculating curve positions. A higher number gives better results but may slow down compilation.], default: 30)
///
/// *Note*: The size of the mark depends on its style values, not
/// the distance between `from` and `to`, which only determine its
/// orientation.
///
/// - from (coordinate): The position to place the mark.
/// - to (coordinate): The position the mark should point towards.
/// - ..style (style):
#let mark(from, to, ..style) = {
  assert.eq(
    style.pos(),
    (),
    message: "Unexpected positional arguments: " + repr(style.pos()),
  )

  let style = style.named()
  (from, to).map(coordinate.resolve-system)

  return (ctx => {
    let (ctx, ..pts) = coordinate.resolve(ctx, from, to)
    let style = styles.resolve(ctx.style, merge: style, root: "mark")

    return (ctx: ctx, drawables: drawable.mark(
      ..pts,
      style.symbol,
      style
    ))
  },)
}

/// Draws a line, more than two points can be given to create a line-strip.
///
/// #example(```
/// line((-1.5, 0), (1.5, 0))
/// line((0, -1.5), (0, 1.5))
/// line((-1, -1), (-0.5, 0.5), (0.5, 0.5), (1, -1), close: true)
/// ```)
///
/// If the first or last coordinates are given as the name of an element,
/// that has a `"default"` anchor, the intersection of that element's border
/// and a line from the first or last two coordinates given is used as coordinate.
/// This is useful to span a line between the borders of two elements.
///
/// #example(```
/// circle((1,2), radius: .5, name: "a")
/// rect((2,1), (rel: (1,1)), name: "b")
/// line("a", "b")
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root:* `line`
///
/// == Keys
///   Supports mark styling.
///
/// = Anchors
///   / start: The line's start position
///   / end: The line's end position
///
/// - ..pts-style (coordinates, style): Positional two or more coordinates to draw lines between. Accepts style key-value pairs.
/// - close (bool): If true, the line-strip gets closed to form a polygon
/// - name (none,string):
#let line(..pts-style, close: false, name: none) = {
  // Extra positional arguments from the pts-style sink are interpreted as coordinates.
  let pts = pts-style.pos()
  let style = pts-style.named()

  assert(pts.len() >= 2, message: "Line must have a minimum of two points")

  // Coordinate check
  let pts-system = pts.map(coordinate.resolve-system)

  // Find the intersection between line a-b next to b
  // if no intersection could be found, return a.
  let element-line-intersection(ctx, elem, a, b) = {
    // Vectors a and b are not transformed yet, but the vectors of the
    // drawable are.
    let (ta, tb) = util.apply-transform(ctx.transform, a, b)

    let pts = ()
    for drawable in elem.at("drawables", default: ()) {
      pts += intersection.line-path(ta, tb, drawable)
    }
    return if pts == () {
      a
    } else {
      // Find the nearest point
      let pt = util.sort-points-by-distance(b, pts).first()

      // Reverse the transformation
      return util.revert-transform(ctx.transform, pt)
    }
  }

  return (ctx => {
    let first-elem = pts.first()
    let last-elem = pts.last()
    let (ctx, ..pts) = coordinate.resolve(ctx, ..pts)

    // If the first/last element, test for intersection
    // of that element and a line from the two first/last coordinates of this
    // line strip.
    if pts-system.first() == "element" {
      let elem = ctx.nodes.at(first-elem)
      pts.first() = element-line-intersection(ctx, elem, ..pts.slice(0, 2))
    }
    if pts-system.last() == "element" {
      let elem = ctx.nodes.at(last-elem)
      pts.last() = element-line-intersection(ctx, elem, ..pts.slice(-2))
    }

    let style = styles.resolve(ctx.style, merge: style, root: "line")
    let (transform, anchors) = anchor_.setup(
      (anchor) => {
        (
          start: pts.first(),
          end: pts.last()
        ).at(anchor)
      },
      (
        "start",
        "end"
      ),
      name: name,
      transform: ctx.transform,
    )

    // Place marks and adjust points
    let (marks, pts) = if style.mark != none {
      mark_.place-marks-along-line(ctx, pts, style.mark)
    } else {
      (none, pts)
    }

    let drawables = (drawable.path(
      (path-util.line-segment(pts),),
      fill: style.fill,
      stroke: style.stroke,
      close: close,
    ),)

    if marks != none {
      drawables += marks
    }

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(transform, drawables)
    )
  },)
}

/// Draws a grid between two coordinates
///
/// #example(```
/// // Draw a grid
/// grid((0,0), (2,2))
///
/// // Draw a smaller blue grid
/// grid((1,1), (2,2), stroke: blue, step: .25)
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root:* `grid`
///   / step: TODO
///   / help-lines: TODO
///
/// = Anchors
///   Supports compass anchors.
///
/// - from (coordinate): The top left of the grid
/// - to (coordinate): The bottom right of the grid
/// - name (none,string):
/// - ..style (style):
#let grid(from, to, name: none, ..style) = {
  (from, to).map(coordinate.resolve-system)

  assert.eq(style.pos(), (), message: "Unexpected positional arguments: " + repr(style.pos()))
  style = style.named()

  return (ctx => {
    let (ctx, from, to) = coordinate.resolve(ctx, from, to)

    (from, to) = (
      (calc.min(from.at(0), to.at(0)), calc.min(from.at(1), to.at(1))),
      (calc.max(from.at(0), to.at(0)), calc.max(from.at(1), to.at(1)))
    )

    let style = styles.resolve(ctx.style, merge: style, root: "grid", base: (
      step: 1,
      stroke: auto,
      help-lines: false,
    ))
    if style.help-lines {
      style.stroke = 0.2pt + gray
    }

    let (x-step, y-step) = if type(style.step) == dictionary {
      (style.step.at("x", default: 1), style.step.at("y", default: 1))
    } else if type(style.step) == array {
      style.step
    } else {
      (style.step, style.step)
    }.map(util.resolve-number.with(ctx))

    let drawables = {
      if x-step != 0 {
        range(int((to.at(0) - from.at(0)) / x-step)+1).map(x => {
          x *= x-step
          x += from.at(0)
          drawable.path(
            path-util.line-segment(((x, from.at(1)), (x, to.at(1)))),
            stroke: style.stroke
          )
        })
      } else {
        ()
      }
      if y-step != 0 {
        range(int((to.at(1) - from.at(1)) / y-step)+1).map(y => {
          y *= y-step
          y += from.at(1)
          drawable.path(
            path-util.line-segment(((from.at(0), y), (to.at(1), y))),
            stroke: style.stroke
          )
        })
      } else {
        ()
      }
    }

    let center = ((from.first() + to.first()) / 2, (from.last() + to.last()) / 2)
    let (transform, anchors) = anchor_.setup(
      anchor => {
        (
          north: (center.first(), to.last()),
          north-east: to,
          east: (to.first(), center.last()),
          south-east: (to.first(), from.last()),
          south: (center.first(), from.last()),
          south-west: from,
          west: (from.first(), center.last()),
          north-west: (from.first(), to.last()),
          center: center,
        ).at(anchor)
        (0,)
      },
      (
        "north",
        "north-east",
        "east",
        "south-east",
        "south",
        "south-west",
        "west",
        "north-west",
        "center"
      ),
      name: name,
      transform: ctx.transform
    )

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(
        transform,
        drawables
      )
    )
  },)
}

/// Positions Typst content in the canvas. Note that the content itself is not transformed only its position is.
///
/// #example(```
/// content((0,0), [Hello World!])
/// ```)
/// To put text on a line you can let the function calculate the angle between its position and a second coordinate by passing it to `angle`:
///
/// #example(```
/// line((0, 0), (3, 1), name: "line")
/// content(
///   ("line.start", 0.5, "line.end"),
///   angle: "line.end",
///   padding: .1,
///   anchor: "south",
///   [Text on a line]
/// )
/// ```)
///
/// #example(```
/// // Place content in a rect between two coordinates
/// content((0, 0), (2, 2), box(par(justify: false)[This is a long text.], stroke: 1pt, width: 100%, height: 100%, inset: 1em))
/// ```)
///
///
/// = parameters
/// = Styling
/// *Root:* `content`
/// == Keys
///   #show-parameter-block("padding", ("number", "dictionary"), default: 0, [Sets the spacing around content. Can be a single number to set padding on all sides or a dictionary to specify each side specifically. The dictionary follows Typst's `pad` function: https://typst.app/docs/reference/layout/pad/])
///   #show-parameter-block("frame", ("string", "none"), default: none, [Sets the frame style. Can be `none`, "rect" or "circle" and inherits the `stroke` and `fill` style.])
///
/// = Anchors
///   Supports compass anchors.
///
/// - ..args-style (coordinate, content, style): When one coordinate is given as a positional argument, the content will be placed at that position. When two coordinates are given as positional arguments, the content will be placed inside a rectangle between the two positions. All named arguments are styling and any additional positional arguments will panic.
/// - angle (angle,coordinate): Rotates the content by the given angle. A coordinate can be given to rotate the content by the angle between it and the first coordinate given in `args`. This effectively points the right hand side of the content towards the coordinate. This currently exists because Typst's rotate function does not change the width and height of content.
/// - anchor (none, string):
/// - name (none, string):
#let content(
    ..args-style,
    angle: 0deg,
    anchor: none,
    name: none,
  ) = {
  let (args, style) = (args-style.pos(), args-style.named())

  let (a, b, body) = if args.len() == 2 {
    args.insert(1, auto)
    args
  } else if args.len() == 3 {
    args
  } else {
    panic("Expected 2 or 3 positional arguments, got " + str(args.len()))
  }

  coordinate.resolve-system(a)

  if b != auto {
    coordinate.resolve-system(b)
  }

  if type(angle) != typst-angle {
    coordinate.resolve-system(angle)
  }

  return (ctx => {
    let style = styles.resolve(ctx.style, merge: style, root: "content")
    let padding = util.as-padding-dict(style.padding)
    for (k, v) in padding {
      padding.insert(k, util.resolve-number(ctx, v))
    }

    let (ctx, a) = coordinate.resolve(ctx, a)
    let b = b
    let auto-size = b == auto
    if not auto-size {
      (ctx, b) = coordinate.resolve(ctx, b)
    }

    let angle = if type(angle) != typst-angle {
      let c
      (ctx, c) = coordinate.resolve(ctx, angle)
      vector.angle2(a, c)
    } else {
      angle
    }

    // Typst's `rotate` function is clockwise relative to x-axis, which is backwards from us
    angle = angle * -1

    let (width, height, ..) = if auto-size {
      util.measure(ctx, body)
    } else {
      vector.sub(b, a)
    }

    width = (calc.abs(width)
      + padding.at("left", default: 0)
      + padding.at("right", default: 0))
    height = (calc.abs(height)
      + padding.at("top", default: 0)
      + padding.at("bottom", default: 0))

    let anchors = {
      let w = width/2
      let h = height/2
      let center = if auto-size {
        a
      } else {
        vector.add(a, (w, -h))
      }

      // Only the center anchor gets transformed. All other anchors
      // must be calculated relative to the transformed center!
      center = matrix.mul-vec(ctx.transform,
        vector.as-vec(center, init: (0,0,0,1)))

      let north = (calc.sin(angle)*h, -calc.cos(angle)*h,0)
      let east = (calc.cos(-angle)*w, -calc.sin(-angle)*w,0)
      let south = vector.scale(north, -1)
      let west = vector.scale(east, -1)
      (
        center: center,
        north: vector.add(center, north),
        north-east: vector.add(center, vector.add(north, east)),
        east: vector.add(center, east),
        south-east: vector.add(center, vector.add(south, east)),
        south: vector.add(center, south),
        south-west: vector.add(center, vector.add(south, west)),
        west: vector.add(center, west),
        north-west: vector.add(center, vector.add(north, west)),
      )
    }

    let drawables = ()
    if style.frame in ("rect", "circle") {
      drawables.push(
        if style.frame == "rect" {
          drawable.path(
            path-util.line-segment((
              anchors.north-west,
              anchors.north-east,
              anchors.south-east,
              anchors.south-west
            )),
            close: true,
            stroke: style.stroke,
            fill: style.fill
          )
        } else if style.frame == "circle" {
          let (x, y, z) = util.calculate-circle-center-3pt(anchors.north-west, anchors.south-west, anchors.south-east)
          let r = vector.dist((x, y, z), anchors.north-west)
          drawable.ellipse(
            x, y, z,
            r, r,
            stroke: style.stroke,
            fill: style.fill
          )
        }
      )
    }

    let (aabb-width, aabb-height, ..) = aabb.size(aabb.aabb(
      (anchors.north-west, anchors.north-east,
       anchors.south-west, anchors.south-east)))

    drawables.push(
      drawable.content(
        anchors.center,
        aabb-width,
        aabb-height,
        typst-rotate(angle,
          block(
            width: width * ctx.length,
            height: height * ctx.length,
            inset: (
              top: padding.at("top", default: 0) * ctx.length,
              left: padding.at("left", default: 0) * ctx.length,
              bottom: padding.at("bottom", default: 0) * ctx.length,
              right: padding.at("right", default: 0) * ctx.length,
            ),
            body
          )
        )
      )
    )

    let (transform, anchors) = anchor_.setup(
      anchor => {
        anchors.at(anchor)
      },
      anchors.keys(),
      default: if auto-size { "center" } else { "north-west" },
      offset-anchor: anchor,
      transform: none, // Content does not get transformed, see the calculation
                       // of anchors.
      name: name,
    )

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(
        transform,
        drawables
      )
    )
  },)
}

/// Draws a rectangle between two coordinates.
/// #example(```
/// rect((0,0), (1,1))
/// rect((-.5, -.5), (rel: (2, 2)),
///   radius: (north-east: (100%, .5),
///            south-west: (100%, .5), rest: .2),
///   stroke: red)
/// rect((-1, -1), (rel: (3, 3)), radius: .5, stroke: blue)
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root* `rect`
/// == Keys
///   #show-parameter-block("radius", ("number", "ratio", "dictionary"), default: 0, [
///     The rectangles corner radius. If set to a single number, that radius is applied
///     to all four corners of the rectangle. If passed a dictionary you can set the
///     radii per corner. The following keys support either a `<number, ratio>` or an array of `<number, ratio>`
///     for specifying a different x- and y-radius:
///     `north`, `east`, `south`, `west`, `north-west`, `north-east`, `south-west` and `south-east`. To set a default value for
///     remaining corners, the `rest` key can be used.
///
///     Ratio values are relative to the rects width/height.
///
///     #example(```
///     rect((0,0), (rel: (1,1)), radius: 0)
///     rect((2,0), (rel: (1,1)), radius: 25%)
///     rect((4,0), (rel: (1,1)), radius: (north: 50%))
///     rect((6,0), (rel: (1,1)), radius: (north-east: 50%))
///     rect((8,0), (rel: (1,1)), radius: (south-west: 0, rest: 50%))
///     rect((10,0), (rel: (1,1)), radius: (rest: (20%, 50%)))
///     ```, vertical: true)
///   ])
///
/// = Anchors
///   Supports compass anchors.
///
/// - a (coordinate): Coordinate of the bottom left corner of the rectangle.
/// - b (coordinate): Coordinate of the top right corner of the rectangle. You can draw a rectangle with a specified width and height by using relative coordinates for this parameter `(rel: (width, height))`.
/// - name (none,string):
/// - anchor (none,string):
/// - ..style (style):
#let rect(a, b, name: none, anchor: none, ..style) = {
  // Coordinate check
  let t = (a, b).map(coordinate.resolve-system)

  // No extra positional arguments from the style sink
  assert.eq(
    style.pos(),
    (),
    message: "Unexpected positional arguments: " + repr(style.pos()),
  )
  let style = style.named()

  return (
    ctx => {
      let ctx = ctx
      let (ctx, a, b) = coordinate.resolve(ctx, a, b)
      assert(a.at(2) == b.at(2),
        message: "Both rectangle points must have the same z value.")
      (a, b) = {
        let lo = (
          calc.min(a.at(0), b.at(0)),
          calc.min(a.at(1), b.at(1)),
          calc.min(a.at(2), b.at(2)),
        )
        let hi = (
          calc.max(a.at(0), b.at(0)),
          calc.max(a.at(1), b.at(1)),
          calc.max(a.at(2), b.at(2)),
        )
        (lo, hi)
      }

      let style = styles.resolve(ctx.style, merge: style, root: "rect")
      let (x1, y1, z1) = a
      let (x2, y2, z2) = b

      let size = (calc.abs(x2 - x1), calc.abs(y2 - y1))
      let (north-west: nw, north-east: ne,
           south-west: sw, south-east: se) = util.as-corner-radius-dict(ctx, style.radius, size)

      let drawables = {
        let z = z1

        // Compute two corner points offset by radius from origin pt.
        //
        //   x radius * a
        //    |----|
        // --p1←--pt  ---
        //         |   | y radius * b
        //         ↓   |
        //         p2 ---
        //         |
        //
        // parameters a and b function as direction vectors in which
        // direction the resulting points p1 and p2 should get offset to.
        //
        // The point pt is the corner point of the non-rounded rectangle.
        // If the radius is zero, we can just return that point for both
        // new corners.
        let get-corner-pts(radius, pt, a, b) = {
          let (rx, ry) = radius
          if rx > 0 or ry > 0 {
            let (xa, ya) = a
            let (xb, yb) = b
            (vector.add(pt, (xa * rx, ya * ry)),
             vector.add(pt, (xb * rx, yb * ry)))
          } else {
            (pt, pt)
          }
        }

        // Get segments for arc between start- and stop angle, starting
        // at point. If radius is zero for both axes, x and y, nothing
        // gets returned.
        //
        // s----p0/
        //      p1
        //       |
        //       e
        //
        // Returns a cubic bezier curve between s and e
        // with the control points pointing from s in direction
        // p0 * radius and from e in direction p1 * radius.
        // The bezier approximates a 90 degree arc.
        let corner-arc(radius, s, e, p0, p1) = {
          let (rx, ry) = radius
          if rx > 0 or ry > 0 {
            let m = 0.551784
            let p0 = (p0.at(0) * m * radius.at(0),
                      p0.at(1) * m * radius.at(1))
            let p1 = (p1.at(0) * m * radius.at(0),
                      p1.at(1) * m * radius.at(1))
            (path-util.cubic-segment(s, e,
              vector.add(s, p0),
              vector.add(e, p1)),)
          }
        }

        // Compute all eight corner points:
        //
        //    p1-------p2
        //   / |       | \
        // p0--+       +--p3
        //  |             |
        // p7--+       +--p4
        //   \ |       | /
        //    p6-------p5
        //
        // If a corner has radius (0,0), both of its
        // corner points are the same. See the comment on get-corner-pts
        // on how the corners get computed.
        let (p0, p1) = get-corner-pts(nw, (x1, y2, z), ( 0,-1), ( 1, 0))
        let (p2, p3) = get-corner-pts(ne, (x2, y2, z), (-1, 0), ( 0,-1))
        let (p4, p5) = get-corner-pts(se, (x2, y1, z), ( 0, 1), (-1, 0))
        let (p6, p7) = get-corner-pts(sw, (x1, y1, z), ( 1, 0), ( 0, 1))

        let segments = ()
        segments += corner-arc(nw, p0, p1, (0, 1), (-1, 0))
        if p1 != p2 { segments += (path-util.line-segment((p1, p2)),) }
        segments += corner-arc(ne, p2, p3, (1, 0), (0, 1))
        if p3 != p4 { segments += (path-util.line-segment((p3, p4)),) }
        segments += corner-arc(se, p4, p5, (0, -1), (1, 0))
        if p5 != p6 { segments += (path-util.line-segment((p5, p6)),) }
        segments += corner-arc(sw, p6, p7, (-1, 0), (0,-1))
        if p7 != p0 { segments += (path-util.line-segment((p7, p0)),) }

        drawable.path(segments, fill: style.fill, stroke: style.stroke, close: true)
      }

      // Calculate border anchors
      let center = vector.scale(vector.add(a, b), .5)
      let border = anchor_.border.with(
        center, size.at(0), size.at(1), drawables)

      let (transform, anchors) = anchor_.setup(
        (anchor) => {
          if anchor in anchor_.compass-angle {
            return border(anchor_.compass-angle.at(anchor))
          }
          else if anchor == "center" {
            return center
          }
        },
        ("north", "south-west", "south", "south-east", "north-west", "north-east", "east", "west", "center"),
        default: "center",
        name: name,
        offset-anchor: anchor,
        transform: ctx.transform
      )

      return (
        ctx: ctx,
        name: name,
        anchors: anchors,
        drawables: drawable.apply-transform(transform, drawables),
      )
    },
  )
}

/// Draws a quadratic or cubic bezier curve
///
/// #example(```
/// let (a, b, c) = ((0, 0), (2, 0), (1, 1))
/// line(a, c,  b, stroke: gray)
/// bezier(a, b, c)
///
/// let (a, b, c, d) = ((0, -1), (2, -1), (.5, -2), (1.5, 0))
/// line(a, c, d, b, stroke: gray)
/// bezier(a, b, c, d)
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root* `bezier`
/// == Keys
///   Supports marks.
///
/// = Anchors
///   / ctrl-n: nth control point where n is an integer starting at 0
///   / start: The start position of the curve.
///   / end: The end position of the curve.
///
/// - start (coordinate): Start position
/// - end (coordinate): End position (last coordinate)
/// - name (none,string):
/// - ..ctrl-style (coordinate,style): The first two positional arguments are taken as cubic bezier control points, where the first is the start control point and the second is the end control point. One control point can be given for a quadratic bezier curve instead. Named arguments are for styling.
#let bezier(start, end, ..ctrl-style, name: none) = {
  // Extra positional arguments are treated like control points.
  let (ctrl, style) = (ctrl-style.pos(), ctrl-style.named())

  // Control point check
  let len = ctrl.len()
  assert(
    len in (1, 2),
    message: "Bezier curve expects 1 or 2 control points. Got " + str(len),
  )
  let coordinates = (start, ..ctrl, end)

  // Coordinates check
  let t = coordinates.map(coordinate.resolve-system)

  return (
    ctx => {
      let (ctx, start, ..ctrl, end) = coordinate.resolve(ctx, ..coordinates)

      if ctrl.len() == 1 {
        (start, end, ..ctrl) = bezier_.quadratic-to-cubic(start, end, ..ctrl)
      }

      let (transform, anchors) = anchor_.setup(
        anchor => {
          (
            start: start,
            end: end,
            ctrl-0: ctrl.at(0),
            ctrl-1: ctrl.at(1),
          ).at(anchor)
        },
        ("start", "end", "ctrl-0", "ctrl-1"),
        default: "start",
        name: name,
        transform: ctx.transform
      )

      let style = styles.resolve(ctx.style, merge: style, root: "bezier")

      let curve = (start, end, ..ctrl)
      let (marks, curve) = if style.mark != none {
        mark_.place-marks-along-bezier(ctx, curve, style, style.mark)
      } else {
        (none, curve)
      }

      let drawables = (drawable.path(
        path-util.cubic-segment(..curve),
        fill: style.fill,
        stroke: style.stroke,
      ),)

      if marks != none {
        drawables += marks
      }

      return (
        ctx: ctx,
        name: name,
        anchors: anchors,
        drawables: drawable.apply-transform(
          transform,
          drawables
        )
      )
    },
  )
}

/// Draw a cubic bezier curve through a set of three points. See `bezier` for style and anchor details.
///
/// #example(```
/// let (a, b, c) = ((0, 0), (1, 1), (2, -1))
/// line(a, b, c, stroke: gray)
/// bezier-through(a, b, c, name: "b")
///
/// // Show calculated control points
/// line(a, "b.ctrl-0", "b.ctrl-1", c, stroke: gray)
/// ```)
///
/// - start (coordinate): Start position
/// - pass-through (coordinate): Curve mid-point
/// - end (coordinate): End coordinate
/// - name (none,string):
/// - ..style (style):
#let bezier-through(start, pass-through, end, name: none, ..style) = {
  assert.eq(style.pos(), (), message: "Unexpected positional arguments: " + repr(style.pos()))
  style = style.named()

  return (ctx => {
    let (ctx, start, pass-through, end) = coordinate.resolve(ctx, start, pass-through, end)

    let (start, end, ..control) = bezier_.cubic-through-3points(start, pass-through, end)

    return bezier(start, end, ..control, ..style, name: name).first()(ctx)
  },)
}

/// Draw a Catmull-Rom curve through a set of points.
///
/// #example(```
/// catmull((0,0), (1,1), (2,-1), (3,0), tension: .4, stroke: blue)
/// catmull((0,0), (1,1), (2,-1), (3,0), tension: .5, stroke: red)
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root* `catmull`\
/// == Keys
///   #show-parameter-block("tension", "float", [I need a description], default: 0.5)
///   Supports marks.
///
/// = Anchors
///   / start: The position of the start of the curve.
///   / end: The position of the end of the curve.
///   / pt-n: The nth given position (0 indexed so "pt-0" is equal to "start")
///
/// - ..pts-style (coordinate,style): Positional arguments should be coordinates that the curve should pass through. Named arguments are for styling.
/// - close (bool): Closes the curve with a straight line between the start and end of the curve.
/// - name (none,string):
#let catmull(..pts-style, close: false, name: none) = {
  let (pts, style)  = (pts-style.pos(), pts-style.named())

  assert(pts.len() >= 2, message: "Catmull-rom curve requires at least two points. Got " + repr(pts.len()) + "instead.")

  pts.map(coordinate.resolve-system)

  return (ctx => {
    let (ctx, ..pts) = coordinate.resolve(ctx, ..pts)

    let (transform, anchors) = {
      let a = (
        start: pts.first(),
        end: pts.last(),
      )
      for (i, pt) in pts.enumerate() {
        a.insert("pt-" + str(i), pt)
      }
      anchor_.setup(
        anchor => {
          a.at(anchor)
        },
        a.keys(),
        name: name,
        default: "start",
        transform: ctx.transform
      )
    }

    let style = styles.resolve(ctx.style, merge: style, root: "catmull")
    let curves = bezier_.catmull-to-cubic(
      pts,
      style.tension,
      close: close)

    let (marks, curves) = if style.mark != none {
      mark_.place-marks-along-beziers(ctx, curves, style, style.mark)
    } else {
      (none, curves)
    }

    let drawables = (
      drawable.path(
        curves.map(c => path-util.cubic-segment(..c)),
        fill: style.fill,
        stroke: style.stroke,
        close: close),)
    if marks != none {
      drawables += marks
    }

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(
        transform,
        drawables
      )
    )
  },)
}

/// Draws a Hobby curve through a set of points.
///
/// #example(```
/// hobby((0, 0), (1, 1), (2, -1), (3, 0), omega: 0, stroke: blue)
/// hobby((0, 0), (1, 1), (2, -1), (3, 0), omega: 1, stroke: red)
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root* `hobby`
/// == Keys
///   Supports marks.
///   #show-parameter-block("omega", "idk", [The curve's curlyness])
///   #show-parameter-block("rho", "idk", [])
///
/// = Anchors
///   / start: The position of the start of the curve.
///   / end: The position of the end of the curve.
///   / pt-n: The nth given position (0 indexed, so "pt-0" is equal to "start")
///
/// - ..pts-style (coordinate,style): Positional arguments are the coordinates to use to draw the curve with, a minimum of two is required. Named arguments are for styling.
/// - tb (auto,array): Incoming tension at `pts.at(n+1)` from `pts.at(n)` to `pts.at(n+1)`. The number given must be one less than the number of points.
/// - ta (auto, array): Outgoing tension at `pts.at(n)` from `pts.at(n)` to `pts.at(n+1)`. The number given must be one less than the number of points.
/// - close (bool): Closes the curve with a straight line between the start and end of the curve.
/// - name (none,string):
#let hobby(..pts-style, ta: auto, tb: auto, close: false, name: none) = {
  let (pts, style)  = (pts-style.pos(), pts-style.named())

  assert(pts.len() >= 2, message: "Hobby curve requires at least two points. Got " + repr(pts.len()) + "instead.")

  pts.map(coordinate.resolve-system)

  return (ctx => {
    let (ctx, ..pts) = coordinate.resolve(ctx, ..pts)

    let (transform, anchors) = {
      let a = (
        start: pts.first(),
        end: pts.last(),
      )
      for (i, pt) in pts.enumerate() {
        a.insert("pt-" + str(i), pt)
      }
      anchor_.setup(
        anchor => {
          a.at(anchor)
        },
        a.keys(),
        name: name,
        default: "start",
        transform: ctx.transform
      )
    }

    let style = styles.resolve(ctx.style, merge: style, root: "hobby")
    let curves = hobby_.hobby-to-cubic(
      pts,
      ta: ta,
      tb: tb,
      omega: style.omega,
      rho: style.rho,
      close: close)

    let (marks, curves) = if style.mark != none {
      mark_.place-marks-along-beziers(ctx, curves, style, style.mark)
    } else {
      (none, curves)
    }

    let drawables = (
      drawable.path(
        curves.map(c => path-util.cubic-segment(..c)),
        fill: style.fill,
        stroke: style.stroke,
        close: close),)
    if marks != none {
      drawables += marks
    }

    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(
        transform,
        drawables
      )
    )
  },)
}

/// Merges two or more paths by concattenating their elements. Anchors and visual styling, such as `stroke` and `fill`, are not preserved. When an element's path does not start at the same position the previous element's path ended, a straight line is drawn between them so that the final path is continuous. You must then pay attention to the direction in which element paths are drawn.
///
/// #example(```
/// merge-path(fill: white, {
///   line((0, 0), (1, 0))
///   bezier((), (0, 0), (1,1), (0,1))
/// })
/// ```)
///
/// Elements hidden via `hide()` are ignored.
///
/// = parameters
///
/// = Anchors
///   / start: The start of the merged path.
///   / end: The end of the merged path.
///
/// - body (elements): Elements with paths to be merged together.
/// - close (bool): Close the path with a straight line from the start of the path to its end.
/// - name (none,string):
/// - ..style (style):
#let merge-path(body, close: false, name: none, ..style) = {
  // No extra positional arguments from the style sink
  assert.eq(
    style.pos(),
    (),
    message: "Unexpected positional arguments: " + repr(style.pos()),
  )
  let style = style.named()

  return (
    ctx => {
      let ctx = ctx
      let segments = ()
      for element in body {
        let r = process.element(ctx, element)
        if r != none {
          ctx = r.ctx
          if segments != () and r.drawables != () {
            assert.eq(r.drawables.first().type, "path")
            let start = path-util.segment-end(segments.last())
            let end = path-util.segment-start(r.drawables.first().segments.first())
            if vector.dist(start, end) > 0 {
              segments.push(path-util.line-segment((start, end,)))
            }
          }
          for drawable in r.drawables {
            if drawable.hidden { continue }
            assert.eq(drawable.type, "path")
            segments += drawable.segments
          }
        }
      }

      let style = styles.resolve(ctx.style, merge: style)

      let (transform, anchors) = anchor_.setup(
        anchor => {
          (
            start: path-util.segment-start(segments.first()),
            end: path-util.segment-end(segments.last()),
          ).at(anchor)
        },
        (
          "start",
          "end"
        ),
        name: name,
        transform: ctx.transform,
      )

      return (
        ctx: ctx,
        name: name,
        anchors: anchors,
        drawables: drawable.path(fill: style.fill, stroke: style.stroke, close: close, segments),
      )
    },
  )
}
