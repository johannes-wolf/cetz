#import "matrix.typ"
#import "vector.typ"
#import "util.typ"
#import "path-util.typ"
#import "aabb.typ"
#import "styles.typ"
#import "process.typ"

#import util: typst-length

/// Sets up a canvas for drawing on. 
///
/// - length (length,ratio): Used to specify what 1 coordinate unit is. If given a ratio, that ratio is relative to the containing elements width!
/// - body (none,array,element): A code block in which functions from `draw.typ` have been called.
/// - background (none,color): A color to be used for the background of the canvas.
/// - debug (bool): Shows the bounding boxes of each element when `true`.
/// -> content
#let canvas(length: 1cm, debug: false, background: none, body) = layout(ly => style(st => {
  if body == none {
    return []
  }
  assert(
    type(body) == array,
    message: "Incorrect type for body: " + repr(type(body)),
  )

  assert(type(length) in (typst-length, ratio), message: "Expected `length` to be of type length or ratio, got " + repr(length))
  let length = if type(length) == ratio {
    length * ly.width
  } else {
    measure(box(width: length, height: length), st).width
  }
  assert(length / 1cm != 0,
    message: "Canvas length must be != 0!")

  let ctx = (
    typst-style: st,
    length: length,
    debug: debug,
    // Previous element position & bbox
    prev: (pt: (0, 0, 0)),
    em-size: measure(box(width: 1em, height: 1em), st),
    style: styles.default,
    // Current transform
    transform: matrix.mul-mat(
      matrix.transform-shear-z(-.5),
      matrix.transform-scale((y: -1))),
    // Nodes, stores anchors and paths
    nodes: (:),
    // group stack
    groups: (),
  )

  let (ctx, bounds, drawables) = process.many(ctx, body)
  if bounds == none {
    return []
  }

  // Filter hidden drawables
  drawables = drawables.filter(d => not d.hidden)

  // Order draw commands by z-index
  drawables = drawables.sorted(key: (cmd) => {
    return cmd.at("z-index", default: 0)
  })

  // Final canvas size
  let (width, height, ..) = vector.scale(aabb.size(bounds), length)

  let relative = (orig, c) => {
    return vector.sub(c, orig)
  }

  box(width: width, height: height, fill: background, align(top, {
    for drawable in drawables {
      // Typst path elements have strange bounding boxes. We need to
      // offset all paths to start at (0, 0) to make gradients work.
      let (x, y, _) = if drawable.type == "path" {
        vector.sub(
          aabb.aabb(path-util.bounds(drawable.segments)).low,
          bounds.low)
      } else {
        (0, 0, 0)
      }

      place(top + left, if drawable.type == "path" {
        let vertices = ()
        for s in drawable.segments {
          let type = s.at(0)
          let coordinates = s.slice(1).map(c => {
            return (
              (c.at(0) - bounds.low.at(0) - x) * length,
              (c.at(1) - bounds.low.at(1) - y) * length,
            )
          })
          assert(
            type in ("line", "cubic"),
            message: "Path segments must be of type line, cubic",
          )

          if type == "cubic" {
            let a = coordinates.at(0)
            let b = coordinates.at(1)
            let ctrla = relative(a, coordinates.at(2))
            let ctrlb = relative(b, coordinates.at(3))

            vertices.push((a, (0pt, 0pt), ctrla))
            vertices.push((b, ctrlb, (0pt, 0pt)))
          } else {
            vertices += coordinates
          }
        }
        if type(drawable.stroke) == dictionary and "thickness" in drawable.stroke and type(drawable.stroke.thickness) != typst-length {
          drawable.stroke.thickness *= length
        }
        path(
          stroke: drawable.stroke,
          fill: drawable.fill,
          closed: drawable.at("close", default: false),
          ..vertices,
        )
      } else if drawable.type == "content" {
        let (width, height) = util.typst-measure(drawable.body, ctx.typst-style)
        move(
          dx: (drawable.pos.at(0) - bounds.low.at(0)) * length - width / 2,
          dy: (drawable.pos.at(1) - bounds.low.at(1)) * length - height / 2,
          drawable.body,
        )
      }, dx: x * length, dy: y * length)
    }
  }))
}))
