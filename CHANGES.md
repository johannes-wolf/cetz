# 0.3.0

CeTZ 0.3.0 requires Typst 0.11.0

## Clipping
- CeTZ now supports boolean operations on paths.

# 0.2.2

## Anchors
- Support for accessing anchors within groups.
- Support string shorthand for path and border anchors.

## 3D
- CeTZ gained some helper functions for drawing 3D figures in orthographic projection: `ortho`, `on-xy`, `on-xz` and `on-yz`.

## Plot
- New axes style key `tick.label.show` to force showing tick labels on mirrored axes.
- Axes tick format can now be set to `none` or content, without defaulting to floating point ticks.

## Fixes
- Fixed piechart styles when using `clockwise: true`.
- Fixed `decorations.flat-brace` vertical positioning
- Fixed drawing of mirrored plot axis ticks.
- Fixed plots with only annotions.
- Added matrix rounding to fix rounding errors when using lots of transforms

# 0.2.1

## Anchors
- Changing a group's "center" anchor now effects how border anchors are calculated.
- Allowed changing of the default anchor for groups.
- Re-added "a", "b", and "c" anchors for `circle-through`
- Open arcs are no longer modified for anchors, invalid border anchors will panic.
- Grids now actually support border anchors.

## Marks
- Marks can now be placed on a path after that path got transformed. See the new `transform-shape` style key.

## Misc
- The `hide` function now support an additional `bounds:` parameter to enable canvas bounds adjustment for hidden elements
- The default transformation matrix changed

## Charts
- Default piechart rotation changed from counter-clockwise to clockwise
- Default piechart start/stop angles changed so that the first item
  starts at 90° (ccw)

## Libs
### Plot
- The default style of plots changed
- New style keys for enabling/disabling the shared zero tick for "school-book" style plots
- New style keys for specifying the layer of different plot elements (`grid-layer`, `axis-layer`, `background-layer`)
- Fixed annotation bounds calculation
- Marks insides annotations are now unaffected by the plots canvas scaling by default (see marks new post-transform style key)

# 0.2.0
CeTZ 0.2.0 requires Typst 0.10.0

## Libs
### Draw
- **BREAKING** Default anchors are now using TikZ like compass names: north, south, east, west, north-west, north-east, south-west and south-east
- **BREAKING** Element anchors have changed! See the documentation for details.
- **BREAKING** Rotation direction changed to CCW
- **BREAKING** Removed the `shadow` function
- **BREAKING** Changed the behaviour of `mark`
- **BREAKING** Changed the behaviour of `translate` by changing the transformation order, changed arguments of `scale` and `translate`
- **BREAKING** LERP coordinates now use ratio instead of float for relative interpolation.
- **BREAKING** Removed `place-marks` and `place-anchors` functions, use the new mark `pos:` attribute and path anchors `(name: <element>, anchor: <number, ratio>)` instead.
- Content padding has been improved to be configurable per side
- Groups support same padding options as content
- Overhauled marks, see manual for the new mark symbols, placement- and styling options
- Fixed and improved intersection calculation
- Fixed and improved the styling algorithm
- Catmull-Rom curves, Hobby curves and arcs now can have marks
- Line elements now use border intersection coordinates if first and/or last coordinate is an element name with a "default" anchor
- Added element `arc-through` to draw an arc through three points
- Added Hobby curves (`hobby`) in addition to catmull (thanks to @Enivex)
- Added `radius` style to `rect` for drawing rounded rects
- Added `hide` function for hiding elements
- Added distance, ratio and angle anchors to elements

### Plot
- Added `plot.add-contour(..)` for plotting contour plots
- Added `plot.add-hline(..)` and `plot.add-vline(..)` for plotting h/v lines
- Added `plot.add-between(..)` for filling the area between two line plots
- Added `plot.add-boxwhisker(..)` for displaying boxwhisker plots (thanks to @JamesxX)
- Added `fill-type` option to `plot.add(..)` for specifying a fill type (axis or shape)
- Changed default samples from 100 to 50!
- Fixed plot filling in some cases
- Axes can now be locked (equal) to keep aspect ratio
- Axes can be reversed by setting min > max
- Axis orientation can be changed, enabling rotation of plots
- Plots now support legends!

### Chart
- Added `piechart` for drawing pie- and donut charts
- Added `boxwhisker` for drawing boxwhisker charts

### Decorations
- New path decorations `zigzag`, `wave` and `coil`

# 0.1.2
CeTZ requires Typst 0.8.0.

## Draw
- New `on-layer(layer, body)` function for drawing with a given layer/z-index
- New `catmull(..)` function for drawing catmull-rom curves
- Changed default anchors of circles and arcs to anchors on the elliptical path
- Added style option to specify triangle mark angle
- Fixed rect anchors if coordinates were swapped
- Fixed bezier extrema/aabb calculation
- Fixed bug with `content` and `intersections`
- Fixed automatic mark offset for lines
- Fixed problems with style inheritance

## Libs
### Plot
- Added `sample-at: (..)` option to `plot.add(..)` for specifying extra sample points
- Added `line: <linear|spline|vh|hv|vhv>` support
- The plot lib tries to linearize data to reduce draw calls
- Fixed custom tick plot formatting
- Allow plots without data

### Decorations
- New decoration library by @RubixDev for drawing braces

# 0.1.1
## Libs
### Angle
- New `angle` library for drawing angles

### Axes
- Support tick label rotation
- Support negative tick mark direction

## Draw
- Fixed `arc` with negative delta
- Fixed division by 0 error when calculating bezier extremas
- Added `mark: (..)` support for `bezier` and `bezier-through`
- Changed `content` to allow for a second coordinate to span content between
- Added `content: (frame: "rect"|"circle")` style for drawing a frame around content
- Default triangle mark angle changed. It can now be set via the style attribute `angle`.
- Arrowheads on lines are now offset so the tip of the triangle points exactly on the
  target position

# 0.1.0
## Plot
- Added arguments `plot-style` and `mark-style` to the `plot(..)` base function
  that allow providing a base style that gets inherited by all graphs.
  Plots now default to the color pattern (blue, red, green, yellow, black) for
  stroking & filling graphs.

## Axes
- Fixed axis label alignment.

## Draw
- Fixed issue #24, assert if line has fewer than two points.
- Fixed an issue with calculating bounding boxes for some transformed paths

## Chart
- Fixed barchart bars getting labeled in reversed order

# 0.0.2
## Content
- The `content` function now supports a second coordinate as `angle`, to
  compute the rotation angle between the origin.
- Anchors of the `content` function are now properly rotated.

## Tree
- Added the `tree` module for laying out trees.

## Canvas
- Changed transformation matrix multiplication order from `Local * World to`
  World * Local.
- Added `set-viewport` function for setting up scaling and translation to draw
  insides a rectangular region.
- The function `rect` now emits rotated anchors,
  before it did not set anchors but used the bounding box.
- New function `copy-anchors` to copy anchors of an element into a group.
- Arcs are now approximated using up to 4 bezier curves instead of using
  sampling with straight lines.
- New function `intersections` that emits anchors at all child element
  intersection points.

## Chart
- Added new library `chart` for drawing charts, currently only bar- and columncharts are supported.

## Plot
- Added new library `plot` for drawing line charts (of functions), replacing `typst-plot`.
