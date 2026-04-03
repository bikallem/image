///|
/// Color can convert itself to alpha-premultiplied 16-bits per channel RGBA.
/// The conversion may be lossy.
pub(open) trait Color {
  rgba(Self) -> (UInt, UInt, UInt, UInt)
}

///|
/// RGBA represents a traditional 32-bit alpha-premultiplied color, having 8
/// bits for each of red, green, blue and alpha.
#valtype
pub(all) struct RGBA {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Debug)

///|
pub impl Color for RGBA with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let r = self.r.to_uint()
  let r = r | (r << 8)
  let g = self.g.to_uint()
  let g = g | (g << 8)
  let b = self.b.to_uint()
  let b = b | (b << 8)
  let a = self.a.to_uint()
  let a = a | (a << 8)
  (r, g, b, a)
}

///|
/// RGBA64 represents a 64-bit alpha-premultiplied color, having 16 bits for
/// each of red, green, blue and alpha.
#valtype
pub(all) struct RGBA64 {
  r : UInt
  g : UInt
  b : UInt
  a : UInt
} derive(Eq, Debug)

///|
pub impl Color for RGBA64 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  (self.r & 0xffffU, self.g & 0xffffU, self.b & 0xffffU, self.a & 0xffffU)
}

///|
/// NRGBA represents a non-alpha-premultiplied 32-bit color.
#valtype
pub(all) struct NRGBA {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Debug)

///|
pub impl Color for NRGBA with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let aa = self.a.to_uint()
  let r = self.r.to_uint()
  let r = (r | (r << 8)) * aa / 0xffU
  let g = self.g.to_uint()
  let g = (g | (g << 8)) * aa / 0xffU
  let b = self.b.to_uint()
  let b = (b | (b << 8)) * aa / 0xffU
  let a = aa | (aa << 8)
  (r, g, b, a)
}

///|
/// NRGBA64 represents a non-alpha-premultiplied 64-bit color,
/// having 16 bits for each of red, green, blue and alpha.
#valtype
pub(all) struct NRGBA64 {
  r : UInt
  g : UInt
  b : UInt
  a : UInt
} derive(Eq, Debug)

///|
pub impl Color for NRGBA64 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let a = self.a & 0xffffU
  let r = (self.r & 0xffffU) * a / 0xffffU
  let g = (self.g & 0xffffU) * a / 0xffffU
  let b = (self.b & 0xffffU) * a / 0xffffU
  (r, g, b, a)
}

///|
/// Alpha represents an 8-bit alpha color.
#valtype
pub(all) struct Alpha {
  a : Byte
} derive(Eq, Debug)

///|
pub impl Color for Alpha with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let a = self.a.to_uint()
  let a = a | (a << 8)
  (a, a, a, a)
}

///|
/// Alpha16 represents a 16-bit alpha color.
#valtype
pub(all) struct Alpha16 {
  a : UInt
} derive(Eq, Debug)

///|
pub impl Color for Alpha16 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let a = self.a & 0xffffU
  (a, a, a, a)
}

///|
/// Gray represents an 8-bit grayscale color.
#valtype
pub(all) struct Gray {
  y : Byte
} derive(Eq, Debug)

///|
pub impl Color for Gray with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let y = self.y.to_uint()
  let y = y | (y << 8)
  (y, y, y, 0xffffU)
}

///|
/// Gray16 represents a 16-bit grayscale color.
#valtype
pub(all) struct Gray16 {
  y : UInt
} derive(Eq, Debug)

///|
pub impl Color for Gray16 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let y = self.y & 0xffffU
  (y, y, y, 0xffffU)
}

///|
/// Standard color constants.
pub let black : Gray16 = { y: 0 }

///|
pub let white : Gray16 = { y: 0xffff }

///|
pub let transparent : Alpha16 = { a: 0 }

///|
pub let fully_opaque : Alpha16 = { a: 0xffff }

///|
/// sqDiff returns the squared-difference of x and y, shifted by 2 so that
/// adding four of those won't overflow a uint32.
/// x and y are both assumed to be in the range [0, 0xffff].
pub fn sq_diff(x : UInt, y : UInt) -> UInt {
  let d = x - y
  (d * d) >> 2
}

///|
/// Palette is a palette of colors.
pub(all) struct Palette {
  colors : Array[&Color]
}

///|
pub impl Show for Palette with output(self, logger) {
  logger.write_string("Palette(")
  logger.write_string(self.colors.length().to_string())
  logger.write_string(" colors)")
}

///|
/// Returns the palette color closest to c in Euclidean R,G,B,A space.
pub fn Palette::convert(self : Palette, c : &Color) -> &Color? {
  if self.colors.is_empty() {
    return None
  }
  Some(self.colors.unsafe_get(self.index(c)))
}

///|
/// Returns the index of the palette color closest to c in Euclidean R,G,B,A space.
pub fn Palette::index(self : Palette, c : &Color) -> Int {
  let (cr, cg, cb, ca) = c.rgba()
  let mut ret = 0
  let mut best_sum : UInt = 0xffffffffU
  for i, v in self.colors {
    let (vr, vg, vb, va) = v.rgba()
    let sum = sq_diff(cr, vr) +
      sq_diff(cg, vg) +
      sq_diff(cb, vb) +
      sq_diff(ca, va)
    if sum < best_sum {
      if sum == 0U {
        return i
      }
      ret = i
      best_sum = sum
    }
  }
  ret
}
