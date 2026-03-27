///|
fn qc_small_coord(n : Int) -> Int {
  let m = n % 17
  let normalized = if m < 0 { m + 17 } else { m }
  normalized - 8
}

///|
fn qc_small_point(x : Int, y : Int) -> Point {
  { x: qc_small_coord(x), y: qc_small_coord(y) }
}

///|
fn qc_small_rect(coords : (Int, Int, Int, Int)) -> Rectangle {
  let (x0, y0, x1, y1) = coords
  rect(
    qc_small_coord(x0),
    qc_small_coord(y0),
    qc_small_coord(x1),
    qc_small_coord(y1),
  )
}

///|
fn prop_rectangle_commutative(
  input : ((Int, Int, Int, Int), (Int, Int, Int, Int)),
) -> Bool {
  let (lhs, rhs) = input
  let r = qc_small_rect(lhs)
  let s = qc_small_rect(rhs)
  r.intersect(s).eq(s.intersect(r)) && r.union(s).eq(s.union(r))
}

///|
fn prop_rectangle_add_sub_inverse(
  input : (Int, Int, Int, Int, Int, Int),
) -> Bool {
  let (x0, y0, x1, y1, px, py) = input
  let r = qc_small_rect((x0, y0, x1, y1))
  let p = qc_small_point(px, py)
  r.add(p).sub(p).eq(r) && r.sub(p).add(p).eq(r)
}

///|
test "rectangle_quickcheck" {
  @qc.quick_check_fn(prop_rectangle_commutative, max_success=200, max_size=24)
  @qc.quick_check_fn(
    prop_rectangle_add_sub_inverse,
    max_success=200,
    max_size=24,
  )
}
