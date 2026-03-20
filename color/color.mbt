///|
/// Color can convert itself to alpha-premultiplied 16-bits per channel RGBA.
/// The conversion may be lossy.
pub(open) trait Color {
  rgba(Self) -> (UInt, UInt, UInt, UInt)
}

///|
/// RGBA represents a traditional 32-bit alpha-premultiplied color, having 8
/// bits for each of red, green, blue and alpha.
pub(all) struct RGBA {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Show)

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
pub(all) struct RGBA64 {
  r : UInt
  g : UInt
  b : UInt
  a : UInt
} derive(Eq, Show)

///|
pub impl Color for RGBA64 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  (self.r & 0xffffU, self.g & 0xffffU, self.b & 0xffffU, self.a & 0xffffU)
}

///|
/// NRGBA represents a non-alpha-premultiplied 32-bit color.
pub(all) struct NRGBA {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Show)

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
pub(all) struct NRGBA64 {
  r : UInt
  g : UInt
  b : UInt
  a : UInt
} derive(Eq, Show)

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
pub(all) struct Alpha {
  a : Byte
} derive(Eq, Show)

///|
pub impl Color for Alpha with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let a = self.a.to_uint()
  let a = a | (a << 8)
  (a, a, a, a)
}

///|
/// Alpha16 represents a 16-bit alpha color.
pub(all) struct Alpha16 {
  a : UInt
} derive(Eq, Show)

///|
pub impl Color for Alpha16 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let a = self.a & 0xffffU
  (a, a, a, a)
}

///|
/// Gray represents an 8-bit grayscale color.
pub(all) struct Gray {
  y : Byte
} derive(Eq, Show)

///|
pub impl Color for Gray with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let y = self.y.to_uint()
  let y = y | (y << 8)
  (y, y, y, 0xffffU)
}

///|
/// Gray16 represents a 16-bit grayscale color.
pub(all) struct Gray16 {
  y : UInt
} derive(Eq, Show)

///|
pub impl Color for Gray16 with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let y = self.y & 0xffffU
  (y, y, y, 0xffffU)
}

///|
/// AnyColor is a closed enum of all standard color types.
pub(all) enum AnyColor {
  RGBA(RGBA)
  RGBA64(RGBA64)
  NRGBA(NRGBA)
  NRGBA64(NRGBA64)
  Alpha(Alpha)
  Alpha16(Alpha16)
  Gray(Gray)
  Gray16(Gray16)
  YCbCr(YCbCr)
  NYCbCrA(NYCbCrA)
  CMYK(CMYK)
} derive(Eq, Show)

///|
pub impl Color for AnyColor with rgba(self) -> (UInt, UInt, UInt, UInt) {
  match self {
    RGBA(c) => c.rgba()
    RGBA64(c) => c.rgba()
    NRGBA(c) => c.rgba()
    NRGBA64(c) => c.rgba()
    Alpha(c) => c.rgba()
    Alpha16(c) => c.rgba()
    Gray(c) => c.rgba()
    Gray16(c) => c.rgba()
    YCbCr(c) => c.rgba()
    NYCbCrA(c) => c.rgba()
    CMYK(c) => c.rgba()
  }
}

///|
/// Standard color constants matching Go's color package.
pub let black : AnyColor = AnyColor::Gray16({ y: 0 })

///|
pub let white : AnyColor = AnyColor::Gray16({ y: 0xffff })

///|
pub let transparent : AnyColor = AnyColor::Alpha16({ a: 0 })

///|
pub let opaque : AnyColor = AnyColor::Alpha16({ a: 0xffff })

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
  colors : Array[AnyColor]
} derive(Show)

///|
/// Returns the palette color closest to c in Euclidean R,G,B,A space.
pub fn Palette::convert(self : Palette, c : AnyColor) -> AnyColor? {
  if self.colors.is_empty() {
    return None
  }
  Some(self.colors[self.index(c)])
}

///|
/// Returns the index of the palette color closest to c in Euclidean R,G,B,A space.
pub fn Palette::index(self : Palette, c : AnyColor) -> Int {
  let (cr, cg, cb, ca) = c.rgba()
  let mut ret = 0
  let mut best_sum : UInt = 0xffffffffU
  for i, v in self.colors {
    let (vr, vg, vb, va) = v.rgba()
    let sum = sq_diff(cr, vr) + sq_diff(cg, vg) + sq_diff(cb, vb) +
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
