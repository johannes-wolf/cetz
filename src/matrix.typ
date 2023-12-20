#import "vector.typ"

#let cos(angle) = {
  return calc.round(calc.cos(angle), digits: 10)
}

#let sin = calc.sin

#let pi = calc.pi

/// Create identity matrix with dimensions $m times n$
///
/// - m (int): Rows
/// - n (int): Columns
/// - one (float): Value to set as $1$
/// - zero (float): Value to set as $0$
/// -> matrix
#let ident(m: 4, n: 4, one: 1, zero: 0) = {
  ({for m in range(0, m) {
    ({for n in range(0, n) {
        if m == n { (one,) } else { (zero,) }
     }},)
    }})
}

/// Return matrix dimensions (m, n)
/// -> tuple
#let dim(m) = {
  return (m.len(), if m.len() > 0 {m.at(0).len()} else {0})
}

/// Return a $4 times 4$ translation matrix
#let transform-translate(x, y, z) = {
  ((1, 0, 0, x),
   (0, 1, 0, y),
   (0, 0, 1, z),
   (0, 0, 0, 1))
}

/// Return a $4 times 4$ z-shear matrix
#let transform-shear-z(factor) = {
  ((1, 0, factor, 0),
   (0, 1,-factor, 0),
   (0, 0, 1, 0),
   (0, 0, 0, 1))
}

// Return 4x4 scale matrix
#let transform-scale(f) = {
  let (x, y, z) = if type(f) == array {
    vector.as-vec(f, init: (1, 1, 1))
  } else if type(f) == dictionary {
    (f.at("x", default: 1),
     f.at("y", default: 1),
     f.at("z", default: 1))
  } else {
    (f, f, f)
  }
  return(
   (x, 0, 0, 0),
   (0, y, 0, 0),
   (0, 0, z, 0),
   (0, 0, 0, 1))
}

// Return 4x4 rotate x matrix
#let transform-rotate-x(angle) = {
  // let (cos, sin) = (calc.cos, calc.sin)
  ((1, 0, 0, 0),
   (0, cos(angle), -sin(angle), 0),
   (0, sin(angle), cos(angle), 0),
   (0, 0, 0, 1))
}

// Return 4x4 rotate y matrix
#let transform-rotate-y(angle) = {
  // let (cos, sin) = (calc.cos, calc.sin)
  ((cos(angle), 0, -sin(angle), 0),
   (0, 1, 0, 0),
   (sin(angle), 0, cos(angle), 0),
   (0, 0, 0, 1))
}

// Return 4x4 rotate z matrix
#let transform-rotate-z(angle) = {
  ((cos(angle), -sin(angle), 0, 0),
   (sin(angle), cos(angle), 0, 0),
   (0, 0, 1, 0),
   (0, 0, 0, 1))
}

// Return 4x4 rotate xz matrix
#let transform-rotate-xz(x, z) = {
  ((cos(z), sin(z), 0, 0),
   (-cos(x)*sin(z), cos(x)*cos(z), -sin(x), 0),
   (sin(x)*sin(z), -sin(x)*cos(z), cos(x), 1),
   (0, 0, 0, 1))
}

/// Return 4x4 rotation matrix - yaw-pitch-roll
///
/// Calculates the product of the three rotation matrices
/// R = Rz(a) Ry(b) Rx(c)
///
/// - a (angle): Yaw
/// - b (angle): Pitch
/// - c (angle): Roll
/// -> matrix
#let transform-rotate-ypr(a, b, c) = {
  ((cos(a)*cos(b), cos(a)*sin(b)*sin(c) - sin(a)*cos(c), cos(a)*sin(b)*cos(c) + sin(a)*sin(c), 0),
   (sin(a)*cos(b), sin(a)*sin(b)*sin(c) + cos(a)*cos(c), sin(a)*sin(b)*cos(c) - cos(a)*sin(c), 0),
   (-sin(b), cos(b)*sin(c), cos(b)*cos(c), 1),
   (0,0,0,1))
}

/// Return 4x4 rotation matrix - euler angles
///
/// Calculates the product of the three rotation matrices
/// R = Rz(z) Ry(y) Rx(x)
///
/// - x (angle): Rotation about x
/// - y (angle): Rotation about y
/// - z (angle): Rotation about z
/// -> matrix
#let transform-rotate-xyz(x, y, z) = {
  ((cos(y)*cos(z), sin(x)*sin(y)*cos(z) - cos(x)*sin(z), cos(x)*sin(y)*cos(z) + sin(x)*sin(z), 0),
   (cos(y)*sin(z), sin(x)*sin(y)*sin(z) + cos(x)*cos(z), cos(x)*sin(y)*sin(z) - sin(x)*cos(z), 0),
   (-sin(y), sin(x)*cos(y), cos(x)*cos(y), 0),
   (0,0,0,1))
}

// Multiply matrix with matrix
#let mul-mat(a, b) = {
  let (dim-a, dim-b) = (a, b).map(dim)
  let (m, n, p) = (
    ..dim-a,
    dim-b.last()
  )
  (
    for i in range(m) {
      (
        for j in range(p) {
          (range(n).map(k => a.at(i).at(k) * b.at(k).at(j)).sum(),)
        }
      ,)
    }
  )
}

// Multiply 4x4 matrix with vector of size 3 or 4.
// The value of vec_4 defaults to w (1).
//
// The resulting vector is of dimension 3
#let mul4x4-vec3(mat, vec, w: 1) = {
  assert(vec.len() <= 4)
  let out = (0, 0, 0)
  for m in range(0, 3) {
    let v = (mat.at(m).at(0) * vec.at(0, default: 0)
           + mat.at(m).at(1) * vec.at(1, default: 0)
           + mat.at(m).at(2) * vec.at(2, default: 0)
           + mat.at(m).at(3) * vec.at(3, default: w))
    out.at(m) = v
  }
  return out
}

// Multiply matrix with vector
#let mul-vec(mat, vec) = {
  if mat.len() != vector.dim(vec) {
    panic("matrix m must be equal to vector dim")
  }
  let new = (0, 0, 0, 1)
  for m in range(0, mat.len()) {
    let v = 0
    for n in range(0, vector.dim(vec)) {
      v += vec.at(n) * mat.at(m).at(n)
    }
    new.at(m) = v
  }
  return new
}

#let inverse(matrix) = {
  let n = {
    let size = dim(matrix)
    assert.eq(size.first(), size.last(), message: "Matrix must be square to perform inversion.")
    size.first()
  }

  let N = range(n)
  let inverted = ident(m: n, n: n)
  let p
  for j in N {
    for i in range(j, n) {
      if matrix.at(i).at(j) != 0 {
        (matrix.at(j), matrix.at(i)) = (matrix.at(i), matrix.at(j))
        (inverted.at(j), inverted.at(i)) = (inverted.at(i), inverted.at(j))

        p = 1 / matrix.at(j).at(j)
        for k in N {
          matrix.at(j).at(k) *= p
          inverted.at(j).at(k) *= p
        }

        for L in N {
          if L != j {
            p = -matrix.at(L).at(j)
            for k in N {
              matrix.at(L).at(k) += p * matrix.at(j).at(k)
              inverted.at(L).at(k) += p * inverted.at(j).at(k)
            }
          }
        }
      }
    }
  }

  return inverted
}

/// Swap column a with column b
///
/// - mat (matrix): Matrix
/// - a (int): Column a
/// - b (int): Column b
/// -> matrix New matrix
#let swap-cols(mat, a, b) = {
  let new = mat
  for m in range(mat.len()) {
    new.at(m).at(a) = mat.at(m).at(b)
    new.at(m).at(b) = mat.at(m).at(a)
  }
  return new
}

// Translate the matrix by the vector
#let translate(mat, vec) = {
  return mul-mat(
    mat,
    transform-translate(
      vec.at(0),
      -vec.at(1),
      vec.at(2),
    ),
  )
}
