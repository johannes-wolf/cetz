#import "/src/coordinate.typ"
#import "/src/draw.typ": *
#import "/src/styles.typ"
#import "/src/util.typ"
#import "/src/vector.typ"

#let _cetz-content = content
#let _cetz-anchor = anchor

#let cylinder-default-style = (
  head-fill: auto,
  head-radius: auto,
  content-box: (inset: 0.5em),
  stroke: (join: "round"),
  size: (4,3)
)

#let cylinder(
  pt,
  name: none,
  content: none,
  anchor: none,
  ..style,
) = {
  // validate coordinates
  let _ = coordinate.resolve-system(pt)
  group(name: name, anchor: anchor, ctx => {
    let (ctx, pt) = coordinate.resolve(ctx, pt)
    let style = styles.resolve(
      ctx.style, merge: style.named(), root: "cylinder", base: cylinder-default-style
    )
    let (width, height) = style.size
    let center-pt = vector.add(pt, (width/2, -height/2))
    // Ensure the center anchor is used by default
    translate(vector.sub(pt, center-pt))
    // `head-radius` mimics the behavior of ppt to determine sizing
    let head-radius = style.head-radius
    if head-radius == auto {
      head-radius = calc.min(width, height) / 4
    }
    if type(head-radius) == ratio {
      head-radius = (head-radius * 1em).em * height
    } else {
      head-radius = util.resolve-number(ctx, head-radius)
    }
    let bottom-left = vector.sub(pt, (0, height))
    let bottom-right = vector.add(bottom-left, (width, 0))
    let top-right = vector.add(pt, (width, 0))
    circle(
      bottom-left,
      anchor: "west",
      radius: (width/2, head-radius),
      stroke: (dash: "dashed"),
      z: 50,
    )
    merge-path(
      {
        line(pt, bottom-left)
        arc(
          bottom-left,
          start: 180deg,
          delta: 180deg,
          radius: (width/2, head-radius),
        )
        line(bottom-right, top-right)
      },
      ..style,
    )
    if style.head-fill == auto {
      style.head-fill = style.fill
    }
    circle(pt, ..style, fill: style.head-fill, anchor: "west", radius: (width/2, head-radius))
    if content != none {
      let (width, height) = (width, height).map(el => util.resolve-number(ctx, el) * ctx.length)
      let content = box(width: width, height: height, ..style.content-box, content)
      _cetz-content(pt, bottom-right, content, ..style, anchor: "west")
    }
    let mid-top = vector.add(pt, (width/2, 0))
    let mid-left = vector.add(pt, (0, -height/2))
    let anchors = (
      west: mid-left,
      east: vector.add(mid-left, (width, 0)),
      north: vector.add(mid-top, (0, head-radius)),
      south: vector.add(mid-top, (0, -height - head-radius)),
      center: center-pt,
      mid: center-pt,
      head-center: mid-top,
      head-south: vector.add(mid-top, (0, -head-radius)),
      south-west: bottom-left,
      south-east: bottom-right,
      north-west: pt,
      default: center-pt,
      north-east: top-right,
      start: pt,
      end: bottom-right,
    )
    for (name, pos) in anchors {
      _cetz-anchor(name, pos)
    }
  })
}
