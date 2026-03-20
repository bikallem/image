///|
/// Port of Go's TestSqDiff from color/color_test.go.
/// Verifies sq_diff matches canonical abs(x-y)^2 >> 2 for edge values.
test "sq_diff" {
  fn canonical(x : UInt, y : UInt) -> UInt {
    let d = if x > y { x - y } else { y - x }
    (d * d) >> 2
  }
  let cases : Array[UInt] = [
    0, 1, 2, 0x0fffd, 0x0fffe, 0x0ffff, 0x10000, 0x10001, 0x10002, 0xfffffffd, 0xfffffffe,
    0xffffffff,
  ]
  for x in cases {
    for y in cases {
      let got = sq_diff(x, y)
      let want = canonical(x, y)
      assert_eq(got, want)
    }
  }
}
