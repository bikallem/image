///|
fn clamp_uint8(v : Int) -> Int {
  if (v.reinterpret_as_uint() & 0xff000000U) == 0U {
    v >> 8
  } else {
    (v.reinterpret_as_uint() >> 31).reinterpret_as_int().lnot() & 0xffff
  }
}

///|
/// Draws YCbCr source pixels onto an RGBA destination.
pub fn draw_ycbcr(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageYCbCr,
  sp : @image.Point,
) -> Unit {
  let x0 = r.min.x
  let x1 = r.max.x
  let y0 = r.min.y
  let y1 = r.max.y
  for y = y0; y < y1; y = y + 1 {
    let sy = sp.y + y - y0
    for x = x0; x < x1; x = x + 1 {
      let sx = sp.x + x - x0
      let yi = src.y_offset(sx, sy)
      let ci = src.c_offset(sx, sy)
      let yy1 = src.y_[yi].to_int() * 0x10101
      let cb1 = src.cb[ci].to_int() - 128
      let cr1 = src.cr[ci].to_int() - 128
      let rr = clamp_uint8(yy1 + 91881 * cr1)
      let gg = clamp_uint8(yy1 - 22554 * cb1 - 46802 * cr1)
      let bb = clamp_uint8(yy1 + 116130 * cb1)
      let di = dst.pix_offset(x, y)
      dst.pix[di] = (rr >> 8).to_byte()
      dst.pix[di + 1] = (gg >> 8).to_byte()
      dst.pix[di + 2] = (bb >> 8).to_byte()
      dst.pix[di + 3] = b'\xff'
    }
  }
}
