// This file contains functions related to bezier curve calculation
#import "vector.typ"

// Map number v from range (ds, de) to (ts, te)
#let _map(v, ds, de, ts, te) = {
  let d1 = de - ds
  let d2 = te - ts
  let v2 = v - ds
  let r = v2 / d1
  return ts + d2 * r
}

/// Get point on quadratic bezier at position t
///
/// - a (vector): Start point
/// - b (vector): End point
/// - c (vector): Control point
/// - t (float): Position on curve [0, 1]
/// -> vector
#let quadratic-point(a, b, c, t) = {
  // (1-t)^2 * a + 2 * (1-t) * t * c + t^2 b
  return vector.add(
    vector.add(
      vector.scale(a, calc.pow(1-t, 2)),
      vector.scale(c, 2 * (1-t) * t)
    ),
    vector.scale(b, calc.pow(t, 2))
  )
}

/// Get dx/dt of quadratic bezier at position t
///
/// - a (vector): Start point
/// - b (vector): End point
/// - c (vector): Control point
/// - t (float): Position on curve [0, 1]
/// -> vector
#let quadratic-derivative(a, b, c, t) = {
  // 2(-a(1-t) + bt - 2ct + c)
  return vector.scale(
    vector.add(
      vector.sub(
        vector.add(
          vector.scale(vector.neg(a), (1 - t)),
          vector.scale(b, t)),
        vector.scale(c, 2 * t)),
      c)
  , 2)
}

/// Get point on cubic bezier curve at position t
///
/// - a (vector):  Start point
/// - b (vector):  End point
/// - c1 (vector): Control point 1
/// - c2 (vector): Control point 2
/// - t (float):   Position on curve [0, 1]
/// -> vector
#let cubic-point(a, b, c1, c2, t) = {
  // (1-t)^3*a + 3*(1-t)^2*t*c1 + 3*(1-t)*t^2*c2 + t^3*b
  vector.add(
    vector.add(
      vector.scale(a, calc.pow(1-t, 3)),
      vector.scale(c1, 3 * calc.pow(1-t, 2) * t)
    ),
    vector.add(
      vector.scale(c2, 3*(1-t)*calc.pow(t,2)),
      vector.scale(b, calc.pow(t, 3))
    )
  )
}

/// Get dx/dt of cubic bezier at position t
///
/// - a (vector): Start point
/// - b (vector): End point
/// - c1 (vector): Control point 1
/// - c2 (vector): Control point 2
/// - t (float): Position on curve [0, 1]
/// -> vector
#let cubic-derivative(a, b, c1, c2, t) = {
  // -3(a(1-t)^2 + t(-2c2 - bt + 3 c2 t) + c1(-1 + 4t - 3t^2))
  vector.scale(
    vector.add(
      vector.add(
        vector.scale(a, calc.pow((1 - t), 2)),
        vector.scale(
          vector.sub(
            vector.add(
              vector.scale(b, -1 * t),
              vector.scale(c2, 3 * t)
            ),
            vector.scale(c2, 2)
          ),
          t
        )
      ),
      vector.scale(c1, -3 * calc.pow(t, 2) + 4 * t - 1)
    ),
    -3
  )
}

/// Get bezier curves ABC coordinates
///
///        /A\  <-- Control point of quadratic bezier
///       / | \
///      /  |  \
///     /_.-B-._\  <-- Point on curve
///    ,'   |   ',
///   /     |     \
///  s------C------e  <-- Point on line between s and e
///
/// - s (vector): Curve start
/// - e (vector): Curve end
/// - B (vector): Point on curve
/// - t (fload): Position on curve [0, 1]
/// - deg (int): Bezier degree (2 or 3)
/// -> (tuple) Tuple of A, B and C vectors
#let to-abc(s, e, B, t, deg: 2) = {
  let tt = calc.pow(t, deg)
  let u(t) = {
    (calc.pow(1 - t, deg) /
     (tt + calc.pow(1 - t, deg)))
  }
  let ratio(t) = {
    calc.abs((tt + calc.pow(1 - t, deg) - 1) /
             (tt + calc.pow(1 - t, deg)))
  }

  let C = vector.add(vector.scale(s, u(t)), vector.scale(e, 1 - u(t)))
  let A = vector.sub(B, vector.scale(vector.sub(C, B), 1 / ratio(t)))

  return (A, B, C)
}


/// Compute control points for quadratic bezier through 3 points
///
/// - s (vector): Curve start
/// - e (vector): Curve end
/// - B (vector): Point on curve
///
/// -> (s, e, c) Cubic bezier curve points
#let quadratic-through-3points(s, B, e) = {
  let d1 = vector.dist(s, B)
  let d2 = vector.dist(e, B)
  let t = d1 / (d1 + d2)

  let (A, B, C) = to-abc(s, e, B, t, deg: 2)

  return (s, e, A)
}

/// Compute control points for cubic bezier through 3 points
///
/// - s (vector): Curve start
/// - e (vector): Curve end
/// - B (vector): Point on curve
///
/// -> (s, e, c1, c2) Cubic bezier curve points
#let cubic-through-3points(s, B, e) = {
  let d1 = vector.dist(s, B)
  let d2 = vector.dist(e, B)
  let t = d1 / (d1 + d2)

  let (A, B, C) = to-abc(s, e, B, t, deg: 3)

  let d = vector.sub(B, C)
  if vector.len(d) == 0 {
    return (s, e, s, e)
  }

  d = vector.norm(d)
  d = (-d.at(1), d.at(0))
  d = vector.scale(d, vector.dist(s, e) / 3)
  let c1 = vector.add(A, vector.scale(d, t))
  let c2 = vector.sub(A, vector.scale(d, (1 - t)))

  let is-right = ((e.at(0) - s.at(0))*(B.at(1) - s.at(1)) -
                  (e.at(1) - s.at(1))*(B.at(0) - s.at(0))) < 0
  if is-right {
    (c1, c2) = (c2, c1)
  }

  return (s, e, c1, c2)
}

/// Convert quadratic bezier to cubic
///
/// - s (vector): Curve start
/// - e (vector): Curve end
/// - c (vector): Control point
///
/// -> (s, e, c1, c2)
#let quadratic-to-cubic(s, e, c) = {
  let c1 = vector.add(s, vector.scale(vector.sub(c, s), 2/3))
  let c2 = vector.add(e, vector.scale(vector.sub(c, e), 2/3))
  return (s, e, c1, c2)
}

/// Split a cubic bezier into two cubic beziers at t
///
/// - s  (vector): Curve start
/// - e  (vector): Curve end
/// - c1 (vector): Control point 1
/// - c2 (vector): Control point 2
/// - t  (float): t 0..1
/// -> ((s, e, c1, c2), (s, e, c1, c2))
#let split(s, e, c1, c2, t) = {
  t = calc.max(0, calc.min(t, 1))

  let split-rec(pts, t, left, right) = {
    if pts.len() == 1 {
      left.push(pts.at(0))
      right.push(pts.at(0))
    } else {
      let new-pts = ()
      for i in range(0, pts.len() - 1) {
        if i == 0 {
          left.push(pts.at(i))
        }
        if i == pts.len() - 2 {
          right.push(pts.at(i + 1))
        }
        new-pts.push(vector.add(vector.scale(pts.at(i), (1 - t)),
                                vector.scale(pts.at(i + 1), t)))
      }
      (left, right) = split-rec(new-pts, t, left, right)
    }
    return (left, right)
  }
  let (left, right) = split-rec((s, c1, c2, e), t, (), ())

  return ((left.at(0), left.at(3), left.at(1), left.at(2)),
          (right.at(0), right.at(3), right.at(1), right.at(2)))
}

/// Approximate cubic curve length
/// - s  (vector): Curve start
/// - e  (vector): Curve end
/// - c1 (vector): Control point 1
/// - c2 (vector): Control point 2
/// -> float Arc length
#let cubic-arclen(s, e, c1, c2, samples: 10) = {
  let d = 0
  let last = none
  for t in range(0, samples + 1) {
    let pt = cubic-point(s, e, c1, c2, t / samples)
    if last != none {
      d += vector.dist(last, pt)
    }
    last = pt
  }
  return d
}

/// Shorten the curve by offsetting s and c1 or e and c2
/// by distance d. If d is positive the curve gets shortened
/// by moving s and c1 closer to e, if d is negative, e and c2
/// get moved closer to s.
///
/// - s  (vector): Curve start
/// - e  (vector): Curve end
/// - c1 (vector): Control point 1
/// - c2 (vector): Control point 2
/// - d  (float): Distance to shorten by
/// -> (s, e, c1, c2) Shortened curve
#let cubic-shorten-linear(s, e, c1, c2, d) = {
  if d == 0 { return (s, e, c1, c2) }

  let t = if d < 0 { 1 } else { 0 }
  let sign = if d < 0 { -1 } else { 1 }

  let a = cubic-point(s, e, c1, c2, t)
  let b = cubic-point(s, e, c1, c2, t + sign * 0.01)
  let offset = vector.scale(vector.norm(vector.sub(b, a)),
    calc.abs(d))
  if d > 0 {
    s = vector.add(s, offset)
    c1 = vector.add(c1, offset)
  } else {
    e = vector.add(e, offset)
    c2 = vector.add(c2, offset)
  }
  return (s, e, c1, c2)
}

/// Approximate bezier interval t for a given distance d.
/// If d is positive, the functions starts from the curves
/// start s, if d is negative, it starts form the curves end
/// e.
/// -> float Bezier t value from [0,1]
#let cubic-t-for-distance(s, e, c1, c2, d, samples: 20) = {
  let travel-forwards(s, e, c1, c2, d) = {
    let sum = 0
    for n in range(1, samples + 1) {
      let t0 = (n - 1) / samples
      let t1 = n / samples

      let segment-dist = vector.dist(cubic-point(s, e, c1, c2, t0),
                                     cubic-point(s, e, c1, c2, t1))
      if sum <= d and d <= sum + segment-dist {
        return t0 + (d - sum) / segment-dist / samples
      }
      sum += segment-dist
    }
    return 1
  }

  if d == 0 {
    return 0
  }

  if d > 0 {
    return travel-forwards(s, e, c1, c2, d)
  } else {
    return 1 - travel-forwards(e, s, c2, c1, -d)
  }
}

/// Shorten curve by distance d. This keeps the curvature of the
/// curve by finding new values along the original curve.
/// If d is positive the curve gets shortened by moving s
/// closer to e, if d is negative, e is moved closer to s.
/// The points s and e are moved along the curve, keeping the
/// kurves curvature the same (the control points get recalculated).
///
/// - s  (vector): Curve start
/// - e  (vector): Curve end
/// - c1 (vector): Control point 1
/// - c2 (vector): Control point 2
/// - d  (float): Distance to shorten by
/// - samples (int): Maximum of samples/steps to use
/// -> (s, e, c1, c2) Shortened curve
#let cubic-shorten(s, e, c1, c2, d, samples: 15) = {
  if d == 0 { return (s, e, c1, c2) }

  let (left, right) = split(s, e, c1, c2, cubic-t-for-distance(s, e, c1, c2, d, samples: samples))
  return if d > 0 {
    right
  } else {
    left
  }
}

/// Align curve points pts to the line start-end
#let align(pts, start, end) = {
  let (x, y, _) = start
  let a = -calc.atan2(end.at(1) - y, end.at(0) - x)
  return pts.map(p => {
    ((p.at(0) - x) * calc.cos(-a) - (pt.at(1) - y) * calc.sin(-a),
     (p.at(0) - x) * calc.sin(-a) - (pt.at(1) - y) * calc.cos(-a),
     p.at(2))
  })
}

/// Find cubic curve extrema by calculating
/// the roots of the curves first derivative.
///
/// -> (array of vector) List of extrema points
#let cubic-extrema(s, e, c1, c2) = {
  // Compute roots of a single dimension (x, y, z) of the
  // curve by using the abc formula for finding roots of
  // the curves first derivative.
  let dim-extrema(a, b, c1, c2) = {
    let f0 = 3*(c1 - a)
    let f1 = 6*(c2 - 2*c1 + a)
    let f2 = 3*(b - 3*c2 + 3*c1 - a)

    if f1 == 0 and f2 == 0 {
      return ()
    }

    // Linear function
    if f2 == 0 {
      return (-f0 / f1,)
    }

    // No real roots
    let discriminant = f1*f1 - 4*f0*f2
    if discriminant < 0 {
      return ()
    }

    if discriminant == 0 {
      return (-f1 / (2*f2),)
    }

    return ((-f1 - calc.sqrt(discriminant)) / (2*f2),
            (-f1 + calc.sqrt(discriminant)) / (2*f2))
  }

  let pts = ()
  let dims = calc.max(s.len(), e.len())
  for dim in range(dims) {
    let ts = dim-extrema(
      s.at(dim, default: 0),
      e.at(dim, default: 0),
      c1.at(dim, default: 0),
      c2.at(dim, default: 0)
    )
    for t in ts {
      // Discard any root outside the bezier range
      if t >= 0 and t <= 1 {
        pts.push(cubic-point(s, e, c1, c2, t))
      }
    }
  }
  return pts
}

/// Return aabb coordinates for cubic bezier curve
///
/// -> (bottom-left, top-right)
#let cubic-aabb(s, e, c1, c2) = {
  let (lo, hi) = (s, e)
  for dim in range(lo.len()) {
    if lo.at(dim) > hi.at(dim) {
      (lo.at(dim), hi.at(dim)) = (hi.at(dim), lo.at(dim))
    }
  }
  for pt in cubic-extrema(s, e, c1, c2) {
    for dim in range(pt.len()) {
      lo.at(dim) = calc.min(lo.at(dim), hi.at(dim), pt.at(dim))
      hi.at(dim) = calc.max(lo.at(dim), hi.at(dim), pt.at(dim))
    }
  }
  return (lo, hi)
}

/// Returns a cubic bezier between p2 and p3 for a catmull-rom curve
/// through all four points.
///
/// - p1 (vector): Point 1
/// - p2 (vector): Point 2
/// - p3 (vector): Point 3
/// - p4 (vector): Point 4
/// - k  (float): Tension between 0 and 1
/// -> (a, b, c1, c2)
#let _catmull-section-to-cubic(p1, p2, p3, p4, k) = {
  return (p2, p3,
          vector.add(p2, vector.scale(vector.sub(p3, p1), 1/(k * 6))),
          vector.sub(p3, vector.scale(vector.sub(p4, p2), 1/(k * 6))))
}

/// Returns a list of cubic beziert for a catmull curve through points
///
/// - points (array): Array of 2d points
/// - k (float): Strength between 0 and oo
#let catmull-to-cubic(points, k, close: false) = {
  k = calc.max(k, 0.1)
  k = if k < .5 {
    1 / _map(k, .5, 0, 1, 10)
  } else {
    _map(k, .5, 1, 1, 10)
  }

  let len = points.len()
  if len == 2 {
    return ((points.at(0), points.at(1),
             points.at(0), points.at(1)),)
  } else if len > 2 {
    let curves = ()

    let (i0, iN) = if close {
      (-1, 0)
    } else {
      (0, -1)
    }

    curves.push(_catmull-section-to-cubic(points.at(i0), points.at(0),
                                          points.at(1), points.at(2), k))
    for i in range(1, len - 2, step: 1) {
      curves.push(_catmull-section-to-cubic(
        ..range(i - 1, i + 3).map(i => points.at(i)), k))
    }

    curves.push(_catmull-section-to-cubic(
      points.at(-3), points.at(-2), points.at(-1), points.at(iN), k))

    if close {
      curves.push(_catmull-section-to-cubic(
        points.at(-2), points.at(-1), points.at(0), points.at(1), k))
    }

    return curves
  }
  return ()
}

/// Find roots of a cubic polynomial with the coefficients a, b, c and d
///
/// -> array Array of roots
#let _cubic-roots(a, b, c, d) = {
  let epsilon = 0.000001
  if calc.abs(a) < 1e-6 {
    if calc.abs(b) < 1e-6 {
      // Constant
      if c == 0 {
        return ()
      }

      // Linear
      let root = -1 * d / c
      if root < 0 - epsilon and root > 1 + epsilon {
        return ()
      }
      return (root,)
    }

    // Quadratic
    let dq = calc.pow(c, 2) - 4 * b * d
    if dq >= 0 {
      dq = calc.sqrt(dq)
      let roots = (-1 * (dq + c) / (2 * b),
                        (dq - c) / (2 * b))
      return roots.filter(t => t >= 0 - epsilon and t <= 1 + epsilon)
    }
  }

  let (A, B, C) = (b/a, c/a, d/a)
  let Q = (3 * B - calc.pow(A, 2)) / 9
  let R = (9 * A * B - 27 * C - 2 * calc.pow(A, 3)) / 54
  let D = calc.pow(Q, 3) + calc.pow(R, 2)
  let aa = -A / 3

  let sgn = x => { if x < 0 { -1 } else { 1 } }
  let roots = if D >= 0 {
    let S = sgn(R + calc.sqrt(D)) * calc.pow(calc.abs(R + calc.sqrt(D)), 1/3)
    let T = sgn(R - calc.sqrt(D)) * calc.pow(calc.abs(R - calc.sqrt(D)), 1/3)

    if (S - T) != 0 {
      // Roots 2 and 3 are complex
      (aa + (S + T),)
    } else {
      (aa + (S + T), aa - (S + T) / 2)
    }
  } else {
    let th = calc.acos(R / calc.sqrt(-calc.pow(Q, 3))) / 1rad
    let qq = 2 * calc.sqrt(-Q)
    (qq * calc.cos(th / 3) + aa,
     qq * calc.cos((th + 2 * calc.pi) / 3) + aa,
     qq * calc.cos((th + 4 * calc.pi) / 3) + aa)
  }

  return roots.filter(t => t >= 0 - epsilon and t <= 1 + epsilon)
}

/// Calculate 2D cubic-bezier and line intersetction points
///
/// - s   (vector): Bezier start point
/// - e   (vector): Bezier end point
/// - c1  (vector): Bezier control point 1
/// - c2  (vector): Bezier control point 2
/// - la  (vector): Line start point
/// - lb  (vector): Line end point
/// - ray (bool): If set to true, ignore line length
#let line-cubic-intersections(la, lb, s, e, c1, c2, ray: false) = {
  // Based on:
  //   http://www.particleincell.com/blog/2013/cubic-line-intersection/
  // with some rounding improvements
  let a = lb.at(1) - la.at(1)
  let b = la.at(0) - lb.at(0)
  let c = la.at(0) * (la.at(1) - lb.at(1)) + la.at(1) * (lb.at(0) - la.at(0))

  /// Get cubic bezier function coefficients
  let _cubic-coeff(a, b, c, d) = (
    -a + 3*b - 3*c + d,
    3*a - 6*b + 3*c,
    -3*a +3*b,
    a)

  let x-coeff = _cubic-coeff(s.at(0), c1.at(0), c2.at(0), e.at(0))
  let y-coeff = _cubic-coeff(s.at(1), c1.at(1), c2.at(1), e.at(1))

  let roots = _cubic-roots(a * x-coeff.at(0) + b * y-coeff.at(0),
                           a * x-coeff.at(1) + b * y-coeff.at(1),
                           a * x-coeff.at(2) + b * y-coeff.at(2),
                           a * x-coeff.at(3) + b * y-coeff.at(3) + c)

  let pts = ()
  for t in roots {
    let pt = cubic-point(s, e, c1, c2, t)
    if ray {
      pts.push(pt)
    } else {
      let s = if calc.abs(lb.at(0) - la.at(0)) >= 1e-6 {
        (pt.at(0) - la.at(0)) / (lb.at(0) - la.at(0))
      } else {
        (pt.at(1) - la.at(1)) / (lb.at(1) - la.at(1))
      }
      if s >= 0 and s <= 1 {
        pts.push(pt)
      }
    }
  }
  return pts
}
