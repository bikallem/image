///|
/// Model can convert any Color to one from its own color model.
pub(open) trait Model {
  convert(Self, &Color) -> &Color
  palette(Self) -> Palette? = _
}

///|
impl Model with palette(_self) -> Palette? {
  None
}

///|
pub(all) struct RGBAModel {} derive(Debug)

///|
pub impl Model for RGBAModel with convert(_self, c) -> &Color {
  let (r, g, b, a) = c.rgba()
  RGBA::{
    r: (r >> 8).to_byte(),
    g: (g >> 8).to_byte(),
    b: (b >> 8).to_byte(),
    a: (a >> 8).to_byte(),
  }
}

///|
pub(all) struct RGBA64Model {} derive(Debug)

///|
pub impl Model for RGBA64Model with convert(_self, c) -> &Color {
  let (r, g, b, a) = c.rgba()
  RGBA64::{ r, g, b, a }
}

///|
pub(all) struct NRGBAModel {} derive(Debug)

///|
pub impl Model for NRGBAModel with convert(_self, c) -> &Color {
  let (r, g, b, a) = c.rgba()
  if a == 0xffffU {
    return NRGBA::{
      r: (r >> 8).to_byte(),
      g: (g >> 8).to_byte(),
      b: (b >> 8).to_byte(),
      a: b'\xff',
    }
  }
  if a == 0U {
    return NRGBA::{ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }
  }
  let r = r * 0xffffU / a
  let g = g * 0xffffU / a
  let b = b * 0xffffU / a
  NRGBA::{
    r: (r >> 8).to_byte(),
    g: (g >> 8).to_byte(),
    b: (b >> 8).to_byte(),
    a: (a >> 8).to_byte(),
  }
}

///|
pub(all) struct NRGBA64Model {} derive(Debug)

///|
pub impl Model for NRGBA64Model with convert(_self, c) -> &Color {
  let (r, g, b, a) = c.rgba()
  if a == 0xffffU {
    return NRGBA64::{ r, g, b, a: 0xffffU }
  }
  if a == 0U {
    return NRGBA64::{ r: 0U, g: 0U, b: 0U, a: 0U }
  }
  let r = r * 0xffffU / a
  let g = g * 0xffffU / a
  let b = b * 0xffffU / a
  NRGBA64::{ r, g, b, a }
}

///|
pub(all) struct AlphaModel {} derive(Debug)

///|
pub impl Model for AlphaModel with convert(_self, c) -> &Color {
  let (_, _, _, a) = c.rgba()
  Alpha::{ a: (a >> 8).to_byte() }
}

///|
pub(all) struct Alpha16Model {} derive(Debug)

///|
pub impl Model for Alpha16Model with convert(_self, c) -> &Color {
  let (_, _, _, a) = c.rgba()
  Alpha16::{ a, }
}

///|
pub(all) struct GrayModel {} derive(Debug)

///|
pub impl Model for GrayModel with convert(_self, c) -> &Color {
  let (r, g, b, _) = c.rgba()
  let y = (19595U * r + 38470U * g + 7471U * b + (1U << 15)) >> 24
  Gray::{ y: y.to_byte() }
}

///|
pub(all) struct Gray16Model {} derive(Debug)

///|
pub impl Model for Gray16Model with convert(_self, c) -> &Color {
  let (r, g, b, _) = c.rgba()
  let y = (19595U * r + 38470U * g + 7471U * b + (1U << 15)) >> 16
  Gray16::{ y, }
}

///|
pub(all) struct YCbCrModel {} derive(Debug)

///|
pub impl Model for YCbCrModel with convert(_self, c) -> &Color {
  let (r, g, b, _) = c.rgba()
  let (yy, cb, cr) = rgb_to_ycbcr(
    (r >> 8).to_byte(),
    (g >> 8).to_byte(),
    (b >> 8).to_byte(),
  )
  YCbCr::{ y: yy, cb, cr }
}

///|
pub(all) struct NYCbCrAModel {} derive(Debug)

///|
pub impl Model for NYCbCrAModel with convert(_self, c) -> &Color {
  let (r, g, b, a) = c.rgba()
  let (rr, gg, bb) = if a != 0U {
    (r * 0xffffU / a, g * 0xffffU / a, b * 0xffffU / a)
  } else {
    (r, g, b)
  }
  let (yy, cb, cr) = rgb_to_ycbcr(
    (rr >> 8).to_byte(),
    (gg >> 8).to_byte(),
    (bb >> 8).to_byte(),
  )
  NYCbCrA::{ y: yy, cb, cr, a: (a >> 8).to_byte() }
}

///|
pub(all) struct CMYKModel {} derive(Debug)

///|
pub impl Model for CMYKModel with convert(_self, c) -> &Color {
  let (r, g, b, _) = c.rgba()
  let (cc, mm, yy, kk) = rgb_to_cmyk(
    (r >> 8).to_byte(),
    (g >> 8).to_byte(),
    (b >> 8).to_byte(),
  )
  CMYK::{ c: cc, m: mm, y: yy, k: kk }
}

///|
pub(all) struct PaletteModel {
  palette : Palette
}

///|
pub impl Model for PaletteModel with palette(self) -> Palette? {
  Some(self.palette)
}

///|
pub impl Model for PaletteModel with convert(self, c) -> &Color {
  match self.palette.convert(c) {
    Some(v) => v
    None => RGBA::{ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }
  }
}
