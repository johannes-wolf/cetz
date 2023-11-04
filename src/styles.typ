#import "util.typ"

#let _default-mark = (
  scale: 1,
  length: .35,
  width: .3,
  inset: .1,
  stroke: auto,
  fill: none,
  start: none,
  end: none,
)

#let default = (
  root: (
    fill: none,
    stroke: black + 1pt,
    radius: 1,
  ),
  mark: _default-mark,
  group: (
    padding: none,
  ),
  line: (
    mark: _default-mark,
  ),
  bezier: (
    mark: _default-mark,
  ),
  arc: (
    // Supported values:
    //   - "OPEN"
    //   - "CLOSE"
    //   - "PIE"
    mode: "OPEN",
  ),
  content: (
    // Allowed values:
    //   - none
    //   - Number
    //   - Array: (y, x), (top, y, bottom), (top, right, bottom, left)
    //   - Dictionary: (top:, right:, bottom:, left:)
    padding: 0,
    // Supported values
    //   - none
    //   - "rect"
    //   - "circle"
    frame: none,
    fill: auto,
    stroke: auto,
  ),
  shadow: (
    color: gray,
    offset-x: .1,
    offset-y: -.1,
  ),
)

/// Resolve the current style root
///
/// - current (style): Current context style (`ctx.style`).
/// - new (style): Style values overwriting the current style (or an empty dict).
///                I.e. inline styles passed with an element: `line(.., stroke: red)`.
/// - root (none, str): Style root element name.
/// - base (none, style): Base style. For use with custom elements, see `lib/angle.typ` as an example.
#let resolve(current, new, root: none, base: none) = {
  if base != none {
    if root != none {
      let default = default
      default.insert(root, base)
      base = default
    } else {
      base = util.merge-dictionary(default, base)
    }
  } else {
    base = default
  }

  let resolve-auto(hier, dict) = {
    if type(dict) != dictionary { return dict }
    for (k, v) in dict {
      if v == auto {
        for i in range(0, hier.len()) {
          let parent = hier.at(i)
          if k in parent {
            v = parent.at(k)
            if v != auto {
              dict.insert(k, v)
              break
            }
          }
        }
      }
      if type(v) == dictionary {
        dict.insert(k, resolve-auto((dict,) + hier, v))
      }
    }
    return dict
  }

  let s = base.root
  if root != none and root in base {
    s = util.merge-dictionary(s, base.at(root))
  } else {
    s = util.merge-dictionary(s, base)
  }
  if root != none and root in current {
    s = util.merge-dictionary(s, current.at(root))
  } else {
    s = util.merge-dictionary(s, current)
  }
  
  s = util.merge-dictionary(s, new)
  s = resolve-auto((current, s, base.root), s)
  return s
}
