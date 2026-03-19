///|
let max_color : UInt = 0xffffU

///|
/// Op is a Porter-Duff compositing operator.
pub(all) enum Op {
  Over
  Src
} derive(Eq, Show)

///|
pub fn draw(
  dst : @image.AnyImage,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
  op : Op
) -> Unit {
  draw_mask(dst, r, src, sp, None, { x: 0, y: 0 }, op)
}

///|
fn clip(
  dst : @image.AnyImage,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
  mask : @image.AnyImage?,
  mp : @image.Point
) -> (@image.Rectangle, @image.Point, @image.Point) {
  let orig = r.min
  let mut r2 = r.intersect(dst.bounds())
  r2 = r2.intersect(src.bounds().add(orig.sub(sp)))
  match mask {
    Some(mask_img) =>
      r2 = r2.intersect(mask_img.bounds().add(orig.sub(mp)))
    None => ()
  }
  let dx = r2.min.x - orig.x
  let dy = r2.min.y - orig.y
  let sp2 : @image.Point = { x: sp.x + dx, y: sp.y + dy }
  let mp2 : @image.Point = { x: mp.x + dx, y: mp.y + dy }
  (r2, sp2, mp2)
}

///|
pub fn draw_mask(
  dst : @image.AnyImage,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
  mask : @image.AnyImage?,
  mp : @image.Point,
  op : Op
) -> Unit {
  let (r, sp, mp) = clip(dst, r, src, sp, mask, mp)
  if r.empty() {
    return
  }
  match (dst, mask) {
    (@image.AnyImage::RGBA(dst0), None) => {
      match src {
        @image.AnyImage::Uniform(u) => {
          let (sr, sg, sb, sa) = u.c.rgba()
          if op == Src || sa == 0xffffU {
            draw_fill_src(dst0, r, sr, sg, sb, sa)
          } else {
            draw_fill_over(dst0, r, sr, sg, sb, sa)
          }
          return
        }
        @image.AnyImage::RGBA(src0) =>
          if op == Src {
            draw_copy_src(dst0, r, src0, sp)
            return
          } else {
            draw_copy_over(dst0, r, src0, sp)
            return
          }
        @image.AnyImage::YCbCr(src0) => {
          @imageutil.draw_ycbcr(dst0, r, src0, sp)
          return
        }
        _ => ()
      }
      draw_rgba(dst0, r, src, sp, mask, op)
      return
    }
    _ => ()
  }
  draw_generic(dst, r, src, sp, mask, mp, op)
}

///|
fn draw_fill_src(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  sr : UInt,
  sg : UInt,
  sb : UInt,
  sa : UInt
) -> Unit {
  let r_byte = (sr >> 8).to_byte()
  let g_byte = (sg >> 8).to_byte()
  let b_byte = (sb >> 8).to_byte()
  let a_byte = (sa >> 8).to_byte()
  for y = r.min.y; y < r.max.y; y = y + 1 {
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let i = dst.pix_offset(x, y)
      dst.pix[i] = r_byte
      dst.pix[i + 1] = g_byte
      dst.pix[i + 2] = b_byte
      dst.pix[i + 3] = a_byte
    }
  }
}

///|
fn draw_fill_over(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  sr : UInt,
  sg : UInt,
  sb : UInt,
  sa : UInt
) -> Unit {
  let a = max_color - sa
  for y = r.min.y; y < r.max.y; y = y + 1 {
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let i = dst.pix_offset(x, y)
      let dr = dst.pix[i].to_uint()
      let dg = dst.pix[i + 1].to_uint()
      let db = dst.pix[i + 2].to_uint()
      let da = dst.pix[i + 3].to_uint()
      dst.pix[i] = ((dr * a / max_color + sr) >> 8).to_byte()
      dst.pix[i + 1] = ((dg * a / max_color + sg) >> 8).to_byte()
      dst.pix[i + 2] = ((db * a / max_color + sb) >> 8).to_byte()
      dst.pix[i + 3] = ((da * a / max_color + sa) >> 8).to_byte()
    }
  }
}

///|
fn draw_copy_src(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageRGBA,
  sp : @image.Point
) -> Unit {
  for y = r.min.y; y < r.max.y; y = y + 1 {
    let sy = sp.y + y - r.min.y
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let sx = sp.x + x - r.min.x
      let si = src.pix_offset(sx, sy)
      let di = dst.pix_offset(x, y)
      dst.pix[di] = src.pix[si]
      dst.pix[di + 1] = src.pix[si + 1]
      dst.pix[di + 2] = src.pix[si + 2]
      dst.pix[di + 3] = src.pix[si + 3]
    }
  }
}

///|
fn draw_copy_over(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageRGBA,
  sp : @image.Point
) -> Unit {
  for y = r.min.y; y < r.max.y; y = y + 1 {
    let sy = sp.y + y - r.min.y
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let sx = sp.x + x - r.min.x
      let si = src.pix_offset(sx, sy)
      let sa = src.pix[si + 3].to_uint()
      let sa16 = sa | (sa << 8)
      let a = max_color - sa16
      let di = dst.pix_offset(x, y)
      let sr16 = src.pix[si].to_uint()
      let sr16 = sr16 | (sr16 << 8)
      let sg16 = src.pix[si + 1].to_uint()
      let sg16 = sg16 | (sg16 << 8)
      let sb16 = src.pix[si + 2].to_uint()
      let sb16 = sb16 | (sb16 << 8)
      let dr = dst.pix[di].to_uint()
      let dg = dst.pix[di + 1].to_uint()
      let db = dst.pix[di + 2].to_uint()
      let da = dst.pix[di + 3].to_uint()
      let dr16 = dr | (dr << 8)
      let dg16 = dg | (dg << 8)
      let db16 = db | (db << 8)
      let da16 = da | (da << 8)
      dst.pix[di] = ((dr16 * a / max_color + sr16) >> 8).to_byte()
      dst.pix[di + 1] = ((dg16 * a / max_color + sg16) >> 8).to_byte()
      dst.pix[di + 2] = ((db16 * a / max_color + sb16) >> 8).to_byte()
      dst.pix[di + 3] = ((da16 * a / max_color + sa16) >> 8).to_byte()
    }
  }
}

///|
fn draw_rgba(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
  mask : @image.AnyImage?,
  op : Op
) -> Unit {
  for y = r.min.y; y < r.max.y; y = y + 1 {
    let sy = sp.y + y - r.min.y
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let sx = sp.x + x - r.min.x
      let (sr0, sg0, sb0, sa0) = src.at(sx, sy).rgba()
      let (sr, sg, sb, sa) = match mask {
        Some(mask_img) => {
          let (_, _, _, ma) = mask_img.at(x, y).rgba()
          (
            sr0 * ma / max_color,
            sg0 * ma / max_color,
            sb0 * ma / max_color,
            sa0 * ma / max_color,
          )
        }
        None => (sr0, sg0, sb0, sa0)
      }
      let di = dst.pix_offset(x, y)
      if op == Over {
        let a = max_color - sa
        let dr = dst.pix[di].to_uint()
        let dg = dst.pix[di + 1].to_uint()
        let db = dst.pix[di + 2].to_uint()
        let da = dst.pix[di + 3].to_uint()
        let dr16 = dr | (dr << 8)
        let dg16 = dg | (dg << 8)
        let db16 = db | (db << 8)
        let da16 = da | (da << 8)
        dst.pix[di] = ((dr16 * a / max_color + sr) >> 8).to_byte()
        dst.pix[di + 1] = ((dg16 * a / max_color + sg) >> 8).to_byte()
        dst.pix[di + 2] = ((db16 * a / max_color + sb) >> 8).to_byte()
        dst.pix[di + 3] = ((da16 * a / max_color + sa) >> 8).to_byte()
      } else {
        dst.pix[di] = (sr >> 8).to_byte()
        dst.pix[di + 1] = (sg >> 8).to_byte()
        dst.pix[di + 2] = (sb >> 8).to_byte()
        dst.pix[di + 3] = (sa >> 8).to_byte()
      }
    }
  }
}

///|
fn draw_generic(
  dst : @image.AnyImage,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
  mask : @image.AnyImage?,
  mp : @image.Point,
  op : Op
) -> Unit {
  for y = r.min.y; y < r.max.y; y = y + 1 {
    let sy = sp.y + y - r.min.y
    let my = mp.y + y - r.min.y
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let sx = sp.x + x - r.min.x
      let mx = mp.x + x - r.min.x
      let (sr0, sg0, sb0, sa0) = src.at(sx, sy).rgba()
      let (sr1, sg1, sb1, sa1) = match mask {
        Some(mask_img) => {
          let (_, _, _, ma) = mask_img.at(mx, my).rgba()
          (
            sr0 * ma / max_color,
            sg0 * ma / max_color,
            sb0 * ma / max_color,
            sa0 * ma / max_color,
          )
        }
        None => (sr0, sg0, sb0, sa0)
      }
      let (sr, sg, sb, sa) = if op == Over {
        let (dr, dg, db, da) = dst.at(x, y).rgba()
        let a = max_color - sa1
        (
          dr * a / max_color + sr1,
          dg * a / max_color + sg1,
          db * a / max_color + sb1,
          da * a / max_color + sa1,
        )
      } else {
        (sr1, sg1, sb1, sa1)
      }
      match dst {
        @image.AnyImage::RGBA(img) =>
          img.set_rgba(
            x,
            y,
            {
              r: (sr >> 8).to_byte(),
              g: (sg >> 8).to_byte(),
              b: (sb >> 8).to_byte(),
              a: (sa >> 8).to_byte(),
            },
          )
        @image.AnyImage::Gray(img) => {
          let yy = (19595U * sr + 38470U * sg + 7471U * sb + (1U << 15)) >> 24
          img.set_gray(x, y, { y: yy.to_byte() })
        }
        @image.AnyImage::Paletted(img) => {
          let c = @color.AnyColor::RGBA64({ r: sr, g: sg, b: sb, a: sa })
          let idx = img.palette.index(c)
          img.set_color_index(x, y, idx.to_byte())
        }
        _ => ()
      }
    }
  }
}
