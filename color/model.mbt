///|
/// AnyModel represents the standard color models.
pub(all) enum AnyModel {
  RGBAModel
  RGBA64Model
  NRGBAModel
  NRGBA64Model
  AlphaModel
  Alpha16Model
  GrayModel
  Gray16Model
  YCbCrModel
  NYCbCrAModel
  CMYKModel
  PaletteModel(Palette)
} derive(Show)

///|
/// Convert converts the given color to the model's color type.
pub fn AnyModel::convert(self : AnyModel, c : AnyColor) -> AnyColor {
  match self {
    RGBAModel => rgba_model(c)
    RGBA64Model => rgba64_model(c)
    NRGBAModel => nrgba_model(c)
    NRGBA64Model => nrgba64_model(c)
    AlphaModel => alpha_model(c)
    Alpha16Model => alpha16_model(c)
    GrayModel => gray_model(c)
    Gray16Model => gray16_model(c)
    YCbCrModel => ycbcr_model(c)
    NYCbCrAModel => nycbcra_model(c)
    CMYKModel => cmyk_model(c)
    PaletteModel(p) =>
      match p.convert(c) {
        Some(v) => v
        None =>
          AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' })
      }
  }
}

///|
fn rgba_model(c : AnyColor) -> AnyColor {
  if c is RGBA(_) {
    return c
  }
  let (r, g, b, a) = c.rgba()
  AnyColor::RGBA({
    r: (r >> 8).to_byte(),
    g: (g >> 8).to_byte(),
    b: (b >> 8).to_byte(),
    a: (a >> 8).to_byte(),
  })
}

///|
fn rgba64_model(c : AnyColor) -> AnyColor {
  if c is RGBA64(_) {
    return c
  }
  let (r, g, b, a) = c.rgba()
  AnyColor::RGBA64({ r, g, b, a })
}

///|
fn nrgba_model(c : AnyColor) -> AnyColor {
  if c is NRGBA(_) {
    return c
  }
  let (r, g, b, a) = c.rgba()
  if a == 0xffffU {
    return AnyColor::NRGBA({
      r: (r >> 8).to_byte(),
      g: (g >> 8).to_byte(),
      b: (b >> 8).to_byte(),
      a: b'\xff',
    })
  }
  if a == 0U {
    return AnyColor::NRGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' })
  }
  let r = r * 0xffffU / a
  let g = g * 0xffffU / a
  let b = b * 0xffffU / a
  AnyColor::NRGBA({
    r: (r >> 8).to_byte(),
    g: (g >> 8).to_byte(),
    b: (b >> 8).to_byte(),
    a: (a >> 8).to_byte(),
  })
}

///|
fn nrgba64_model(c : AnyColor) -> AnyColor {
  if c is NRGBA64(_) {
    return c
  }
  let (r, g, b, a) = c.rgba()
  if a == 0xffffU {
    return AnyColor::NRGBA64({ r, g, b, a: 0xffffU })
  }
  if a == 0U {
    return AnyColor::NRGBA64({ r: 0U, g: 0U, b: 0U, a: 0U })
  }
  let r = r * 0xffffU / a
  let g = g * 0xffffU / a
  let b = b * 0xffffU / a
  AnyColor::NRGBA64({ r, g, b, a })
}

///|
fn alpha_model(c : AnyColor) -> AnyColor {
  if c is Alpha(_) {
    return c
  }
  let (_, _, _, a) = c.rgba()
  AnyColor::Alpha({ a: (a >> 8).to_byte() })
}

///|
fn alpha16_model(c : AnyColor) -> AnyColor {
  if c is Alpha16(_) {
    return c
  }
  let (_, _, _, a) = c.rgba()
  AnyColor::Alpha16({ a, })
}

///|
fn gray_model(c : AnyColor) -> AnyColor {
  if c is Gray(_) {
    return c
  }
  let (r, g, b, _) = c.rgba()
  let y = (19595U * r + 38470U * g + 7471U * b + (1U << 15)) >> 24
  AnyColor::Gray({ y: y.to_byte() })
}

///|
fn gray16_model(c : AnyColor) -> AnyColor {
  if c is Gray16(_) {
    return c
  }
  let (r, g, b, _) = c.rgba()
  let y = (19595U * r + 38470U * g + 7471U * b + (1U << 15)) >> 16
  AnyColor::Gray16({ y, })
}

///|
fn ycbcr_model(c : AnyColor) -> AnyColor {
  if c is YCbCr(_) {
    return c
  }
  let (r, g, b, _) = c.rgba()
  let (yy, cb, cr) = rgb_to_ycbcr(
    (r >> 8).to_byte(),
    (g >> 8).to_byte(),
    (b >> 8).to_byte(),
  )
  AnyColor::YCbCr({ y: yy, cb, cr })
}

///|
fn nycbcra_model(c : AnyColor) -> AnyColor {
  match c {
    NYCbCrA(_) => c
    YCbCr(yc) => AnyColor::NYCbCrA({ y: yc.y, cb: yc.cb, cr: yc.cr, a: b'\xff' })
    _ => {
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
      AnyColor::NYCbCrA({ y: yy, cb, cr, a: (a >> 8).to_byte() })
    }
  }
}

///|
fn cmyk_model(c : AnyColor) -> AnyColor {
  if c is CMYK(_) {
    return c
  }
  let (r, g, b, _) = c.rgba()
  let (cc, mm, yy, kk) = rgb_to_cmyk(
    (r >> 8).to_byte(),
    (g >> 8).to_byte(),
    (b >> 8).to_byte(),
  )
  AnyColor::CMYK({ c: cc, m: mm, y: yy, k: kk })
}
