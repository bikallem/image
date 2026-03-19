///|
test "RGBA.rgba" {
  let c : @color.RGBA = { r: b'\x80', g: b'\x40', b: b'\xc0', a: b'\xff' }
  let (r, g, b, a) = c.rgba()
  inspect(r, content="32896")
  inspect(g, content="16448")
  inspect(b, content="49344")
  inspect(a, content="65535")
}

///|
test "NRGBA.rgba premultiply" {
  let c : @color.NRGBA = { r: b'\xff', g: b'\x00', b: b'\x00', a: b'\x80' }
  let (r, _g, _b, a) = c.rgba()
  inspect(r, content="32896")
  inspect(a, content="32896")
}

///|
test "Gray.rgba" {
  let c : @color.Gray = { y: b'\x80' }
  let (r, g, b, a) = c.rgba()
  inspect(r, content="32896")
  inspect(g, content="32896")
  inspect(b, content="32896")
  inspect(a, content="65535")
}

///|
test "YCbCr round-trip" {
  // YCbCr conversion is lossy, so we test a known value
  let (y, cb, cr) = @color.rgb_to_ycbcr(b'\xff', b'\x00', b'\x00')
  let (r, g, b) = @color.ycbcr_to_rgb(y, cb, cr)
  // Red -> YCbCr -> RGB loses a bit
  inspect(r, content="b'\\xFE'")
  inspect(g, content="b'\\x00'")
  inspect(b, content="b'\\x00'")
}

///|
test "CMYK round-trip" {
  let (c, m, y, k) = @color.rgb_to_cmyk(b'\xff', b'\x80', b'\x00')
  let (r, g, b) = @color.cmyk_to_rgb(c, m, y, k)
  inspect(r, content="b'\\xFF'")
  inspect(g, content="b'\\x80'")
  inspect(b, content="b'\\x00'")
}

///|
test "model convert RGBA->Gray" {
  let c = @color.AnyColor::RGBA(
    { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' },
  )
  let g = @color.AnyModel::GrayModel.convert(c)
  inspect(g, content="Gray({y: b'\\xFF'})")
}

///|
test "sq_diff" {
  inspect(@color.sq_diff(0x0U, 0x0U), content="0")
  inspect(@color.sq_diff(0xffffU, 0xffffU), content="0")
  // 0xffff^2 >> 2 = 65535*65535/4 = 1073709056 (with wrapping)
  inspect(@color.sq_diff(0xffffU, 0x0U), content="1073709056")
}
