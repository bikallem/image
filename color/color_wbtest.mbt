///|
test "RGBA.rgba" {
  let c : RGBA = { r: b'\x80', g: b'\x40', b: b'\xc0', a: b'\xff' }
  let (r, g, b, a) = c.rgba()
  inspect(r, content="32896")
  inspect(g, content="16448")
  inspect(b, content="49344")
  inspect(a, content="65535")
}

///|
test "NRGBA.rgba premultiply" {
  let c : NRGBA = { r: b'\xff', g: b'\x00', b: b'\x00', a: b'\x80' }
  let (r, _g, _b, a) = c.rgba()
  inspect(r, content="32896")
  inspect(a, content="32896")
}

///|
test "Gray.rgba" {
  let c : Gray = { y: b'\x80' }
  let (r, g, b, a) = c.rgba()
  inspect(r, content="32896")
  inspect(g, content="32896")
  inspect(b, content="32896")
  inspect(a, content="65535")
}

///|
test "model convert RGBA->Gray" {
  let c : RGBA = { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }
  let g = GrayModel::{  }.convert(c)
  let (r, gr, b, a) = g.rgba()
  // Gray{0xFF} -> rgba() gives (0xFF00|0xFF, ..., 0xFFFF)
  inspect(r, content="65535")
  inspect(gr, content="65535")
  inspect(b, content="65535")
  inspect(a, content="65535")
}
