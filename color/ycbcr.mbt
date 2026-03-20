///|
fn clamp_uint8(v : Int) -> Int {
  if (v.reinterpret_as_uint() & 0xff000000U) == 0U {
    v >> 16
  } else {
    (v >> 31).lnot()
  }
}

///|
fn clamp_uint16(v : Int) -> Int {
  if (v.reinterpret_as_uint() & 0xff000000U) == 0U {
    v >> 8
  } else {
    (v >> 31).lnot() & 0xffff
  }
}

///|
/// Converts an RGB triple to a Y'CbCr triple.
pub fn rgb_to_ycbcr(r : Byte, g : Byte, b : Byte) -> (Byte, Byte, Byte) {
  let r1 = r.to_int()
  let g1 = g.to_int()
  let b1 = b.to_int()
  let yy = (19595 * r1 + 38470 * g1 + 7471 * b1 + (1 << 15)) >> 16
  let cb = clamp_uint8(-11056 * r1 - 21712 * g1 + 32768 * b1 + (257 << 15))
  let cr = clamp_uint8(32768 * r1 - 27440 * g1 - 5328 * b1 + (257 << 15))
  (yy.to_byte(), cb.to_byte(), cr.to_byte())
}

///|
/// Converts a Y'CbCr triple to an RGB triple.
pub fn ycbcr_to_rgb(y : Byte, cb : Byte, cr : Byte) -> (Byte, Byte, Byte) {
  let yy1 = y.to_int() * 0x10101
  let cb1 = cb.to_int() - 128
  let cr1 = cr.to_int() - 128
  let r = clamp_uint8(yy1 + 91881 * cr1)
  let g = clamp_uint8(yy1 - 22554 * cb1 - 46802 * cr1)
  let b = clamp_uint8(yy1 + 116130 * cb1)
  (r.to_byte(), g.to_byte(), b.to_byte())
}

///|
/// YCbCr represents a fully opaque 24-bit Y'CbCr color.
#valtype
pub(all) struct YCbCr {
  y : Byte
  cb : Byte
  cr : Byte
} derive(Eq, Show)

///|
pub impl Color for YCbCr with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let yy1 = self.y.to_int() * 0x10101
  let cb1 = self.cb.to_int() - 128
  let cr1 = self.cr.to_int() - 128
  let r = clamp_uint16(yy1 + 91881 * cr1)
  let g = clamp_uint16(yy1 - 22554 * cb1 - 46802 * cr1)
  let b = clamp_uint16(yy1 + 116130 * cb1)
  (
    r.reinterpret_as_uint(),
    g.reinterpret_as_uint(),
    b.reinterpret_as_uint(),
    0xffffU,
  )
}

///|
/// NYCbCrA represents a non-alpha-premultiplied Y'CbCr-with-alpha color.
#valtype
pub(all) struct NYCbCrA {
  y : Byte
  cb : Byte
  cr : Byte
  a : Byte
} derive(Eq, Show)

///|
pub fn NYCbCrA::ycbcr(self : NYCbCrA) -> YCbCr {
  { y: self.y, cb: self.cb, cr: self.cr }
}

///|
pub impl Color for NYCbCrA with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let yy1 = self.y.to_int() * 0x10101
  let cb1 = self.cb.to_int() - 128
  let cr1 = self.cr.to_int() - 128
  let r = clamp_uint16(yy1 + 91881 * cr1).reinterpret_as_uint()
  let g = clamp_uint16(yy1 - 22554 * cb1 - 46802 * cr1).reinterpret_as_uint()
  let b = clamp_uint16(yy1 + 116130 * cb1).reinterpret_as_uint()
  let a = self.a.to_uint() * 0x101U
  (r * a / 0xffffU, g * a / 0xffffU, b * a / 0xffffU, a)
}

///|
/// Converts an RGB triple to a CMYK quadruple.
pub fn rgb_to_cmyk(r : Byte, g : Byte, b : Byte) -> (Byte, Byte, Byte, Byte) {
  let rr = r.to_uint()
  let gg = g.to_uint()
  let bb = b.to_uint()
  let mut w = rr
  if w < gg {
    w = gg
  }
  if w < bb {
    w = bb
  }
  if w == 0U {
    return (b'\x00', b'\x00', b'\x00', b'\xff')
  }
  let c = (w - rr) * 0xffU / w
  let m = (w - gg) * 0xffU / w
  let y = (w - bb) * 0xffU / w
  (c.to_byte(), m.to_byte(), y.to_byte(), (0xffU - w).to_byte())
}

///|
/// Converts a CMYK quadruple to an RGB triple.
pub fn cmyk_to_rgb(
  c : Byte,
  m : Byte,
  y : Byte,
  k : Byte,
) -> (Byte, Byte, Byte) {
  let w = 0xffffU - k.to_uint() * 0x101U
  let r = (0xffffU - c.to_uint() * 0x101U) * w / 0xffffU
  let g = (0xffffU - m.to_uint() * 0x101U) * w / 0xffffU
  let b = (0xffffU - y.to_uint() * 0x101U) * w / 0xffffU
  ((r >> 8).to_byte(), (g >> 8).to_byte(), (b >> 8).to_byte())
}

///|
/// CMYK represents a fully opaque CMYK color, having 8 bits for each of cyan,
/// magenta, yellow and black.
#valtype
pub(all) struct CMYK {
  c : Byte
  m : Byte
  y : Byte
  k : Byte
} derive(Eq, Show)

///|
pub impl Color for CMYK with rgba(self) -> (UInt, UInt, UInt, UInt) {
  let w = 0xffffU - self.k.to_uint() * 0x101U
  let r = (0xffffU - self.c.to_uint() * 0x101U) * w / 0xffffU
  let g = (0xffffU - self.m.to_uint() * 0x101U) * w / 0xffffU
  let b = (0xffffU - self.y.to_uint() * 0x101U) * w / 0xffffU
  (r, g, b, 0xffffU)
}
