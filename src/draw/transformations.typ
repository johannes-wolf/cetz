#import "/src/coordinate.typ"
#import "/src/matrix.typ"
#import "/src/vector.typ"
#import "/src/util.typ"

/// Sets the transformation matrix.
///
/// - mat (none, matrix): The 4x4 transformation matrix to set. If `none` is passed, the transformation matrix is set to the identity matrix (`matrix.ident()`).
#let set-transform(mat) = {
  let mat = if mat == none {
    matrix.ident()
  } else {
    mat
  }

  assert(
    type(mat) == array,
    message: "Transformtion matrix must be of type array, got: " + repr(mat)
  )
  assert.eq(
    mat.len(),
    4,
    message: "Transformation matrix must be of size 4x4, got: " + repr(mat)
  )

  (ctx => {
    ctx.transform = mat
    return (ctx: ctx)
  },)
}

/// Rotates the transformation matrix on the z-axis by a given angle or other axes when specified.
///
/// #example(```
/// // Rotate on z-axis
/// rotate(z: 45deg)
/// rect((-1,-1), (1,1))
/// // Rotate on y-axis
/// rotate(y: 80deg)
/// circle((0,0))
/// ```)
///
/// - ..angles (angle): A single angle as a positional argument to rotate on the z-axis by.
///   Named arguments of `x`, `y` or `z` can be given to rotate on their respective axis.
///   You can give named arguments of `yaw`, `pitch` or `roll`, too.
#let rotate(..angles) = {
  assert(angles.pos().len() == 1 or angles.named().len() > 0,
    message: "Rotate takes a single z-angle or angles " +
             "(x, y, z or yaw, pitch, roll) as named arguments, got: " + repr(angles))

  let named = angles.named()
  let names = named.keys()

  let mat = if angles.pos().len() == 1 {
    matrix.transform-rotate-z(angles.pos().at(0))
  } else if names.all(n => n in ("x", "y", "z")) {
    matrix.transform-rotate-xyz(named.at("x", default: 0deg),
                                named.at("y", default: 0deg),
                                named.at("z", default: 0deg))
  } else if names.all(n => n in ("yaw", "pitch", "roll")) {
    matrix.transform-rotate-ypr(named.at("yaw", default: 0deg),
                                named.at("pitch", default: 0deg),
                                named.at("roll", default: 0deg))
  } else {
    panic("Invalid rotate arguments." +
          "Rotate expects: A single (z-axis) angle or any combination of x, y,z or any combination of yaw, pitch, roll. " +
          "Got: " + repr(named))
  }

  (ctx => {
    ctx.transform = matrix.mul-mat(ctx.transform, mat)
    return (ctx: ctx)
  },)
}

/// Translates the transformation matrix by the given vector or dictionary.
///
/// #example(```
/// // Outer rect
/// rect((0, 0), (2, 2))
/// // Inner rect
/// translate(x: .5, y: .5)
/// rect((0, 0), (1, 1))
/// ```)
///
/// - ..args (vector, float, length): A single vector or any combination of the named arguments `x`, `y` and `z` to translate by.
///   A translation matrix with the given offsets gets multiplied with the current transformation depending on the value of `pre`.
/// - pre (bool): Specify matrix multiplication order
///   - false: `World = World * Translate`
///   - true:  `World = Translate * World`
#let translate(..args, pre: false) = {
  assert((args.pos().len() == 1 and args.named() == (:)) or
         (args.pos() == () and args.named() != (:)),
    message: "Expected a single positional argument or one or more named arguments, got: " + repr(args))

  let pos = args.pos()
  let named = args.named()

  let vec = if named != (:) {
    (named.at("x", default: 0), named.at("y", default: 0), named.at("z", default: 0))
  } else {
    vector.as-vec(pos.at(0), init: (0, 0, 0))
  }

  (ctx => {
    // Allow translating by length values
    let vec = vec.map(v => if type(v) == length {
      util.resolve-number(ctx, v)
    } else {
      v
    })

    let t = matrix.transform-translate(..vec)
    if pre {
      ctx.transform = matrix.mul-mat(t, ctx.transform)
    } else {
      ctx.transform = matrix.mul-mat(ctx.transform, t)
    }
    return (ctx: ctx)
  },)
}

/// Scales the transformation matrix by the given factor(s).
///
/// #example(```
/// // Scale the y-axis
/// scale(y: 50%)
/// circle((0,0))
/// ```)
///
/// - ..args (float, ratio): A single value to scale the transformation matrix by or per axis
///   scaling factors. Accepts a single float or ratio value or any combination of the named arguments
///   `x`, `y` and `z` to set per axis scaling factors. A ratio of 100% is the same as the value $1$.
#let scale(..args) = {
  assert((args.pos().len() == 1 and args.named() == (:)) or
         (args.pos() == () and args.named() != (:)),
    message: "Expected a single positional argument or one or more named arguments, got: " + repr(args))

  let pos = args.pos()
  let named = args.named()

  let vec = if args.named() != (:) {
    (named.at("x", default: 1), named.at("y", default: 1), named.at("z", default: 1))
  } else if type(pos.at(0)) == array {
    vector.as-vec(pos, init: (1, 1, 1))
  } else {
    let factor = pos.at(0)
    (factor, factor, factor)
  }

  // Allow scaling using ratio values
  vec = vec.map(v => if type(v) == ratio {
    v / 100%
  } else {
    v
  })

  (ctx => {
    ctx.transform = matrix.mul-mat(ctx.transform, matrix.transform-scale(vec))
    return (ctx: ctx)
  },)
}

/// Sets the given position as the new origin `(0, 0, 0)`
///
/// #example(```
/// // Outer rect
/// rect((0,0), (2,2), name: "r")
/// // Move origin to top edge
/// set-origin("r.north")
/// circle((0, 0), radius: .1)
/// ```)
///
/// - origin (coordinate): Coordinate to set as new origin `(0,0,0)`
#let set-origin(origin) = {
  (
    ctx => {
      let (ctx, c) = coordinate.resolve(ctx, origin)
      let (x, y, z) = vector.sub(
        util.apply-transform(ctx.transform, c),
        util.apply-transform(ctx.transform, (0, 0, 0)),
      )
      ctx.transform = matrix.mul-mat(matrix.transform-translate(x, y, z), ctx.transform)
      return (ctx: ctx)
    },
  )
}

/// Sets the previous coordinate.
///
/// The previous coordinate can be used via `()` (empty coordinate).
/// It is also used as base for relative coordinates if not specified
/// otherwise.
///
/// #example(```
/// circle((), radius: .25)
/// move-to((1,0))
/// circle((), radius: .15)
/// ```)
///
/// - pt (coordinate): The coordinate to move to.
#let move-to(pt) = {
  let t = coordinate.resolve-system(pt)

  return (ctx => {
    let (ctx, pt) = coordinate.resolve(ctx, pt)
    return (ctx: ctx)
  },)
}

/// Span viewport between two coordinates and set-up scaling and translation
///
/// #example(```
/// rect((0,0), (2,2))
/// set-viewport((0,0), (2,2), bounds: (10, 10))
/// circle((5,5))
/// ```)
///
/// - from (coordinate): Bottom-Left corner coordinate
/// - to (coordinate): Top right corner coordinate
/// - bounds (vector): Viewport bounds vector that describes the inner width,
///   height and depth of the viewport
#let set-viewport(from, to, bounds: (1, 1, 1)) = {
  (from, to).map(coordinate.resolve-system)

  return (ctx => {
    let bounds = vector.as-vec(bounds, init: (1, 1, 1))

    let (ctx, from, to) = coordinate.resolve(ctx, from, to)
    let (fx, fy, fz) = from
    let (tx, ty, tz) = to

    // Compute scaling
    let (sx, sy, sz) = vector.sub((tx, ty, tz),
                                  (fx, fy, fz)).enumerate().map(((i, v)) => if bounds.at(i) == 0 {
      0
    } else {
      v / bounds.at(i)
    })

    ctx.transform = matrix.mul-mat(ctx.transform,
      matrix.transform-translate(fx, fy, fz))
    ctx.transform = matrix.mul-mat(ctx.transform,
      matrix.transform-scale((sx, sy, sz)))
    return (ctx: ctx)
  },)
}

