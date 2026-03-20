///|
/// Port of Go's TestRectangle from geom_test.go.
test "rectangle" {
  // in_ checks that every point in f is in g
  fn rect_all_points_in(f : Rectangle, g : Rectangle) -> Bool {
    if !f.in_(g) {
      return false
    }
    let mut y = f.min.y
    while y < f.max.y {
      let mut x = f.min.x
      while x < f.max.x {
        let p : Point = { x, y }
        if !p.in_(g) {
          return false
        }
        x += 1
      }
      y += 1
    }
    true
  }
  let rects : Array[Rectangle] = [
    rect(0, 0, 10, 10),
    rect(10, 0, 20, 10),
    rect(1, 2, 3, 4),
    rect(4, 6, 10, 10),
    rect(2, 3, 12, 5),
    rect(-1, -2, 0, 0),
    rect(-1, -2, 4, 6),
    rect(-10, -20, 30, 40),
    rect(8, 8, 8, 8),
    rect(88, 88, 88, 88),
    rect(6, 5, 4, 3),
  ]
  // r.eq(s) should be equivalent to every point in r being in s and vice versa
  for r in rects {
    for s in rects {
      let got = r.eq(s)
      let want = rect_all_points_in(r, s) && rect_all_points_in(s, r)
      assert_eq!(got, want)
    }
  }
  // The intersection should be the largest rectangle a such that every point
  // in a is both in r and in s.
  for r in rects {
    for s in rects {
      let a = r.intersect(s)
      assert_true!(rect_all_points_in(a, r))
      assert_true!(rect_all_points_in(a, s))
      let is_zero = a.eq(
        { min: { x: 0, y: 0 }, max: { x: 0, y: 0 } },
      )
      let overlaps = r.overlaps(s)
      assert_true!(is_zero != overlaps)
      let larger : Array[Rectangle] = [
        { min: { x: a.min.x - 1, y: a.min.y }, max: a.max },
        { min: { x: a.min.x, y: a.min.y - 1 }, max: a.max },
        { min: a.min, max: { x: a.max.x + 1, y: a.max.y } },
        { min: a.min, max: { x: a.max.x, y: a.max.y + 1 } },
      ]
      for b in larger {
        if b.empty() {
          continue
        }
        if rect_all_points_in(b, r) && rect_all_points_in(b, s) {
          fail!("intersection could be larger")
        }
      }
    }
  }
  // The union should be the smallest rectangle a such that every point in r
  // is in a and every point in s is in a.
  for r in rects {
    for s in rects {
      let a = r.union(s)
      assert_true!(rect_all_points_in(r, a))
      assert_true!(rect_all_points_in(s, a))
      if a.empty() {
        continue
      }
      let smaller : Array[Rectangle] = [
        { min: { x: a.min.x + 1, y: a.min.y }, max: a.max },
        { min: { x: a.min.x, y: a.min.y + 1 }, max: a.max },
        { min: a.min, max: { x: a.max.x - 1, y: a.max.y } },
        { min: a.min, max: { x: a.max.x, y: a.max.y - 1 } },
      ]
      for b in smaller {
        if rect_all_points_in(r, b) && rect_all_points_in(s, b) {
          fail!("union could be smaller")
        }
      }
    }
  }
}
