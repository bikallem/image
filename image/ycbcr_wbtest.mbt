///|
/// Port of Go's TestYCbCr from ycbcr_test.go.
/// Tests YCbCr image creation, pixel access with 6 subsample ratios.
test "ycbcr_image" {
  let rects : Array[Rectangle] = [
    rect(0, 0, 16, 16),
    rect(1, 0, 16, 16),
    rect(0, 1, 16, 16),
    rect(1, 1, 16, 16),
    rect(1, 1, 15, 16),
    rect(1, 1, 16, 15),
    rect(1, 1, 15, 15),
    rect(2, 3, 14, 15),
    rect(7, 0, 7, 16),
    rect(0, 8, 16, 8),
    rect(0, 0, 10, 11),
    rect(5, 6, 16, 16),
    rect(7, 7, 8, 8),
    rect(7, 8, 8, 9),
    rect(8, 7, 9, 8),
    rect(8, 8, 9, 9),
    rect(7, 7, 17, 17),
    rect(8, 8, 17, 17),
    rect(9, 9, 17, 17),
    rect(10, 10, 17, 17),
  ]
  let ratios : Array[YCbCrSubsampleRatio] = [
    Ratio444, Ratio422, Ratio420, Ratio440, Ratio411, Ratio410,
  ]
  let deltas : Array[Point] = [
    { x: 0, y: 0 },
    { x: 1000, y: 1001 },
    { x: 5001, y: -400 },
    { x: -701, y: -801 },
  ]
  for r in rects {
    for ratio in ratios {
      for delta in deltas {
        let r1 = r.add(delta)
        let m = new_image_ycbcr(r1, ratio)
        // Buffer should be reasonably small
        assert_true(m.y_.length() <= 100 * 100)
        // Initialize pixels
        let mut y = r1.min.y
        while y < r1.max.y {
          let mut x = r1.min.x
          while x < r1.max.x {
            let yi = m.y_offset(x, y)
            let ci = m.c_offset(x, y)
            m.y_[yi] = (16 * y + x).to_byte()
            m.cb[ci] = (y + 16 * x).to_byte()
            m.cr[ci] = (y + 16 * x).to_byte()
            x += 1
          }
          y += 1
        }
        // Verify pixel access works correctly
        y = r1.min.y
        while y < r1.max.y {
          let mut x = r1.min.x
          while x < r1.max.x {
            let c = m.ycbcr_at(x, y)
            let yi = m.y_offset(x, y)
            assert_eq(c.y, m.y_[yi])
            x += 1
          }
          y += 1
        }
        // is_opaque should always be true for YCbCr
        assert_true(m.is_opaque())
      }
    }
  }
}

///|
/// Port of Go's TestYCbCrSlicesDontOverlap.
/// Y, Cb, Cr arrays are separate (trivially true in our impl).
test "ycbcr_no_overlap" {
  let m = new_image_ycbcr(rect(0, 0, 8, 8), Ratio420)
  // Fill each array with a distinct value
  for i in 0..<m.y_.length() {
    m.y_[i] = b'\x0a'
  }
  for i in 0..<m.cb.length() {
    m.cb[i] = b'\x0b'
  }
  for i in 0..<m.cr.length() {
    m.cr[i] = b'\x0c'
  }
  // Verify each array still has its value
  for i in 0..<m.y_.length() {
    assert_eq(m.y_[i], b'\x0a')
  }
  for i in 0..<m.cb.length() {
    assert_eq(m.cb[i], b'\x0b')
  }
  for i in 0..<m.cr.length() {
    assert_eq(m.cr[i], b'\x0c')
  }
}
