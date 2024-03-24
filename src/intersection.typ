#import "vector.typ"
#import "util.typ"

/// Check for line-line intersection and return point or none
///
/// - a (vector): Line 1 point 1
/// - b (vector): Line 1 point 2
/// - c (vector): Line 2 point 1
/// - d (vector): Line 2 point 2
/// - ray (bool): Treat both lines as infinite
/// -> (vector,none)
#let line-line(a, b, c, d, ray: false) = {
  let lli8(x1, y1, x2, y2, x3, y3, x4, y4) = {
    let nx = (x1*y2 - y1*x2)*(x3 - x4)-(x1 - x2)*(x3*y4 - y3*x4)
    let ny = (x1*y2 - y1*x2)*(y3 - y4)-(y1 - y2)*(x3*y4 - y3*x4)
    let d = (x1 - x2)*(y3 - y4)-(y1 - y2)*(x3 - x4)
    if d == 0 {
      return none
    }
    return (nx / d, ny / d, 0)
  }
  let pt = lli8(a.at(0), a.at(1), b.at(0), b.at(1),
                c.at(0), c.at(1), d.at(0), d.at(1))
  if pt != none {
    let on-line(pt, a, b) = {
      let (x, y, ..) = pt
      let epsilon = util.float-epsilon
      let mx = calc.min(a.at(0), b.at(0)) - epsilon
      let my = calc.min(a.at(1), b.at(1)) - epsilon
      let Mx = calc.max(a.at(0), b.at(0)) + epsilon
      let My = calc.max(a.at(1), b.at(1)) + epsilon
      return mx <= x and Mx >= x and my <= y and My >= y
    }
    if ray or (on-line(pt, a, b) and on-line(pt, c, d)) {
      return pt
    }
  }
}

// Check for line-cubic bezier intersection
#let line-cubic(la, lb, s, e, c1, c2, ray: false) = {
  import "/src/bezier.typ": line-cubic-intersections as line-cubic
  return line-cubic(la, lb, s, e, c1, c2, ray: ray)
}

// Check for line-linestrip intersection
#let line-linestrip(la, lb, v, ray: false) = {
  let pts = ()
  for i in range(0, v.len() - 1) {
    let pt = line-line(la, lb, v.at(i), v.at(i + 1), ray: ray)
    if pt != none {
      pts.push(pt)
    }
  }
  return pts
}

/// Check for line-path intersection in 2D
///
/// - la (vector): Line start
/// - lb (vector): Line end
/// - path (path): Path
#let line-path(la, lb, path, ray: false) = {
  let segment(s) = {
    let (k, ..v) = s
    if k == "line" {
      return line-linestrip(la, lb, v, ray: ray)
    } else if k == "cubic" {
      return line-cubic(la, lb, ..v, ray: ray)
    } else {
      return ()
    }
  }

  let pts = ()
  for s in path.at("segments", default: ()) {
    pts += segment(s)
  }
  return pts
}

/// Check for path-path intersection in 2D
///
/// - a (path): Path a
/// - b (path): Path b
/// - samples (int): Number of samples to use for bezier curves
/// -> array List of vectors
#let path-path(a, b, samples: 8) = {
  import "bezier.typ": cubic-point

  // Convert segment to vertices by sampling curves
  let linearize-segment(s) = {
    let t = s.at(0)
    if t == "line" {
      return s.slice(1)
    } else if t == "cubic" {
      return range(samples + 1).map(
        t => cubic-point(..s.slice(1), t/samples)
      )
    }
  }

  let pts = ()
  for s in a.at("segments", default: ()) {
    let sv = linearize-segment(s)
    for ai in range(0, sv.len() - 1) {
      pts += line-path(sv.at(ai), sv.at(ai + 1), b)
    }
  }
  return pts
}
