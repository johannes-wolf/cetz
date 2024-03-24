#import "doc/util.typ": *
#import "doc/example.typ": example
#import "doc/style.typ" as doc-style

#import "src/lib.typ": *
#import "src/styles.typ"
#import "src/anchor.typ" as anchor_
#import "@preview/tidy:0.2.0"


// Usage:
//   ```example
//   /* canvas drawing code */
//   ```
#show raw.where(lang: "example"): example
#show raw.where(lang: "example-vertical"): example.with(vertical: true)




#make-title()

#set terms(indent: 1em)
#set par(justify: true)
#set heading(numbering: (..num) => if num.pos().len() < 4 {
    numbering("1.1", ..num)
  })
#show link: set text(blue)

// Outline
#{
  show heading: none
  columns(2, outline(indent: true, depth: 3))
  pagebreak(weak: true)
}

#set page(numbering: "1/1", header: align(right)[CeTZ])

= Introduction

This package provides a way to draw onto a canvas using a similar API to #link("https://processing.org/")[Processing] but with relative coordinates and anchors from #link("https://tikz.dev/")[Ti#[_k_]Z]. You also won't have to worry about accidentally drawing over other content as the canvas will automatically resize. And remember: up is positive!

The name CeTZ is a recursive acronym for "CeTZ, ein Typst Zeichenpaket" (german for "CeTZ, a Typst drawing package").

= Usage

This is the minimal starting point:
#pad(left: 1em)[```typ
#import "@preview/cetz:0.2.2"
#cetz.canvas({
  import cetz.draw: *
  ...
})
```]
Note that draw functions are imported inside the scope of the `canvas` block. This is recommended as some draw functions override Typst's function's such as `line`.

#show raw.where(block: false): it => if it.text.starts-with("<") and it.text.ends-with(">") {
    set text(1.2em)
    doc-style.show-type(it.text.slice(1, -1))
  } else { 
    it 
  }

== CeTZ Unique Argument Types
Many CeTZ functions expect data in certain formats which we will call types. Note that these are actually made up of Typst primitives.
  / `<coordinate>`: Any coordinate system. See coordinate-systems.
  / `<number>`: Any of `<float>`, `<integer>` or `<length>`. 
  / `<style>`: Named arguments (or a dictionary if used for a single argument) of style key-values.
  / `<context>`: A CeTZ context object that holds internal state.
  / `<vector>`: A three element array of `<float>`s

== Anchors <anchors>
You can refer to a position relative to an element by using its anchors. Anchors come in several different variations but can all be used in two different ways.

The first is by using the `anchor` argument on an element. When given, the element will be translated such that the given anchor will be where the given position is. This is supported by all elements that have the `anchor` argument.
```example
// Draw a circle and place its "west" anchor at the origin.
circle((0,0), anchor: "west")

// Draw a smaller red circle at the origin.
fill(red)
stroke(none)
circle((0,0), radius: 0.3)
```
The second is by using anchor coordinates. You must first give the element a name by passing a string to its `name` argument, you can then use its anchors to place other elements, see @coordinate-anchor for more usage. Note this is only available for elements that have a `name` argument.

```example
// Name the circle
circle((0,0), name: "circle")

// Draw a smaller red circle at "circle"'s east anchor
fill(red)
stroke(none)
circle("circle.east", radius: 0.3)
```
Note that all anchors are transformed along with the element.

=== Named
Named anchors are normally unique to the type of element, such as a bezier curve's control points. Other anchor variants specify their own named anchors that are available to all elements that support the anchor variant.

All elements also have a "default" named anchor, it always refers to another anchor on the element. 

=== Border
A border anchor refers to a point on the element's border where a ray is cast from the element's center at a given angle and hits the border.

They are given as angles where `0deg` is towards the right and `90deg` is up.

Border anchors also specify named compass directions such as "north", "north-east", etc. Border anchors also spefcify a "center" named anchor which is where the ray cast originates from.

```example-vertical
circle((0, 0), name: "circle", radius: 1)

set-style(content: (frame: "rect", stroke: none, fill: white, padding: .1))
content((name: "circle", anchor: 0deg), [0deg], anchor: "west")
content((name: "circle", anchor: 160deg), [160deg], anchor: "south-east")
content("circle.north", [North], anchor: "south")
content("circle.south-east", [South East], anchor: "north-west")
content("circle.south-west", [South West], anchor: "north-east")
```

=== Path 
A path anchor refers to a point along the path of an element. They can be given as either a `<number>` for an absolute distance along the path, or a `<ratio>` for a relative distance along the path.

Path anchors also specify three anchors "start", "mid" and "end".

```example-vertical
line((0,0), (10, 1), name: "line")

set-style(content: (frame: "rect", stroke: none, fill: white, padding: .1))
content("line.start", [0%, 0, "start"], anchor: "east")
content("line.mid", [50%, "mid"])
content("line.end", [100%, "end"], anchor: "west")

content((name: "line", anchor: 75%), [75%])
content((name: "line", anchor: 50pt), [50pt])
```


= Draw Function Reference

== Canvas

#doc-style.parse-show-module("/src/canvas.typ")

== Styling <styling>
You can style draw elements by passing the relevant named arguments to their draw functions. All elements that draw something have stroke and fill styling unless said otherwise.

#doc-style.show-parameter-block("fill", ("color", "none"), default: none, [How to fill the drawn element.])
#doc-style.show-parameter-block("stroke", ("none", "auto", "length", "color", "dictionary", "stroke"), default: black + 1pt, [How to stroke the border or the path of the draw element. See Typst's line documentation for more details: https://typst.app/docs/reference/visualize/line/#parameters-stroke])

```example
// Draws a red circle with a blue border
circle((0, 0), fill: red, stroke: blue)
// Draws a green line
line((0, 0), (1, 1), stroke: green)
```

Instead of having to specify the same styling for each time you want to draw an element, you can use the `set-style()` function to change the style for all elements after it. You can still pass styling to a draw function to override what has been set with `set-style()`. You can also use the `fill()` and `stroke()` functions as a shorthand to set the fill and stroke respectively.

```example
// Draws an empty square with a black border
rect((-1, -1), (1, 1))

// Sets the global style to have a fill of red and a stroke of blue
set-style(stroke: blue, fill: red)
circle((0,0))

// Draws a green line despite the global stroke is blue
line((), (1,1), stroke: green)
```

When using a dictionary for a style, it is important to note that they update each other instead of overriding the entire option like a non-dictionary value would do. For example, if the stroke is set to `(paint: red, thickness: 5pt)` and you pass `(paint: blue)`, the stroke would become `(paint: blue, thickness: 5pt)`.

```example
// Sets the stroke to red with a thickness of 5pt
set-style(stroke: (paint: red, thickness: 5pt))
// Draws a line with the global stroke
line((0,0), (1,0))
// Draws a blue line with a thickness of 5pt because dictionaries update the style
line((0,0), (1,1), stroke: (paint: blue))
// Draws a yellow line with a thickness of 1pt because other values override the style
line((0,0), (0,1), stroke: yellow)
```

You can also specify styling for each type of element. Note that dictionary values will still update with its global value, the full hierarchy is `function > element type > global`. When the value of a style is `auto`, it will become exactly its parent style.

```example
set-style(
  // Global fill and stroke
  fill: green,
  stroke: (thickness: 5pt),
  // Stroke and fill for only rectangles
  rect: (stroke: (dash: "dashed"), fill: blue),
)
rect((0,0), (1,1))
circle((0.5, -1.5))
rect((0,-3), (1, -4), stroke: (thickness: 1pt))
```

```example
// Its a nice drawing okay
set-style(
  rect: (
    fill: red,
    stroke: none
  ),
  line: (
    fill: blue,
    stroke: (dash: "dashed")
  ),
)
rect((0,0), (1,1))
line((0, -1.5), (0.5, -0.5), (1, -1.5), close: true)
circle((0.5, -2.5), radius: 0.5, fill: green)
```

=== Marks <styling-mark>
Marks are arrow tips that can be added to the end of path based elements that support the `mark` style key, or can be directly drawn by using the `mark` draw function. Marks are specified by giving there names as strings and have several options to customise them. You can give an array of names to have multiple marks in a row, dictionaries can also be used in the array for per mark styling.

#figure(table(
  columns: 3,
  [*Name*], [*Shorthand*], [*Shape*],
  ..(for (name, item) in cetz.mark-shapes.marks {
    let name-to-mnemonic = (:)
    for (name, item) in cetz.mark-shapes.mnemonics {
      let list = name-to-mnemonic.at(item.at(0), default: ())
      list += (raw(name) + if item.at(1) { " (reversed)" },)
      name-to-mnemonic.insert(item.at(0), list)
    }
    (
      raw(name),
      name-to-mnemonic.at(name, default: ([],)).join([, ]),
      cetz.canvas(cetz.draw.line((), (1, 0), mark: (end: name)))
    )
  })
), caption: [Mark symbols])

```example
let c = ((rel: (0, -1)), (rel: (2, 0), update: false)) // Coordinates to draw the line, it is not necessary to understand this for this example.
// No marks
line((), (rel: (1, 0), update: false))
// Draws a triangle mark at both ends of the line.
set-style(mark: (symbol: ">"))
line(..c)
// Overrides the end mark to be a diamond but the start is still a triangle.
set-style(mark: (end: "<>"))
line(..c)
// Draws two triangle marks at both ends but the first mark of end is still a diamond.
set-style(mark: (symbol: (">", ">")))
line(..c)
// Sets the stroke of first mark in the sequence to red but the end mark overrides it to be blue.
set-style(mark: (symbol: ((symbol: ">", stroke: red), ">"), end: (stroke: blue)))
line(..c)
```

#doc-style.show-parameter-block("symbol", ("none", "string", "array", "dictionary"), [This option sets the mark to draw when using the `mark` draw function, or applies styling to both mark ends of path based elements. The mark's name or shorthand can be given, multiple marks can be drawn by passing an array of names or shorthands. When `none` no marks will be drawn. A style `dictionary` can be given instead of a `string` to override styling for that particular mark, just make sure to still give the mark name using the `symbol` key otherwise nothing will be drawn!. ])
#doc-style.show-parameter-block("start", ("none", "string", "array", "dictionary"), [This option sets the mark to draw at the start of a path based element. It will override all options of the `symbol` key and will not effect marks drawn using the `mark` draw function.])
#doc-style.show-parameter-block("end", ("none", "string", "array", "dictionary"), [This option sets the mark to draw at the end of a path based element. It will override all options of the `symbol` key and will not effect marks drawn using the `mark` draw function.])

#doc-style.show-parameter-block("length", "number", [The size of the mark in the direction it is pointing.], default: 0.2cm)
#doc-style.show-parameter-block("width", "number", [The size of the mark along the normal of its direction.], default: 0.15cm)
#doc-style.show-parameter-block("inset", "number", [It specifies a distance by which something inside the arrow tip is set inwards; for the Stealth arrow tip it is the distance by which the back angle is moved inwards.], default: 0.05cm)
#doc-style.show-parameter-block("scale", "float", [A factor that is applied to the mark's length, width and inset.], default: 1)
#doc-style.show-parameter-block("sep", "number", [The distance between multiple marks along their path.], default: 0.1cm)
#doc-style.show-parameter-block("flex", "boolean", [Only applicable when marks are used on curves such as bezier and hobby. If true, the mark will point along the secant of the curve. If false, the tangent at the marks tip is used.], default: true)
#doc-style.show-parameter-block("position-samples", "integer", [Only applicable when marks are used on curves such as bezier and hobby. The maximum number of samples to use for calculating curve positions. A higher number gives better results but may slow down compilation.], default: 30)

#doc-style.show-parameter-block("pos", ("number", "ratio"), [Overrides the mark's position along a path. A number will move it an absolute distance, while a ratio will be a distance relative to the length of the path. Note that this may be removed in the future in preference of a different method.])

#doc-style.show-parameter-block("offset", ("number", "ratio"), [Like `pos` but it moves the position of the mark instead of overriding it.])

#doc-style.show-parameter-block("slant", "ratio", [How much to slant the mark relative to the axis of the arrow. 0% means no slant 100% slants at 45 degrees], default: 0%)
#doc-style.show-parameter-block("harpoon", "boolean", [When true only the top half of the mark is drawn.], default: false)
#doc-style.show-parameter-block("flip", "boolean", [When true the mark is flipped along its axis.], default: false)
#doc-style.show-parameter-block("reverse", "boolean", [Reverses the direction of the mark.], default: false)
#doc-style.show-parameter-block("xy-up", "vector", [The direction which is "up" for use when drawing 2D marks.], default: (0, 0, 1))
#doc-style.show-parameter-block("z-up", "vector", [The direction which is "up" for use when drawing 3D marks.], default: (0, 1, 0))

#doc-style.show-parameter-block("shorten-to", ("integer", "auto", "none"), [Which mark to shorten the path to when multiple marks are given. `auto` will shorten to the last mark, `none` will shorten to the first mark (effectively disabling path shortening). An integer can be given to select the mark's index.])

#doc-style.show-parameter-block("transform-shape", "bool", [When false marks will not be streched/affected by the current transformation, marks will be placed after the path is transformed.], default: true)


#pagebreak()
== Shapes
#doc-style.parse-show-module("/src/draw/shapes.typ")

#pagebreak()
== Grouping
#doc-style.parse-show-module("/src/draw/grouping.typ")

#pagebreak()
== Clipping
#doc-style.parse-show-module("/src/draw/clipping.typ")

#pagebreak()
== Transformations
All transformation functions push a transformation matrix onto the current transform stack. To apply transformations scoped use a `group(...)` object.

Transformation matrices get multiplied in the following order:
$ M_"world" = M_"world" dot M_"local" $

#doc-style.parse-show-module("/src/draw/transformations.typ")

== Projection

#doc-style.parse-show-module("/src/draw/projection.typ")

= Coordinate Systems <coordinate-systems>
A _coordinate_ is a position on the canvas on which the picture is drawn. They take the form of dictionaries and the following sub-sections define the key value pairs for each system. Some systems have a more implicit form as an array of values and `CeTZ` attempts to infer the system based on the element types.

== XYZ <coordinate-xyz>
Defines a point `x` units right, `y` units upward, and `z` units away.
#doc-style.show-parameter-block("x", "number", default: 0, [The number of units in the `x` direction.])
#doc-style.show-parameter-block("y", "number", default: 0, [The number of units in the `y` direction.])
#doc-style.show-parameter-block("z", "number", default: 0, [The number of units in the `z` direction.])

The implicit form can be given as an array of two or three `<number>`s, as in `(x,y)` and `(x,y,z)`.

```example
line((0,0), (x: 1))
line((0,0), (y: 1))
line((0,0), (z: 1))

// Implicit form
line((0, -2), (1, -2))
line((0, -2), (0, -1, 0))
line((0, -2), (0, -2, 1))
```

== Previous <previous>
Use this to reference the position of the previous coordinate passed to a draw function. This will never reference the position of a coordinate used in to define another coordinate. It takes the form of an empty array `()`. The previous position initially will be `(0, 0, 0)`.

```example
line((0,0), (1, 1))

// Draws a circle at (1,1)
circle(())
```

== Relative <coordinate-relative>
Places the given coordinate relative to the previous coordinate. Or in other words, for the given coordinate, the previous coordinate will be used as the origin. Another coordinate can be given to act as the previous coordinate instead.

#doc-style.show-parameter-block("rel", "coordinate", "The coordinate to be place relative to the previous coordinate.", show-default: false)
#doc-style.show-parameter-block("update", "boolean", default: true, "When false the previous position will not be updated.")
#doc-style.show-parameter-block("to", "coordinate", default: (), "The coordinate to treat as the previous coordinate.")

In the example below, the red circle is placed one unit below the blue circle. If the blue circle was to be moved to a different position, the red circle will move with the blue circle to stay one unit below.

```example
circle((0, 0), stroke: blue)
circle((rel: (0, -1)), stroke: red)
```

== Polar
Defines a point that is `radius` distance away from the origin at the given `angle`.

#doc-style.show-parameter-block("angle", "angle", [The angle of the coordinate. An angle of `0deg` is to the right, a degree of `90deg` is upward. See https://typst.app/docs/reference/layout/angle/ for details.], show-default: false)
#doc-style.show-parameter-block("radius", ("number", "tuple<number>"), [The distance from the origin. An array can be given, in the form `(x, y)` to define the `x` and `y` radii of an ellipse instead of a circle.], show-default: false)

```example
line((0,0), (angle: 30deg, radius: 1cm))
```

The implicit form is an array of the angle then the radius `(angle, radius)` or `(angle, (x, y))`. 

```example
line((0,0), (30deg, 1), (60deg, 1), 
     (90deg, 1), (120deg, 1), (150deg, 1), (180deg, 1))
```

== Barycentric
In the barycentric coordinate system a point is expressed as the linear combination of multiple vectors. The idea is that you specify vectors $v_1$, $v_2$ ..., $v_n$ and numbers $alpha_1$, $alpha_2$, ..., $alpha_n$. Then the barycentric coordinate specified by these vectors and numbers is $ (alpha_1 v_1 + alpha_2 v_1 + dots.c + alpha_n v_n)/(alpha_1 + alpha_2 + dots.c + alpha_n) $

#doc-style.show-parameter-block("bary", "dictionary", [A dictionary where the key is a named element and the value is a `<float>`. The `center` anchor of the named element is used as $v$ and the value is used as $a$.], show-default: false)

```example
circle((90deg, 3), radius: 0, name: "content")
circle((210deg, 3), radius: 0, name: "structure")
circle((-30deg, 3), radius: 0, name: "form")

for (c, a) in (
  ("content", "south"),
  ("structure", "north"),
  ("form", "north")
) {
  content(c, align(center, c + [\ oriented]), padding: .1, anchor: a)
}

stroke(gray + 1.2pt)
line("content", "structure", "form", close: true)

for (c, s, f, cont) in (
  (0.5, 0.1, 1, "PostScript"),
  (1, 0, 0.4, "DVI"),
  (0.5, 0.5, 1, "PDF"),
  (0, 0.25, 1, "CSS"),
  (0.5, 1, 0, "XML"),
  (0.5, 1, 0.4, "HTML"),
  (1, 0.2, 0.8, "LaTeX"),
  (1, 0.6, 0.8, "TeX"),
  (0.8, 0.8, 1, "Word"),
  (1, 0.05, 0.05, "ASCII")
) {
  content((bary: (content: c, structure: s, form: f)),
    cont, fill: rgb(50, 50, 255, 100), stroke: none, frame: "circle")
}
```

== Anchor <coordinate-anchor>
Defines a point relative to a named element using anchors, see @anchors.

#doc-style.show-parameter-block("name", "string", [The name of the element that you wish to use to specify a coordinate.], show-default: false)
#doc-style.show-parameter-block("anchor", ("number", "angle", "string", "ratio", "none"), [The anchor of the element. Strings are named anchors, angles are border anchors and numbers and ratios are path anchors. If not given, the default anchor will be used, on most elements this is `center` but it can be different.])

```example
circle((0,0), name: "circle")
// Anchor at 30 degree
content((name: "circle", anchor: 30deg), box(fill: white, $ 30 degree $))
// Anchor at 30% of the path length
content((name: "circle", anchor: 30%), box(fill: white, $ 30 % $))
// Anchor at 3.14 of the path
content((name: "circle", anchor: 3.14), box(fill: white, $ p = 3.14 $))
```
Note, that not all elements provide border or path anchors!

You can also use implicit syntax of a dot separated string in the form `"name.anchor"` for all anchors. Because named elements in groups act as anchors, you can also access them through this syntax.

```example
group(name: "group", {
  line((0,0), (3,2), name: "line")
  circle("line.end", name: "circle")
  rect("line.start", "circle.east")

  circle("circle.30deg", radius: 0.1, fill: red)
})

circle("group.circle.-1", radius: 0.1, fill: blue)
```





== Tangent
This system allows you to compute the point that lies tangent to a shape. In detail, consider an element and a point. Now draw a straight line from the point so that it "touches" the element (more formally, so that it is _tangent_ to this element). The point where the line touches the shape is the point referred to by this coordinate system.

#doc-style.show-parameter-block("element", "string", [The name of the element on whose border the tangent should lie.], show-default: false)
#doc-style.show-parameter-block(show-default: false, "point", "coordinate", [The point through which the tangent should go.])
#doc-style.show-parameter-block(show-default: false, "solution", "integer", [Which solution should be used if there are more than one.])

A special algorithm is needed in order to compute the tangent for a given shape. Currently it does this by assuming the distance between the center and top anchor (See @anchors) is the radius of a circle. 

```example
grid((0,0), (3,2), help-lines: true)

circle((3,2), name: "a", radius: 2pt)
circle((1,1), name: "c", radius: 0.75)
content("c", $ c $, anchor: "north-east", padding: .1)

stroke(red)
line("a", (element: "c", point: "a", solution: 1),
     "c", (element: "c", point: "a", solution: 2),
     close: true)
```

== Perpendicular
Can be used to find the intersection of a vertical line going through a point $p$ and a horizontal line going through some other point $q$.

#doc-style.show-parameter-block(show-default: false, "horizontal", "coordinate", [The coordinate through which the horizontal line passes.])
#doc-style.show-parameter-block(show-default: false, "vertical", "coordinate", [The coordinate through which the vertical line passes.])

You can use the implicit syntax of `(horizontal, "-|", vertical)` or `(vertical, "|-", horizontal)`

```example
set-style(content: (padding: .05))
content((30deg, 1), $ p_1 $, name: "p1")
content((75deg, 1), $ p_2 $, name: "p2")

line((-0.2, 0), (1.2, 0), name: "xline")
content("xline.end", $ q_1 $, anchor: "west")
line((2, -0.2), (2, 1.2), name: "yline")
content("yline.end", $ q_2 $, anchor: "south")

line("p1.south-east", (horizontal: (), vertical: "xline.end"))
line("p2.south-east", ((), "|-", "xline.end")) // Short form
line("p1.south-east", (vertical: (), horizontal: "yline.end"))
line("p2.south-east", ((), "-|", "yline.end")) // Short form
```

== Interpolation <coordinate-lerp>
Use this to linearly interpolate between two coordinates `a` and `b` with a given distance `number`. If `number` is a `<number>` the position will be at the absolute distance away from `a` towards `b`, a `<ratio>` can be given instead to be the relative distance between `a` and `b`. 
An angle can also be given for the general meaning: "First consider the line from `a` to `b`. Then rotate this line by `angle` around point `a`. Then the two endpoints of this line will be `a` and some point `c`. Use this point `c` for the subsequent computation."

#doc-style.show-parameter-block(show-default: false, "a", "coordinate", [The coordinate to interpolate from.])
#doc-style.show-parameter-block(show-default: false, "b", "coordinate", [The coordinate to interpolate to.])
#doc-style.show-parameter-block(show-default: false, "number", ("ratio", "number"), [
  The distance between `a` and `b`. A ratio will be the relative distance between the two points, a number will be the absolute distance between the two points.
])
#doc-style.show-parameter-block("angle", "angle", [Angle between $arrow("AB")$ and $arrow("AP")$, where $P$ is the resulting coordinate. This can be used to get the _normal_ for a tangent between two points.], default: 0deg)

Can be used implicitly as an array in the form `(a, number, b)` or `(a, number, angle, b)`.

```example
grid((0,0), (3,3), help-lines: true)

line((0,0), (2,2), name: "a")
for i in (0%, 20%, 50%, 80%, 100%, 125%) { /* Relative distance */
  content(("a.start", i, "a.end"),
          box(fill: white, inset: 1pt, [#i]))
}

line((1,0), (3,2), name: "b")
for i in (0, 0.5, 1, 2) { /* Absolute distance */
  content(("b.start", i, "b.end"),
          box(fill: white, inset: 1pt, text(red, [#i])))
}
```

```example
grid((0,0), (3,3), help-lines: true)
line((1,0), (3,2))
line((1,0), ((1, 0), 1, 10deg, (3,2)))
fill(red)
stroke(none)
circle(((1, 0), 50%, 10deg, (3, 2)), radius: 2pt)
```

```example
grid((0,0), (4,4), help-lines: true)

fill(black)
stroke(none)
let n = 16
for i in range(0, n+1) {
  circle(((2,2), i / 8, i * 22.5deg, (3,2)), radius: 2pt)
}
```

You can even chain them together!

```example
grid((0,0), (3, 2), help-lines: true)
line((0,0), (3,2))
stroke(red)
line(((0,0), 0.3, (3,2)), (3,0))
fill(red)
stroke(none)
circle(
  ( // a
    (((0, 0), .3, (3, 2))),
    0.7,
    (3,0)
  ),
  radius: 2pt
)
```

```example
grid((0,0), (3, 2), help-lines: true)
line((1,0), (3,2))
for (l, c) in ((0cm, "0cm"), (1cm, "1cm"), (15mm, "15mm")) {
  content(((1,0), l, (3,2)), box(fill: white, $ #c $))
}
```

Interpolation coordinates can be used to get the _normal_ on a tangent:
```example
let (a, b) = ((0,0), (3,2))
line(a, b)
// Get normal for tangent from a to () with distance .5, at a
circle(a, radius: .1, fill: black)
line((a, .7, b), (a: (), b: a, number: .5, angle: 90deg), stroke: red)
```

== Function
An array where the first element is a function and the rest are coordinates will cause the function to be called with the resolved coordinates. The resolved coordinates have the same format as the implicit form of the 3-D XYZ coordinate system, @coordinate-xyz.

The example below shows how to use this system to create an offset from an anchor, however this could easily be replaced with a relative coordinate with the `to` argument set, @coordinate-relative.

```example
circle((0, 0), name: "c")
fill(red)
circle((v => cetz.vector.add(v, (0, -1)), "c.west"), radius: 0.3)
```

#pagebreak()

= Libraries

== Tree
The tree library allows the drawing diagrams with simple tree layout algorithms

#doc-style.parse-show-module("/src/lib/tree.typ")

== Plot

The library `plot` of CeTZ allows plotting data.

=== Types

Types commonly used by function of the `plot` library:
- #doc-style.show-type("domain"): Tuple representing a functions domain as closed interval.
  Example domains are: `(0, 1)` for $[0, 1]$ or
  `(-calc.pi, calc.pi)` for $[-pi, pi]$.
- #doc-style.show-type("axes"): Tuple of axis names. Plotting functions taking an `axes` tuple
  will use those axes as their `x` and `y` axis for plotting.
  To rotate a plot, you can simply swap its axes, for example `("y", "x")`.
- #doc-style.show-type("mark"): Plots feature their own set of marks. The following mark symbols are
  available:
  ```example-vertical
  let marks = ("+", "x", "-", "|", "o", "square", "triangle")
  cetz.plot.plot(size: (14, 1), x-min: 0, x-max: marks.len() + 1,
    x-ticks: marks.enumerate().map(((i, s)) => (i+1, raw(s))),
    x-tick-step: none, y-tick-step: none,
    x-label: none, y-label: none,
    {
    for (i, s) in marks.enumerate() {
      cetz.plot.add(((i + 1, 0),), mark: s, mark-style: (stroke: blue, fill: white), mark-size: .5)
    }
  })
  ```

#doc-style.parse-show-module("/src/lib/plot.typ")

=== Legends <plot-legends>
A legend for a plot will be drawn if at least one set of data with a label that is not `none` is given.
The following anchors are available when placing a legend on a plot:
  - `legend.north`
  - `legend.south`
  - `legend.east`
  - `legend.west`
  - `legend.north-east`
  - `legend.north-west`
  - `legend.south-east`
  - `legend.south-west`
  - `legend.inner-north`
  - `legend.inner-south`
  - `legend.inner-east`
  - `legend.inner-west`
  - `legend.inner-north-east`
  - `legend.inner-north-west`
  - `legend.inner-south-east`
  - `legend.inner-south-west`
```example
import cetz.plot
plot.plot(
  size: (3,2),
  x-tick-step: none,
  y-tick-step: none,
  legend: "legend.north", {
  plot.add(
    ((-1, -1), (1, 1)),
    mark: "o",
    label: $ f(x) $
  )
})
```

==== Styling
*Root:* `legend`
===== Keys
#doc-style.show-parameter-block("orientation", ("direction"), default: ttb, [
  The direction the legend items get laid out to.
])
#doc-style.show-parameter-block("default-position", ("string", "coordinate"), default: "legend.north-east", [
  The default position the legend gets placed at.
])
#doc-style.show-parameter-block("layer", ("number"), default: 1, [
  The layer index the legend gets drawn at, see on-layer.
])
#doc-style.show-parameter-block("fill", ("paint"), default: rgb(255,255,255,200), [
  The legends frame background color.
])
#doc-style.show-parameter-block("stroke", ("stroke"), default: black, [
  The legends frame stroke style.
])
#doc-style.show-parameter-block("padding", ("float"), default: .1, [
  The legends frame padding, that is the distance added between its items and its frame.
])
#doc-style.show-parameter-block("offset", ("tuple"), default: (0,0), [
  An offset tuple (x and y coordinates) to add to the legends position.
])
#doc-style.show-parameter-block("spacing", ("number"), default: .1, [
  The spacing between the legend position and its frame.
])
#doc-style.show-parameter-block("item.spacing", ("number"), default: .05, [
  The spacing between two legend items in canvas units.
])
#doc-style.show-parameter-block("item.preview.width", ("number"), default: .75, [
  The width of a legend items preview picture, a small preview of the graph the legend item belongs to.
])
#doc-style.show-parameter-block("item.preview.height", ("number"), default: .3, [
  The height of a legend items preview picture.
])
#doc-style.show-parameter-block("item.preview.margin", ("number"), default: .1, [
  Margin between the preview picture and the item label.
])


#doc-style.parse-show-module("/src/lib/plot/line.typ")
#doc-style.parse-show-module("/src/lib/plot/contour.typ")
#doc-style.parse-show-module("/src/lib/plot/boxwhisker.typ")
#doc-style.parse-show-module("/src/lib/plot/bar.typ")
#doc-style.parse-show-module("/src/lib/plot/annotation.typ")
#doc-style.parse-show-module("/src/lib/plot/sample.typ")

=== Examples

```example
import cetz.plot
plot.plot(size: (3,2), x-tick-step: calc.pi, y-tick-step: 1,
                       x-format: v => $#{v/calc.pi} pi$, {
  plot.add(domain: (0, 4*calc.pi), calc.sin,
    samples: 15, line: "hvh", style: (mark: (stroke: blue)))
  plot.add(domain: (0, 4*calc.pi), calc.sin)
})
```

```example
import cetz.plot
import cetz.palette

// Let ticks point outwards by giving them negative length
set-style(axes: (tick: (length: -.2, minor-length: -.1)))

// Plot something
plot.plot(size: (3,3), x-tick-step: 1, x-minor-tick-step: .2,
                       y-tick-step: 1, y-minor-tick-step: .2, {
  let z(x, y) = {
    (1 - x/2 + calc.pow(x,5) + calc.pow(y,3)) * calc.exp(-(x*x) - (y*y))
  }
  plot.add-contour(x-domain: (-2, 3), y-domain: (-3, 3),
                   z, z: (.1, .4, .7), fill: true)
})
```

=== Styling <plot.style>

The following style keys can be used (in addition to the standard keys)
to style plot axes. Individual axes can be styled differently by
using their axis name as key below the `axes` root.

```typc
set-style(axes: ( /* Style for all axes */ ))
set-style(axes: (bottom: ( /* Style axis "bottom" */)))
```

Axis names to be used for styling:
- School-Book and Left style:
  - `x`: X-Axis
  - `y`: Y-Axis
- Scientific style:
  - `left`: Y-Axis
  - `right`: Y2-Axis
  - `bottom`: X-Axis
  - `top`: X2-Axis

#doc-style.parse-show-module("/src/lib/axes.typ")

==== Default `scientific` Style
#raw(repr(axes.default-style-scientific))

==== Default `school-book` Style
#raw(repr(axes.default-style-schoolbook))

== Chart

With the `chart` library it is easy to draw charts.

#doc-style.parse-show-module("/src/lib/chart/barchart.typ")
#doc-style.parse-show-module("/src/lib/chart/columnchart.typ")
#doc-style.parse-show-module("/src/lib/chart/piechart.typ")
#doc-style.parse-show-module("/src/lib/chart/boxwhisker.typ")

=== Examples -- Bar Chart <barchart-examples>
```example-vertical
import cetz.chart
// Left - Basic
let data = (("A", 10), ("B", 20), ("C", 13))
group(name: "a", {
  chart.barchart(size: (4, 3), data)
})
// Center - Clustered
let data = (("A", 10, 12, 22), ("B", 20, 1, 7), ("C", 13, 8, 9))
group(name: "b", anchor: "south-west", {
  anchor("default", "a.south-east")
  chart.barchart(size: (4, 3), mode: "clustered", value-key: (1,2,3), data)
})
// Right - Stacked
let data = (("A", 10, 12, 22), ("B", 20, 1, 7), ("C", 13, 8, 9))
group(name: "c", anchor: "south-west", {
  anchor("default", "b.south-east")
  chart.barchart(size: (4, 3), mode: "stacked", value-key: (1,2,3), data)
})
```

=== Examples -- Column Chart <columnchart-examples>

==== Basic, Clustered and Stacked
```example-vertical
import cetz.chart
// Left - Basic
let data = (("A", 10), ("B", 20), ("C", 13))
group(name: "a", {
  chart.columnchart(size: (4, 3), data)
})
// Center - Clustered
let data = (("A", 10, 12, 22), ("B", 20, 1, 7), ("C", 13, 8, 9))
group(name: "b", anchor: "south-west", {
  anchor("default", "a.south-east")
  chart.columnchart(size: (4, 3), mode: "clustered", value-key: (1,2,3), data)
})
// Right - Stacked
let data = (("A", 10, 12, 22), ("B", 20, 1, 7), ("C", 13, 8, 9))
group(name: "c", anchor: "south-west", {
  anchor("default", "b.south-east")
  chart.columnchart(size: (4, 3), mode: "stacked", value-key: (1,2,3), data)
})
```

=== Styling

Charts share their axis system with plots and therefore can be
styled the same way, see @plot.style.

==== Default `barchart` Style
#raw(repr(chart.barchart-default-style))

==== Default `columnchart` Style
#raw(repr(chart.columnchart-default-style))

==== Default `boxwhisker` Style
#raw(repr(chart.boxwhisker-default-style))

==== Default `piechart` Style
#raw(repr(chart.piechart-default-style))

== Palette <palette>

A palette is a function of the form `index => style` that takes an
index, that can be any integer and returns a canvas style dictionary.
If passed the string `"len"` it must return the length of its unique
styles. An example use for palette functions is the `plot` library, which
can use palettes to apply different styles per plot.

The palette library provides some predefined palettes.

#doc-style.parse-show-module("/src/lib/palette.typ")

#let show-palette(p) = box({
  let p = p.with(stroke: true)
  canvas(length: 1em, {
    import cetz.draw: *
    for i in range(0, p("len")) {
      if calc.rem(i, 10) == 0 { move-to((rel: (0, -.5))) }
      rect((), (rel: (1,.5)), name: "r", ..p(i))
      move-to("r.south-east")
    }
  })
})

=== List of predefined palettes
#columns(2, [
- `gray` #show-palette(palette.gray)
- `red` #show-palette(palette.red)
- `orange` #show-palette(palette.orange)
- `light-green` #show-palette(palette.light-green)
- `dark-green` #show-palette(palette.dark-green)
- `turquoise` #show-palette(palette.turquoise)
- `cyan` #show-palette(palette.cyan)
- `blue` #show-palette(palette.blue)
- `indigo` #show-palette(palette.indigo)
- `purple` #show-palette(palette.purple)
- `magenta` #show-palette(palette.magenta)
- `pink` #show-palette(palette.pink)
- `rainbow` #show-palette(palette.rainbow)
- `tango-light` #show-palette(palette.tango-light)
- `tango` #show-palette(palette.tango)
- `tango-dark` #show-palette(palette.tango-dark)
])

== Angle <angle>

The `angle` function of the angle module allows drawing angles with an optional label.

#doc-style.parse-show-module("/src/lib/angle.typ")

==== Default `angle` Style
#raw(repr(angle.default-style))

== Decorations <decorations>

Various pre-made shapes and path modifications.

=== Braces
#doc-style.parse-show-module("/src/lib/decorations/brace.typ")

=== Path Decorations
Path decorations are elements that accept a path as input and generate
one or more shapes that follow that path.

All path decoration functions support the following style keys:
#def-arg("start", [`<ratio>` or `<length>`], default: 0%,
  [Absolute or relative start of the decoration on the path.])
#def-arg("stop", [`<ratio>` or `<length>`], default: 100%,
  [Absolute or relative end of the decoration on the path.])
#def-arg("rest", [`<string>`], default: "LINE",
  [If set to `"LINE"`, generate lines between the paths start/end and
   the decorations start/end if the path is _not closed_.])
#def-arg("width", [`<number>`], default: 1,
  [Width or thickness of the decoration.])
#def-arg("segments", [`<int>`], default: 10,
  [Number of repetitions/phases to generate.
   This key is ignored if `segment-length` is set != `none`.])
#def-arg("segment-length", [`none` or `<number>`], default: none,
  [Length of one repetition/phase of the decoration.])
#def-arg("align", [`"START"`, `"MID"`, `"END"`], default: "START",
  [Alignment of the decoration on the path _if `segment-length` is set_ and
   the decoration does not fill up the full range between start and stop.])

#doc-style.parse-show-module("/src/lib/decorations/path.typ")

==== Styling

===== Default `brace` Style
#decorations.brace-default-style

===== Default `flat-brace` Style
#decorations.flat-brace-default-style

= Advanced Functions

== Coordinate

#doc-style.parse-show-module("/src/coordinate.typ")

== Styles

#doc-style.parse-show-module("/src/styles.typ")


=== Default Style <default-style>

This is a dump of the style dictionary every canvas gets initialized with.
It contains all supported keys for all elements.

#[
  #set text(size: 8pt)
  #columns(raw(repr(styles.default), lang: "typc"))
]

= Creating Custom Elements <custom-elements>

The simplest way to create custom, reusable elements is to return them
as a group. In this example we will implement a function `my-star(center)`
that draws a star with `n` corners and a style specified inner and outer
radius.

```example
let my-star(center, name: none, ..style) = {
  group(name: name, ctx => {
    // Define a default style
    let def-style = (n: 5, inner-radius: .5, radius: 1)

    // Resolve the current style ("star")
    let style = cetz.styles.resolve(ctx.style, merge: style.named(),
      base: def-style, root: "star")

    // Compute the corner coordinates
    let corners = range(0, style.n * 2).map(i => {
      let a = 90deg + i * 360deg / (style.n * 2)
      let r = if calc.rem(i, 2) == 0 { style.radius } else { style.inner-radius }

      // Output a center relative coordinate
      (rel: (calc.cos(a) * r, calc.sin(a) * r, 0), to: center)
    })

    line(..corners, ..style, close: true)
  })
}

// Call the element
my-star((0,0))
my-star((0,3), n: 10)

set-style(star: (fill: yellow)) // set-style works, too!
my-star((0,6), inner-radius: .3)
```


= Internals
== Context

The state of the canvas is encoded in its context dictionary. Elements or other
draw calls may return a modified context to the canvas to change its
state, e.g. modifying the transformating matrix, adding a group or setting a style.

The context can be manually retrieved and modified using the `get-ctx` and `set-ctx`
functions.

== Elements

Each CeTZ element (`line`, `bezier`, `circle`, ...) returns an array of
functions for drawing to the canvas. Such function takes the canvas'
context and must return an dictionary of the following keys:
- `ctx` (required): The (modified) canvas context object
- `drawables`: List of drawables to render to the canvas
- `anchors`: A function of the form `(<anchor-identifier>) => <vector>`
- `name`: The elements name

An element that does only modify the context could be implemented like the
following:
```example
let my-element() = {
  (ctx => {
    // Do something with ctx ...
    (ctx: ctx)
  },)
}

// Call the element
my-element()
```

For drawing, elements must not use Typst native drawing functions, but
output CeTZ paths. The `drawable` module provides functions for path
creation (`path(..)`), the `path-util` module provides utilities for path
segment creation. For demonstration, we will recreate the custmom element
`my-star` from @custom-elements:
```example
import cetz.drawable: path
import cetz.vector

let my-star(center, ..style) = {
  (ctx => {
    // Define a default style
    let def-style = (n: 5, inner-radius: .5, radius: 1, stroke: auto, fill: auto)

    // Resolve center to a vector
    let (ctx, center) = cetz.coordinate.resolve(ctx, center)

    // Resolve the current style ("star")
    let style = cetz.styles.resolve(ctx.style, merge: style.named(),
      base: def-style, root: "star")

    // Compute the corner coordinates
    let corners = range(0, style.n * 2).map(i => {
      let a = 90deg + i * 360deg / (style.n * 2)
      let r = if calc.rem(i, 2) == 0 { style.radius } else { style.inner-radius }
      vector.add(center, (calc.cos(a) * r, calc.sin(a) * r, 0))
    })

    // Build a path through all three coordinates
    let path = cetz.drawable.path((cetz.path-util.line-segment(corners),),
      stroke: style.stroke, fill: style.fill, close: true)

    (ctx: ctx,
     drawables: cetz.drawable.apply-transform(ctx.transform, path),
    )
  },)
}

// Call the element
my-star((0,0))
my-star((0,3), n: 10)
my-star((0,6), inner-radius: .3, fill: yellow)
```

Using custom elements instead of groups (as in @custom-elements) makes sense
when doing advanced computations or even applying modifications to passed in
elements.

/*
= Vector, Matrix and Complex Types

#doc-style.parse-show-module("/src/vector.typ")
#doc-style.parse-show-module("/src/matrix.typ")
#doc-style.parse-show-module("/src/complex.typ")
*/
