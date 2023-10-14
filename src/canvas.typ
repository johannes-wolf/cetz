#import "matrix.typ"
#import "vector.typ"
#import "draw.typ"
#import "cmd.typ"
#import "util.typ"
#import "coordinate.typ"
#import "styles.typ"
#import "path-util.typ"
#import "aabb.typ"

// Aliases for typst types/functions
// because we override them.
#let typst-length = length

// Recursive element traversal function which takes the current ctx, bounds and also returns them (to allow modifying function locals of the root scope)
#let process-element(element, ctx) = {
  if element == none { return }
  let drawables = ()
  let bounds = none
  let anchors = (:)

  // Allow to modify the context
  if "before" in element {
    ctx = (element.before)(ctx)
  }

  if "style" in element {
    ctx.style = util.merge-dictionary(
      ctx.style, 
      if type(element.style) == function {
        (element.style)(ctx)
      } else {
        element.style
      }
    )
  }

  if "push-transform" in element {
    if type(element.push-transform) == function {
      ctx.transform = (element.push-transform)(ctx)
    } else {
      ctx.transform = matrix.mul-mat(
        ctx.transform,
        element.push-transform
      )
    }
  }

  // Render children
  if "children" in element {
    let child-drawables = ()
    let children = if type(element.children) == function {
      (element.children)(ctx)
    } else {
      element.children
    }
    for child in children {
      let r = process-element(child, ctx)
      if r != none {
        if r.bounds != none {
          bounds = aabb.aabb(r.bounds, init: bounds)
        }

        ctx = r.ctx
        child-drawables += r.drawables
      }
    }

    if "finalize-children" in element {
      drawables += (element.finalize-children)(ctx, child-drawables)
    } else {
      drawables += child-drawables
    }
  }

  // Query element for points
  let coordinates = ()
  if "coordinates" in element {
    for c in element.coordinates {
      c = coordinate.resolve(ctx, c)

      // if the first element is `false` don't update the previous point
      if c.first() == false {
        // the format here is `(false, x, y, z)` so get rid of the boolean
        c = c.slice(1)
      } else {
        ctx.prev.pt = c
      }
      coordinates.push(c)
    }

    // If the element wants to calculate extra coordinates depending
    // on it's resolved coordinates, it can use "transform-coordinates".
    if "transform-coordinates" in element {
      assert(type(element.transform-coordinates) == function)

      coordinates = (element.transform-coordinates)(ctx, ..coordinates)
    }
  }

  // Render element
  if "render" in element {
    for drawable in (element.render)(ctx, ..coordinates) {
      // Transform position to absolute
      drawable.segments = drawable.segments.map(s => {
        return (s.at(0),) + s.slice(1).map(util.apply-transform.with(ctx.transform))
      })

      if "bounds" not in drawable {
        drawable.bounds = path-util.bounds(drawable.segments)
      } else {
        drawable.bounds = drawable.bounds.map(util.apply-transform.with(ctx.transform));
      }

      bounds = aabb.aabb(drawable.bounds, init: bounds)

      // Push draw command
      drawables.push(drawable)
    }
  }

  // Add default anchors
  if bounds != none and element.at("add-default-anchors", default: true) {
    let mid = aabb.mid(bounds)
    let (low: low, high: high) = bounds
    anchors += (
      center: mid,
      left: (low.at(0), mid.at(1), 0),
      right: (high.at(0), mid.at(1), 0),
      top: (mid.at(0), low.at(1), 0),
      bottom: (mid.at(0), high.at(1), 0),
      top-left: (low.at(0), low.at(1), 0),
      top-right: (high.at(0), low.at(1), 0),
      bottom-left: (low.at(0), high.at(1), 0),
      bottom-right: (high.at(0), high.at(1), 0),
    )
  }

  // Query element for (relative) anchors
  let custom-anchors = if "custom-anchors-ctx" in element {
    (element.custom-anchors-ctx)(ctx, ..coordinates)
  } else if "custom-anchors" in element {
    (element.custom-anchors)(..coordinates)
  }
  if custom-anchors != none {
    for (k, a) in custom-anchors {
      anchors.insert(k, util.apply-transform(ctx.transform, a)) // Anchors are absolute!
    }
  }

  // Query (already absolute) anchors depending on drawable
  if "custom-anchors-drawables" in element {
    for (k, a) in (element.custom-anchors-drawables)(drawables) {
      anchors.insert(k, a)
    }
  }

  if "default" not in anchors {
    anchors.default = if "default-anchor" in element {
      anchors.at(element.default-anchor)
    } else if "center" in anchors {
      anchors.center
    } else {
      (0,0,0,1)
    }
  }

  if "anchor" in element and element.anchor != none {
    assert(element.anchor in anchors,
          message: "Anchor '" + element.anchor + "' not found in " + repr(anchors))
    let translate = vector.sub(anchors.default, anchors.at(element.anchor))
    for (i, d) in drawables.enumerate() {
        drawables.at(i).segments = d.segments.map(
          s => (s.at(0),) + s.slice(1).map(c => vector.add(translate, c)))
    }

    for (k, a) in anchors {
      anchors.insert(k, vector.add(translate, a))
    }

    bounds = if bounds != none {
      aabb.aabb((vector.add(translate, (bounds.low.at(0), bounds.low.at(1))),
                 vector.add(translate, (bounds.high.at(0), bounds.high.at(1)))))
    }
  }

  if "name" in element and type(element.name) == str {
    ctx.nodes.insert(
      element.name, 
      (
        anchors: anchors,
        // paths: drawables, // Uncomment as soon as needed
      )
    )
  }

  if ctx.debug and bounds != none {
    drawables.push(
      cmd.path(
        stroke: red, 
        fill: none, 
        close: true, 
        ("line", bounds.low,
                 (bounds.high.at(0), bounds.low.at(1)),
                 bounds.high,
                 (bounds.low.at(0), bounds.high.at(1)))
      ).first()
    )
  }

  if "after" in element {
    ctx = (element.after)(ctx, ..coordinates)
  }

  return (bounds: bounds, ctx: ctx, drawables: drawables)
}

#let canvas(length: 1cm,        /* Length of 1.0 canvas units */
            background: none,   /* Background paint */
            debug: false, body) = layout(ly => style(st => {
  if body == none {
    return []
  }

  let length = length
  assert(type(length) in (typst-length, ratio),
         message: "length: Expected length, got " + type(length) + ".")
  if type(length) == ratio {
    // NOTE: Ratio length is based on width!
    length = ly.width * length
  } else {
    // HACK: To convert em sizes to absolute sizes, we
    //       measure a rect of that size.
    length = measure(line(length: length), st).width
  }

  // Canvas bounds
  let bounds = none

  // Canvas context object
  let ctx = (
    typst-style: st,
    length: length,

    debug: debug,

    // Previous element position & bbox
    prev: (pt: (0, 0, 0)),

    // Current content padding size (added around content boxes)
    content-padding: 0em,

    em-size: measure(box(width: 1em, height: 1em), st),

    style: (:),

    // Current transform
    transform: matrix.mul-mat(
      matrix.transform-shear-z(.5),
      matrix.transform-scale((x: 1, y: -1, z: 1)),
    ),

    // Nodes, stores anchors and paths
    nodes: (:),

    // group stack
    groups: (),
  )
  
  let draw-cmds = ()
  for element in body {
    let r = process-element(element, ctx)
    if r != none {
      if r.bounds != none {
        bounds = aabb.aabb(r.bounds, init: bounds)
      }
      ctx = r.ctx
      draw-cmds += r.drawables
    }
  }

  if bounds == none {
    return []
  }

  // Order draw commands by z-index
  draw-cmds = draw-cmds.sorted(key: (cmd) => {
    return cmd.at("z-index", default: 0)
  })

  // Final canvas size
  let (width, height, ..) = vector.scale(aabb.size(bounds), length)
  
  // Offset all element by canvas grow to the bottom/left
  let transform = matrix.transform-translate(
    -bounds.low.at(0), 
    -bounds.low.at(1), 
    0
  )
  box(
    stroke: if debug {green}, 
    width: width, 
    height: height, 
    fill: background, 
    align(
      top,
      for d in draw-cmds {
        d.segments = d.segments.map(s => {
          return (s.at(0),) + s.slice(1).map(v => {
            return util.apply-transform(transform, v)
              .slice(0,2).map(x => ctx.length * x)
          })
        })
        (d.draw)(d)
      }
    )
  )
}))
