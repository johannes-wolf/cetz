// This file contains utility functions for path calculation
#import "util.typ"
#import "vector.typ"
#import "bezier.typ"
#import "deps.typ"
#import deps.oxifmt: strfmt

#let default-samples = 25

/// Get first position vector of a path segment
///
/// - s (segment): Path segment
/// -> vector
#let segment-start(s) = {
  return s.at(1)
}

/// Get last position vector of a path segment
///
/// - s (segment): Path segment
/// -> vector
#let segment-end(s) = {
  if s.at(0) == "line" {
    return s.last()
  }
  return s.at(2)
}

/// Calculate bounding points for a list of path segments
///
/// - segments (array): List of path segments
/// -> array: List of vectors
#let bounds(segments) = {
  let bounds = ()

  for s in segments {
    let (kind, ..pts) = s
    if kind == "line" {
      bounds += pts
    } else if kind == "cubic" {
      bounds.push(pts.at(0))
      bounds.push(pts.at(1))
      bounds += bezier.cubic-extrema(..pts)
    }
  }
  return bounds
}

/// Calculate length of a single path segment
///
/// - s (array): Path segment
/// -> float: Length of the segment in canvas units
#let _segment-length(s, samples: default-samples) = {
  let (kind, ..pts) = s
  if kind == "line" {
    let len = 0
    for i in range(1, pts.len()) {
      len += vector.len(vector.sub(pts.at(i - 1), pts.at(i)))
    }
    return len
  } else if kind == "cubic" {
    return bezier.cubic-arclen(..pts, samples: samples)
  } else {
    panic("Invalid segment: " + kind, s)
  }
}

/// Get the length of a path
///
/// - segments (array): List of path segments
/// -> float: Total length of the path
#let length(segments) = {
  return segments.map(_segment-length).sum()
}

/// Finds the two points that are between t on a line segment.
#let _points-between-distance(pts, distance) = {
  let travelled = 0
  let length = 0
  for i in range(1, pts.len()) {
    length = vector.dist(pts.at(i - 1), pts.at(i))
    if travelled <= distance and distance <= travelled + length {
      return (
        start: i - 1,
        end: i,
        distance: distance - travelled,
        length: length
      )
    }
    travelled += length
  }
  return (
    start: pts.len() - 2,
    end: pts.len() - 1,
    distance: length,
    length: length
  )
}

/// Finds the point at a given distance from the start of a line segment. Distances greater than the length of the segment return the end of the line segment. Distances less than zero return the start of the segment.
///
/// - segment (array): The line segment
/// - distance (float): The distance along the line segment to find the point
/// -> vector: The point on the line segment
#let _point-on-line-segment(segment, distance) = {
  let pts = segment.slice(1)

  let (start, end, distance, length) = _points-between-distance(pts, distance)
  return if length == 0 {
    // length can be zero if start and end are at the same position
    // this can occur for several reasons, user input, group has zero width or height (not both)
    pts.at(end)
  } else {
    vector.lerp(pts.at(start), pts.at(end), distance / length)
  }
}

/// Finds the point at a given distance from the start of a path segment. Distances greater than the length of the segment return the end of the path segment. Distances less than zero return the start of the segment.
///
/// - segment (segment): Path segment
/// - distance (float): The distance along the path segment to find the point
/// - extrapolate (bool): If true, use linear extrapolation for distances outsides the path
///
/// -> vector: The point on the path segment
#let _point-on-segment(segment, distance, samples: default-samples, extrapolate: false) = {
  let (kind, ..pts) = segment
  if kind == "line" {
    return _point-on-line-segment(segment, distance)
  } else if kind == "cubic" {
    return bezier.cubic-point(
      ..pts,
      bezier.cubic-t-for-distance(
        ..pts,
        distance,
        samples: samples
      )
    )
  }
}

#let segment-at-t(segments, t, rev: false, samples: default-samples, clamp: false) = {
  let lengths = segments.map(_segment-length.with(samples: samples))
  let total = lengths.sum()

  if type(t) == ratio {
    t = total * t / 100%
  }
  if not clamp {
    assert(t >= 0 and t <= total,
      message: strfmt("t is expected to be between 0 and the length of the path ({}), got: {}", total, t))
  }

  if rev {
    segments = segments.rev()
    lengths = lengths.rev()
  }
  let travelled = 0
  for (i, segment-length) in segments.zip(lengths).enumerate() {
    let (segment, length) = segment-length
    if travelled <= t and t <= travelled + length {
      return (
        index: if rev { segments.len() - i } else { i },
        segment: segment,
        // Distance travelled
        travelled: travelled,
        // Distance left
        distance: t - travelled,
        // The length of the segment
        length: length
      )
    }
    travelled += length
  }
  return (index: if rev { 0 } else { segments.len() - 1 },
    segment: segments.last(),
    travelled: total,
    distance: t,
    length: lengths.last())
}

#let _extrapolated-point-on-segment(segment, distance, rev: false, samples: 100) = {
  let (kind, ..pts) = segment
  let (pt, dir) = if kind == "line" {
    let (a, b) = if rev {
      (pts.at(0), pts.at(1))
    } else {
      (pts.at(-2), pts.at(-1))
    }
    (if rev {a} else {b}, vector.sub(b, a))
  } else {
    let dir = bezier.cubic-derivative(..pts, if rev { 0 } else { 1 })
    if vector.len(dir) == 0 {
      dir = vector.sub(pts.at(1), pts.at(0))
    }
    (if rev {pts.at(0)} else {pts.at(1)}, dir)
  }

  if vector.len(dir) != 0 {
    return vector.add(pt, vector.scale(vector.norm(dir), distance * if rev { -1 } else { 1 }))
  }
  return none
}

/// Get position on path
///
/// - segments (array): List of path segments
/// - t (int,float,ratio): Absolute position on the path if given an
///   float or integer, or relative position if given a ratio from 0% to 100%
/// - extrapolate (bool): If true, use linear extrapolation if distance is outsides the paths range
/// -> none,vector: Position on path. If the path is empty (segments == ()), none is returned
#let point-on-path(segments, t, samples: default-samples, extrapolate: false) = {
  assert(
    type(t) in (int, float, ratio),
    message: "Distance t must be of type int, float or ratio"
  )
  let rev = if type(t) == ratio and t < 0% or type(t) in ("int", "float") and t < 0 {
    true
  } else {
    false
  }
  if rev {
    t *= -1
  }

  // Extrapolate at path boundaries if enabled
  if extrapolate {
    let total = length(segments)
    let absolute-t = if type(t) == ratio { t / 100% * total } else { t }
    if absolute-t > total {
      return _extrapolated-point-on-segment(segments.first(), absolute-t - total, rev: rev, samples: samples)
    }
  }

  let segment = segment-at-t(segments, t, samples: samples, rev: rev)
  return if segment != none {
    let (distance, segment, length, ..) = segment
    _point-on-segment(segment, if rev { length - distance } else { distance }, samples: samples, extrapolate: extrapolate)
  }
}

/// Get position and direction on path
///
/// - segments (array): List of path segments
/// - t (float): Position (from 0 to 1)
/// - clamp (bool): Clamp position between 0 and 1
/// -> tuple: Tuple of the point at t and the scaled direction
#let direction(segments, t, samples: default-samples, clamp: false) = {
  let (segment, distance, length, ..) = segment-at-t(segments, t, samples: samples, clamp: clamp)
  let (kind, ..pts) = segment
  return (
    _point-on-segment(segment, distance, samples: samples),
    if kind == "line" {
      let (start, end, distance, length) = _points-between-distance(pts, distance)
      vector.norm(vector.sub(segment.at(end+1), segment.at(start+1)))
    } else {
      let t = bezier.cubic-t-for-distance(..pts, distance, samples: samples)
      let dir = bezier.cubic-derivative(..pts, t)
      if vector.len(dir) == 0 {
        vector.norm(vector.sub(pts.at(1), pts.at(0)))
      } else {
        dir
      }
    }
  )
}

/// Create a line segment with points
///
/// - points (array): List of points
/// -> array Segment
#let line-segment(points) = {
  ("line",) + points
}

/// Create a cubic bezier segment
///
/// - a (vector): Start
/// - b (vector): End
/// - ctrl-a (vector): Control point a
/// - ctrl-b (vector): Control point b
/// -> array Segment
#let cubic-segment(a, b, ctrl-a, ctrl-b) = {
  ("cubic", a, b, ctrl-a, ctrl-b)
}

/// Normalize segments by connecting gaps via straight line segments
/// and merging multiple line segments into a single one.
///
/// - segments (array): Path segments
/// -> array Normalized path segments
#let normalize(segments) = {
  let new = ()
  for s in segments {
    if new == () {
      new.push(s)
    } else {
      let head = new.last()
      let (kind, ..pts) = s

      if kind == "line" and head.at(0) == kind {
        // Merge consecutive line segments
        if new.last().len() > 0 and new.last().last() == pts.first() {
          new.last() += pts.slice(1)
        } else {
          new.last() += pts
        }
      } else if segment-start(s) != segment-end(head) {
        // Push a new line or line point if the current segment
        // does not start where the previous segment ended
        if head.at(0) == "line" {
          new.last().push(pts.first())
        } else {
          new.push(line-segment((segment-end(head), segment-start(s))))
        }
        // Push the segment
        new.push(s)
      } else {
        new.push(s)
      }
    }
  }
  return new
}

/// Shortens a segment by a given distance.
#let shorten-segment(segment, distance, snap-to: none, mode: "CURVED", samples: default-samples) = {
  let rev = distance < 0
  if distance >= _segment-length(segment) {
    return line-segment(if rev {
      (segment-start(segment), segment-start(segment))
    } else {
      (segment-end(segment), segment-end(segment))
    })
  }

  let (kind, ..s) = segment
  if kind == "line" {
    if rev {
      distance *= -1
      s = s.rev()
    }
    let (start, end, distance, length) = _points-between-distance(s, distance)
    if length != 0 {
      s = (vector.lerp(s.at(start), s.at(end), distance / length),) + s.slice(end)
    }

    if rev {
      s = s.rev()
    }
  } else {
    s = if mode == "LINEAR" {
      bezier.cubic-shorten-linear(..s, distance)
    } else {
      bezier.cubic-shorten(..s, distance, samples: samples)
    }

    // Shortening beziers suffers from rounding or precision errors
    // so we "snap" the curve start/end to the snap-points, if provided.
    if snap-to != none {
      if rev { s.at(1) = snap-to } else { s.at(0) = snap-to }
    }
  }
  return (kind,) + s
}

/// Shortens a path's segments by the given distances. The start of the path is shortened first by moving the point along the line towards the end. The end of the path is then shortened in the same way. When a distance is 0 no other calculations are made.
/// 
/// - segments (segments): The segments of the path to shorten.
/// - start-distance (int, float): The distance to shorten from the start of the path.
/// - end-distance (int, float): The distance to shorten from the end of the path
/// - pos (none, tuple): Tuple of points to "snap" the path ends to
/// -> segments Segments of the path that have been shortened
#let shorten-path(segments, start-distance, end-distance, snap-to: none, mode: "CURVED", samples: default-samples) = {
  let total = length(segments)
  let (snap-start, snap-end) = if snap-to == none {
    (none, none)
  } else {
    snap-to
  }

  if start-distance > 0 {
    let (segment, distance, index, ..) = segment-at-t(
      segments,
      start-distance,
      clamp: true,
    )
    segments = segments.slice(index + 1)
    segments.insert(0,
      shorten-segment(
        segment, 
        distance,
        mode: mode,
        samples: samples,
        snap-to: snap-start
      )
    )
  }
  if end-distance > 0 {
    let (segment, distance, index, ..) = segment-at-t(
      segments,
      end-distance,
      rev: true,
      clamp: true,
    )
    segments = segments.slice(0, index - 1)
    segments.push(
      shorten-segment(
        segment, 
        -distance,
        mode: mode,
        samples: samples,
        snap-to: snap-end
      )
    )
  }
  return segments
}


/// Expand line-strips into single line segments
/// this can make algorithms processing the path easier.
///
/// - p (path): Input path
/// -> array Expanded path segments list
#let expand-segments(p, linearize: false, samples: 8) = {
  let new = ()
  for s in p.segments {
    let (kind, ..pts) = s
    if kind == "line" and pts.len() > 2 {
      for i in range(1, pts.len()) {
        new.push(("line", pts.at(i - 1), pts.at(i)))
      }
    } else if linearize and kind == "cubic" {
      let pts = range(samples + 1).map(
        t => cubic-point(..s.slice(1), t / samples))
      for i in range(1, pts.len()) {
        new.push(("line", pts.at(i - 1), pts.at(i)))
      }
    } else {
      new.push(s)
    }
  }
  return new
}
