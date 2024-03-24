#import "/src/process.typ"
#import "/src/drawable.typ"
#import "/src/styles.typ"
#import "/src/path-util.typ": expand-segments

#let wasm = plugin("/plugin/clipping/clipping.wasm")

#let _clip(a, b, mode: "union", name: none, ..style) = {
  assert(mode in ("union", "intersection", "difference", "xor", "divide"),
    message: "Invalid clip mode")

  (ctx => {
    let style = styles.resolve(ctx.style, merge: style.named())
    let (drawables: a-drawables, ..) = process.many(ctx, a)
    let (drawables: b-drawables, ..) = process.many(ctx, b)

    let mode_data = cbor.encode(mode)

    let a_data = cbor.encode(a-drawables.map(expand-segments))
    let b_data = cbor.encode(b-drawables.map(expand-segments))

    let res = cbor.decode(wasm.clip_path(a_data,
                                         b_data,
                                         mode_data))
    let clipped = ()
    for sub-path in res {
      clipped.push(drawable.path(sub-path,
        stroke: style.stroke, fill: style.fill, close: true))
    }

    return (
      ctx: ctx,
      drawables: clipped,
    )
  },)
}

/// Return one or more union paths of the input paths a and b.
///
/// *Note:* All of the clipping functions can only clip non `content` elements!
/// Content elements passed to clipping functions are ignored.
///
/// *Note:* All of the clipping functions have limitations on which paths
/// they work. Especially paths with cubic beziers (circles) can make the
/// clipping functions fail in some circumstances. You can try to slightly
/// move elements to fix those errors.
///
/// ```example
/// union-path({
///   rotate(45deg)
///   rect((-.5, -.5), (rel: (1,1)))
/// }, {
///   rect((-.5, -.5), (.5,.5))
/// })
/// ```
///
/// - a (element): Path a
/// - b (element): Path b
/// - name (none,str):
/// - ..style (any):
/// -> element
#let union-path(a, b, name: none, ..style) = {
  _clip(a, b, name: name, mode: "union", ..style)
}

/// Return the intersection paths between paths a and b
///
/// ```example
/// intersection-path({
///   rotate(45deg)
///   rect((-.5, -.5), (rel: (1,1)))
/// }, {
///   rect((-.5, -.5), (.5,.5))
/// })
/// ```
///
/// - a (element): Path a
/// - b (element): Path b
/// - name (none,str):
/// - ..style (any):
/// -> element
#let intersection-path(a, b, name: none, ..style) = {
  _clip(a, b, name: name, mode: "intersection", ..style)
}

/// Return the difference paths between paths a and b
///
/// ```example
/// difference-path({
///   rotate(45deg)
///   rect((-.5, -.5), (rel: (1,1)))
/// }, {
///   rect((-.5, -.5), (.5,.5))
/// })
/// ```
///
/// - a (element): Path a
/// - b (element): Path b
/// - name (none,str):
/// - ..style (any):
/// -> element
#let difference-path(a, b, name: none, ..style) = {
  _clip(a, b, name: name, mode: "difference", ..style)
}
