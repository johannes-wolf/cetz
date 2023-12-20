#import "/src/process.typ"
#import "/src/intersection.typ"
#import "/src/path-util.typ"
#import "/src/styles.typ"
#import "/src/drawable.typ"
#import "/src/vector.typ"
#import "/src/util.typ"
#import "/src/coordinate.typ"
#import "/src/aabb.typ"
#import "/src/anchor.typ" as anchor_
#import "/src/deps.typ"
#import deps.oxifmt: strfmt

#import "transformations.typ": move-to

/// Hides an element.
///
/// Hidden elements are not drawn to the canvas,
/// are ignored when calculating bounding boxes and discarded by `merge-path`. All
/// other behaviours remain the same as a non-hidden element.
///
/// #example(```
/// set-style(radius: .5)
/// intersections("i", {
///   circle((0,0), name: "a")
///   circle((1,2), name: "b")
///   // Use a hidden line to find the border intersections
///   hide(line("a.center", "b.center"))
/// })
/// line("i.0", "i.1")
/// ```)
///
/// - body (element): One or more elements to hide
#let hide(body) = {
  if type(body) == array {
    return body.map(f => {
      (ctx) => {
        let element = f(ctx)
        if "drawables" in element {
          element.drawables = element.drawables.map(d => {
            d.hidden = true
            return d
          })
        }
        return element
      }
    })
  }
  return body
}

/// Calculates the intersections between multiple paths and creates one anchor
/// per intersection point.
///
/// All resulting anchors will be named numerically, starting at 0.
/// i.e., a call `intersections("a", ...)` will generate the anchors
/// `"a.0"`, `"a.1"`, `"a.2"` to `"a.n"`, depending of the number of
/// intersections.
///
/// #example(```
/// intersections("i", {
///   circle((0, 0))
///   bezier((0,0), (3,0), (1,-1), (2,1))
///   line((0,-1), (0,1))
///   rect((1.5,-1),(2.5,1))
/// })
/// for-each-anchor("i", (name) => {
///   circle("i." + name, radius: .1, fill: blue)
/// })
/// ```)
///
/// You can also use named elements:
///
/// #example(```
/// circle((0,0), name: "a")
/// rect((0,0), (1,1), name: "b")
/// intersections("i", "a", "b")
/// for-each-anchor("i", (name) => {
///   circle("i." + name, radius: .1, fill: blue)
/// })
/// ```)
///
/// You can calculate intersections with hidden elements by using @@hide().
///
/// - name (string): Name to prepend to the generated anchors.
/// - ..elements (elements,string): Elements and/or element names to calculate intersections with.
///   Elements referred to by name are (unlike elements passed) not drawn by the intersections function!
/// - samples (int): Number of samples to use for non-linear path segments. A higher sample count can give more precise results but worse performance.
#let intersections(name, ..elements, samples: 10) = {
  samples = calc.clamp(samples, 2, 2500)

  assert(type(name) == str and name != "",
    message: "Intersection must have a name, got:" + repr(name))
  assert(elements.pos() != (),
    message: "You must at least give one element to intersections.")

  return (ctx => {
    let ctx = ctx

    let named-drawables = () // List of elements to calc intersections for
    let drawables = () // List of elements to draw + calc intersections for

    for elem in elements.pos() {
      if type(elem) == str {
        assert(elem in ctx.nodes,
          message: "No such element '" + elem + "' in elements " + repr(ctx.nodes.keys()))
        named-drawables += ctx.nodes.at(elem).drawables
      } else {
        let new-drawables = ()
        (ctx: ctx, drawables: new-drawables, ..) = process.many(ctx, elem)
        drawables += new-drawables
      }
    }

    // Filter out elements that can not intersect
    let paths = (named-drawables + drawables).filter(d => d.type == "path")

    let pts = ()
    if paths.len() > 1 {
      for (i, path-1) in paths.enumerate() {
        for path-2 in paths.slice(i+1) {
          for pt in intersection.path-path(
            path-1,
            path-2,
            samples: samples
          ) {
            if pt not in pts { pts.push(pt) }
          }
        }
      }
    }
    let anchors = (:)
    for (i, pt) in pts.enumerate() {
      anchors.insert(str(i), pt)
    }

    return (
      ctx: ctx,
      name: name,
      anchors: anchor_.setup(
        anchor => {
          anchors.at(anchor)
        },
        anchors.keys(),
        transform: none,
        name: name
      ).last(),
      drawables: drawables
    )
  },)
}

/// Groups one or more elements together. This element acts as a scope, all state changes such as transformations and styling only affect the elements in the group. Elements after the group are not affected by the changes inside the group.
///
/// #example(```
/// // Create group
/// group({
///   stroke(5pt)
///   scale(.5); rotate(45deg)
///   rect((-1,-1),(1,1))
/// })
/// rect((-1,-1),(1,1))
/// ```)
///
/// = parameters
///
/// = Styling
/// *Root* `group`
///
/// == Keys
///   #show-parameter-block("padding", ("none", "number", "array", "dictionary"), default: none, [How much padding to add around the group's bounding box. `none` applies no padding. A number applies padding to all sides equally. A dictionary applies padding following Typst's `pad` function: https://typst.app/docs/reference/layout/pad/. An array follows CSS like padding: `(y, x)`, `(top, x, bottom)` or `(top, right, bottom, left)`.])
///
/// = Anchors
///   Supports compass anchors. These are created based on the axis aligned bounding box of all the child elements of the group.
///
/// You can add custom anchors to the group by using the `anchor` element while in the scope of said group, see `anchor` for more details. You can also copy over anchors from named child element by using the `copy-anchors` element as they are not accessible from outside the group.
///
/// The default anchor is "center" but this can be overridden by using `anchor` to place a new anchor called "default".
///
/// - body (elements, function): Elements to group together. A least one is required. A function that accepts `ctx` and returns elements is also accepted.
/// - anchor (none, string): Anchor to position the group and it's children relative to. For translation the difference between the groups `"center"` anchor
///   and the passed anchor is used.
/// - name (none, string):
/// - ..style (style):
#let group(body, name: none, anchor: none, ..style) = {
  assert(type(body) in (array, function), message: "Incorrect type for body, expected an array or function. Instead got: " + repr(body))
  // No extra positional arguments from the style sink
  assert.eq(
    style.pos(),
    (),
    message: "Unexpected positional arguments: " + repr(style.pos()),
  )
  (ctx => {
    let style = styles.resolve(ctx.style, merge: style.named(), root: "group")

    let bounds = none
    let drawables = ()
    let group-ctx = ctx
    group-ctx.groups.push((anchors: (:)))
    (ctx: group-ctx, drawables, bounds) = process.many(group-ctx, if type(body) == function {body(ctx)} else {body})

    // Apply bounds padding
    let bounds = if bounds != none {
      let padding = util.as-padding-dict(style.padding)
      for (k, v) in padding {
        padding.insert(k, util.resolve-number(ctx, v))
      }

      aabb.padded(bounds, padding)
    }

    let (transform, anchors) = anchor_.setup(
      anchor => {
        let anchors = (:)
        if bounds != none {
          let bounds = bounds
          (bounds.low.at(1), bounds.high.at(1)) = (bounds.high.at(1), bounds.low.at(1))
          let mid = aabb.mid(bounds)
          anchors += (
            north: (mid.at(0), bounds.high.at(1)),
            north-east: bounds.high,
            east: (bounds.high.at(0), mid.at(1)),
            south-east: (bounds.high.at(0), bounds.low.at(1)),
            south: (mid.at(0), bounds.low.at(1)),
            south-west: bounds.low,
            west: (bounds.low.at(0), mid.at(1)),
            north-west: (bounds.low.at(0), bounds.high.at(1)),
            center: mid,
          )
        }
        // Custom anchors need to be added last to override the compass anchors.
        anchors += group-ctx.groups.last().anchors
        return anchors.at(anchor)
      },
      group-ctx.groups.last().anchors.keys() + if bounds != none { ("north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west", "center") },
      name: name,
      default: if bounds != none { "center" } else { none },
      offset-anchor: anchor
    )
    return (
      ctx: ctx,
      name: name,
      anchors: anchors,
      drawables: drawable.apply-transform(transform, drawables),
    )
  },)
}

/// Creates a new anchor for the current group. This element can only be used inside a group otherwise it will panic. The new anchor will be accessible from inside the group by using just the anchor's name as a coordinate.
///
/// #example(```
/// // Create group
/// group(name: "g", {
///   circle((0,0))
///   anchor("x", (.4, .1))
///   circle("x", radius: .2)
/// })
/// circle("g.x", radius: .1)
/// ```)
///
/// - name (string): The name of the anchor
/// - position (coordinate): The position of the anchor
#let anchor(name, position) = {
  coordinate.resolve-system(position)
  return (ctx => {
    assert(
      ctx.groups.len() > 0,
      message: "Anchor '" + name + "' created outside of group!",
    )
    let (ctx, position) = coordinate.resolve(ctx, position)
    position = util.apply-transform(ctx.transform, position)
    ctx.groups.last().anchors.insert(name, position)
    return (ctx: ctx, name: name, anchors: anchor_.setup(anchor => position, ("default",), default: "default", name: name, transform: none).last())
  },)
}

/// Copies multiple anchors from one element into the current group. Panics when used outside of a group. Copied anchors will be accessible in the same way anchors created by the `anchor` element are.
///
/// - element (string): The name of the element to copy anchors from.
/// - filter (auto,array): When set to `auto` all anchors will be copied to the group. An array of anchor names can instead be given so only the anchors that are in the element and the list will be copied over.
#let copy-anchors(element, filter: auto) = {
  (ctx => {
    assert(
      ctx.groups.len() > 0,
      message: "copy-anchors cannot be used outside of a group.",
    )
    assert(
      element in ctx.nodes,
      message: "copy-anchors: Could not find element '" + element + "'",
    )

    let calc-anchors = ctx.nodes.at(element).anchors
    let anchors = calc-anchors(())
    if filter != auto {
      anchors = anchors.filter(a => a in filter)
    }

    let new = {
      let d = (:)
      for a in anchors {
        d.insert(a, calc-anchors(a))
      }
      d
    }

    // Add each anchor as own element
    for (k, v) in new {
      ctx.nodes.insert(k, (anchors: (name => {
        if name == () { return ("default",) }
        else if name == "default" { v }
      })))
    }

    // Add anchors to group
    ctx.groups.last().anchors += new

    return (ctx: ctx)
  },)
}

/// Place multiple anchors along a path.
///
/// *DEPRECATED*
///
/// #example(```
/// place-anchors(circle(()), "circle", ("a", 0), ("b", .5), ("c", .75))
/// for-each-anchor("circle", n => {
///   circle("circle." + n, radius: .1, fill: blue, stroke: none)
/// })
/// ```)
///
/// - path (drawable): Single drawable
/// - name: (string): The grouping elements name
/// - ..anchors (array): List of anchor tuples `(name, pos)` or dictionaries of the
///   form `(name: <string>, pos: <float, ratio>)`, where `pos` is a relative position
///   on the path from `0` to `1` or 0% to 100%.
#let place-anchors(path, name, ..anchors) = {
  assert(type(name) == str,
    message: "Name must be of type string, got: " + type(name))

  return (ctx => {
    let (ctx, drawables) = process.many(ctx, path)

    assert(drawables.first().type == "path")
    let s = drawables.first().segments

    let out = (:)
    for a in anchors.pos() {
      assert(type(a) in (dictionary, array),
        message: "Expected anchor tuple or dictionary, got: " + repr(a))
      let (name, pos) = if type(a) == dictionary {
        (a.name, a.pos)
      } else {
        a
      }
      if type(pos) != ratio {
        pos *= 100%
      }
      out.insert(name, path-util.point-on-path(s, pos))
    }

    return (
      ctx: ctx,
      name: name,
      anchors: anchor_.setup(
        anchor => {
          out.at(anchor)
        },
        out.keys(),
        name: name,
        transform: none
      ).last(),
      drawables: drawables
    )
  },)
}

/// An advanced element that allows you to modify the current canvas context.
///
/// A context object holds the canvas' state, such as the element dictionary,
/// the current transformation matrix, group and canvas unit length. The following
/// fields are considered stable:
/// - `length` (length): Length of one canvas unit as typst length
/// - `transform` (cetz.matrix): Current 4x4 transformation matrix
/// - `debug` (bool): True if the canvas' debug flag is set
///
/// #example(```
/// // Setting a custom transformation matrix
/// set-ctx(ctx => {
///   let mat = ((1, 0, .5, 0),
///              (0, 1,  0, 0),
///              (0, 0,  1, 0),
///              (0, 0,  0, 1))
///   ctx.transform = mat
///   return ctx
/// })
/// circle((z: 0), fill: red)
/// circle((z: 1), fill: blue)
/// circle((z: 2), fill: green)
/// ```)
///
/// - callback (function): A function that accepts the context dictionary and only returns a new one.
#let set-ctx(callback) = {
  assert(type(callback) == function)
  return (ctx => (ctx: callback(ctx)),)
}

/// An advanced element that allows you to read the current canvas context through a callback and return elements based on it.
///
/// #example(```
/// // Print the transformation matrix
/// get-ctx(ctx => {
///   content((), [#repr(ctx.transform)])
/// })
/// ```)
///
/// - callback (function): A function that accepts the context dictionary and can return elements.
#let get-ctx(callback) = {
  assert(type(callback) == function)
  (ctx => {
    let body = callback(ctx)
    if body != none {
      let (ctx, drawables) = process.many(ctx, callback(ctx))
      return (ctx: ctx, drawables: drawables)
    }
    return (ctx: ctx)
  },)
}

/// Iterates through all anchors of an element and calls a callback for each one.
///
/// #example(```
/// // Label nodes anchors
/// rect((0, 0), (2,2), name: "my-rect")
/// for-each-anchor("my-rect", (name) => {
///    content((), box(inset: 1pt, fill: white, text(8pt, [#name])), angle: -30deg)
/// })
/// ```)
///
/// - name (string): The name of the element with the anchors to loop through.
/// - callback (function): A function that takes the anchor name and can return elements.
#let for-each-anchor(name, callback) = {
  get-ctx(ctx => {
    assert(
      name in ctx.nodes,
      message: strfmt("Unknown element {} in elements {}", name, repr(ctx.nodes.keys()))
    )
    for anchor in (ctx.nodes.at(name).anchors)(()) {
      move-to(name + "." + anchor)
      callback(anchor)
    }
  })
}

/// Places elements on a specific layer.
///
/// A layer determines the position of an element in the draw queue. A lower
/// layer is drawn before a higher layer.
///
/// Layers can be used to draw behind or in front of other elements, even if
/// the other elements were created before or after. An example would be drawing
/// a background behind a text, but using the text's calculated bounding box for
/// positioning the background.
///
/// #example(```
/// // Draw something behind text
/// set-style(stroke: none)
/// content((0, 0), [This is an example.], name: "text")
/// on-layer(-1, {
///   circle("text.north-east", radius: .3, fill: red)
///   circle("text.south", radius: .4, fill: green)
///   circle("text.north-west", radius: .2, fill: blue)
/// })
/// ```)
///
/// - layer (float, integer): The layer to place the elements on. Elements placed without `on-layer` are always placed on layer 0.
/// - body (elements): Elements to draw on the layer specified.
#let on-layer(layer, body) = {
  assert(type(layer) in (int, float), message: "Layer must be a float or integer, 0 being the default layer. Got: " + repr(layer))
  assert(type(body) in (function, array))
  return (ctx => {
    let (ctx, drawables, ..) = process.many(ctx, if type(body) == function { body(ctx) } else { body })

    drawables = drawables.map(d => {
      if d.at("z-index", default: none) == none {
        d.z-index = layer
      }
      return d
    })

    return (
      ctx: ctx,
      drawables: drawables
    )
  },)
}

/// TODO: Not writing the docs for this as it should be removed in place of better anchors before 0.2
/// Place one or more marks along a path
///
/// Mark items must get passed as positional arguments. A `mark-item` is an dictionary
/// of the format: `(mark: "<symbol>", pos: <float>)`, where the position `pos` is a
/// relative position from `0` to `1` along the path.
///
/// - name (none,string): Element name
/// - path (drawable): A single drawable
/// - ..marks-style (mark-item,style): Positional `mark-item`s and style key-value pairs
#let place-marks(path, ..marks-style, name: none) = {
  let (marks, style) = (marks-style.pos(), marks-style.named())
  assert(type(path) == array and path.len() == 1 and type(path.first()) == function)
  path = path.first()
  return (ctx => {
    let (ctx, drawables) = process.element(ctx, path)
    let paths = drawables.filter(d => d.type == "path")
    assert(paths.len() > 0, message: "Cannot place marks on an element with no path.")

    let path = paths.first()
    let anchors = (
      start: path-util.point-on-path(path.segments, 0%),
      end: path-util.point-on-path(path.segments, 100%)
    )

    let style = styles.resolve(ctx.style, merge: style, root: "mark")

    for mark in marks {
      let (pos, dir) = path-util.direction(path.segments, mark.pos)
      drawables.push(
        drawable.mark(
          vector.add(pos, dir),
          pos,
          mark.mark,
          style,
        )
      )
      if "name" in mark {
        anchors.insert(m.name, path-util.point-on-path(path, mark.pos * 100%))
      }
    }

    return (
      ctx: ctx,
      name: name,
      drawables: drawables,
      anchors: anchors,
    )
  },)
}
