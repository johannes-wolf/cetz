#import "../../draw.typ"

#let draw-mark-valid-marks = (
  "o", "square", "triangle", "*", "x", "+", "-", "|", 
)

#let draw-mark(pts, x, y, mark, mark-size, plot-size) = {

  if type(mark-size) != function {mark-size = (idx=>mark-size)}

  for (idx, pt) in pts.enumerate() {
    let (px, py, ..) = pt
    let mark-size = mark-size(idx)

    assert(mark in draw-mark-valid-marks,
      message: "Invalid marker type! Given " + mark + ", expected " +
        draw-mark-valid-marks.map(it=>"\""+it+"\"").join(", "))

    // Scale marks back to canvas scaling
    let (sx, sy) = plot-size
    sx = (x.max - x.min) / sx
    sy = (y.max - y.min) / sy
    sx *= mark-size
    sy *= mark-size

    let bl(pt) = (rel: (-sx/2, -sy/2), to: pt)
    let br(pt) = (rel: (sx/2, -sy/2), to: pt)
    let tl(pt) = (rel: (-sx/2, sy/2), to: pt)
    let tr(pt) = (rel: (sx/2, sy/2), to: pt)
    let ll(pt) = (rel: (-sx/2, 0), to: pt)
    let rr(pt) = (rel: (sx/2, 0), to: pt)
    let tt(pt) = (rel: (0, sy/2), to: pt)
    let bb(pt) = (rel: (0, -sy/2), to: pt)

    let draw-mark = (
      if mark == "o" {
        draw.circle.with(radius: (sx/2, sy/2))
      } else
      if mark == "square" {
        pt => { draw.rect(bl(pt), tr(pt)) }
      } else
      if mark == "triangle" {
        pt => { draw.line(bl(pt), br(pt), tt(pt), close: true) }
      } else
      if mark == "*" or mark == "x" {
        pt => { draw.line(bl(pt), tr(pt));
                draw.line(tl(pt), br(pt)) }
      } else
      if mark == "+" {
        pt => { draw.line(ll(pt), rr(pt));
                draw.line(tt(pt), bb(pt)) }
      } else
      if mark == "-" {
        pt => { draw.line(ll(pt), rr(pt)) }
      } else
      if mark == "|" {
        pt => { draw.line(tt(pt), bb(pt)) }
      }
    )

    if px >= x.min and px <= x.max and py >= y.min and py <= y.max {
      draw-mark(pt)
    }
  }
}
