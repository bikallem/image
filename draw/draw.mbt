///|
let max_color : UInt = 0xffffU

///|
/// Fast division by 65535: exact for all uint32 inputs in [0, 65535*65535].
fn div65535(x : UInt) -> UInt {
  (x + (x >> 16) + 1U) >> 16
}

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
  op : Op,
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
  mp : @image.Point,
) -> (@image.Rectangle, @image.Point, @image.Point) {
  let orig = r.min()
  let mut r2 = r.intersect(dst.bounds())
  r2 = r2.intersect(src.bounds().add(orig.sub(sp)))
  match mask {
    Some(mask_img) => r2 = r2.intersect(mask_img.bounds().add(orig.sub(mp)))
    None => ()
  }
  let dx = r2.min_x - orig.x
  let dy = r2.min_y - orig.y
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
  op : Op,
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
        @image.AnyImage::NRGBA(src0) => {
          draw_nrgba(dst0, r, src0, sp, op)
          return
        }
        @image.AnyImage::Gray(src0) => {
          draw_gray(dst0, r, src0, sp)
          return
        }
        _ => ()
      }
      draw_rgba(dst0, r, src, sp, mask, op)
      return
    }
    // Paletted destination fast paths
    (@image.AnyImage::Paletted(dst0), None) =>
      match src {
        @image.AnyImage::Uniform(u) => {
          // Uniform fill: find palette index once, fill with that byte
          let idx = dst0.palette.index(u.c).to_byte()
          let dx = r.dx()
          let mut row_off = dst0.pix_offset +
            (r.min_y - dst0.rect.min_y) * dst0.stride +
            (r.min_x - dst0.rect.min_x)
          for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
            for i = 0; i < dx; i = i + 1 {
              dst0.pix.unsafe_set(row_off + i, idx)
            }
            row_off += dst0.stride
          }
          return
        }
        _ => {
          // For non-uniform: look up palette index per pixel
          draw_paletted(dst0, r, src, sp)
          return
        }
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
  sa : UInt,
) -> Unit {
  let r_byte = (sr >> 8).to_byte()
  let g_byte = (sg >> 8).to_byte()
  let b_byte = (sb >> 8).to_byte()
  let a_byte = (sa >> 8).to_byte()
  let dx = r.dx()
  let n = dx * 4
  let mut row_off = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  if r_byte == g_byte && g_byte == b_byte && b_byte == a_byte {
    // All channels same value — single memset per row
    for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
      @blit.fill_bytes(dst.pix, row_off, r_byte, n)
      row_off += dst.stride
    }
  } else {
    // Fill first row pixel by pixel, then blit to remaining rows
    let mut i = row_off
    for _x = 0; _x < dx; _x = _x + 1 {
      dst.pix.unsafe_set(i, r_byte)
      dst.pix.unsafe_set(i + 1, g_byte)
      dst.pix.unsafe_set(i + 2, b_byte)
      dst.pix.unsafe_set(i + 3, a_byte)
      i += 4
    }
    let first_row = row_off
    row_off += dst.stride
    for _y = r.min_y + 1; _y < r.max_y; _y = _y + 1 {
      @blit.blit_fixed_array(dst.pix, row_off, dst.pix, first_row, n)
      row_off += dst.stride
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
  sa : UInt,
) -> Unit {
  let a = max_color - sa
  let dx = r.dx()
  let mut row_off = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
    let mut i = row_off
    for _x = 0; _x < dx; _x = _x + 1 {
      let dr = dst.pix.unsafe_get(i).to_uint()
      let dg = dst.pix.unsafe_get(i + 1).to_uint()
      let db = dst.pix.unsafe_get(i + 2).to_uint()
      let da = dst.pix.unsafe_get(i + 3).to_uint()
      dst.pix.unsafe_set(i, ((div65535(dr * a) + sr) >> 8).to_byte())
      dst.pix.unsafe_set(i + 1, ((div65535(dg * a) + sg) >> 8).to_byte())
      dst.pix.unsafe_set(i + 2, ((div65535(db * a) + sb) >> 8).to_byte())
      dst.pix.unsafe_set(i + 3, ((div65535(da * a) + sa) >> 8).to_byte())
      i += 4
    }
    row_off += dst.stride
  }
}

///|
fn draw_copy_src(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageRGBA,
  sp : @image.Point,
) -> Unit {
  let dx = r.dx()
  let n = dx * 4
  let mut d_row = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let mut s_row = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 4
  for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
    @blit.blit_fixed_array(dst.pix, d_row, src.pix, s_row, n)
    d_row += dst.stride
    s_row += src.stride
  }
}

///|
fn draw_copy_over(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageRGBA,
  sp : @image.Point,
) -> Unit {
  let dx = r.dx()
  let mut d_row = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let mut s_row = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 4
  for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
    let mut di = d_row
    let mut si = s_row
    for _x = 0; _x < dx; _x = _x + 1 {
      let sa = src.pix.unsafe_get(si + 3).to_uint()
      let sa16 = sa | (sa << 8)
      let a = max_color - sa16
      let sr16 = src.pix.unsafe_get(si).to_uint()
      let sr16 = sr16 | (sr16 << 8)
      let sg16 = src.pix.unsafe_get(si + 1).to_uint()
      let sg16 = sg16 | (sg16 << 8)
      let sb16 = src.pix.unsafe_get(si + 2).to_uint()
      let sb16 = sb16 | (sb16 << 8)
      let dr = dst.pix.unsafe_get(di).to_uint()
      let dg = dst.pix.unsafe_get(di + 1).to_uint()
      let db = dst.pix.unsafe_get(di + 2).to_uint()
      let da = dst.pix.unsafe_get(di + 3).to_uint()
      let dr16 = dr | (dr << 8)
      let dg16 = dg | (dg << 8)
      let db16 = db | (db << 8)
      let da16 = da | (da << 8)
      dst.pix.unsafe_set(di, ((div65535(dr16 * a) + sr16) >> 8).to_byte())
      dst.pix.unsafe_set(di + 1, ((div65535(dg16 * a) + sg16) >> 8).to_byte())
      dst.pix.unsafe_set(di + 2, ((div65535(db16 * a) + sb16) >> 8).to_byte())
      dst.pix.unsafe_set(di + 3, ((div65535(da16 * a) + sa16) >> 8).to_byte())
      di += 4
      si += 4
    }
    d_row += dst.stride
    s_row += src.stride
  }
}

///|
fn draw_nrgba(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageNRGBA,
  sp : @image.Point,
  op : Op,
) -> Unit {
  let dx = r.dx()
  let mut d_row = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let mut s_row = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 4
  for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
    let mut di = d_row
    let mut si = s_row
    for _x = 0; _x < dx; _x = _x + 1 {
      let sa = src.pix.unsafe_get(si + 3).to_uint()
      if op == Src || sa == 0xff {
        // Premultiply and store
        let sr = src.pix.unsafe_get(si).to_uint() * sa / 0xffU
        let sg = src.pix.unsafe_get(si + 1).to_uint() * sa / 0xffU
        let sb = src.pix.unsafe_get(si + 2).to_uint() * sa / 0xffU
        dst.pix.unsafe_set(di, sr.to_byte())
        dst.pix.unsafe_set(di + 1, sg.to_byte())
        dst.pix.unsafe_set(di + 2, sb.to_byte())
        dst.pix.unsafe_set(di + 3, sa.to_byte())
      } else if sa > 0U {
        // Over compositing
        let sa16 = sa | (sa << 8)
        let a = max_color - sa16
        let sr = src.pix.unsafe_get(si).to_uint()
        let sr16 = sr * sa / 0xffU
        let sr16 = sr16 | (sr16 << 8)
        let sg = src.pix.unsafe_get(si + 1).to_uint()
        let sg16 = sg * sa / 0xffU
        let sg16 = sg16 | (sg16 << 8)
        let sb = src.pix.unsafe_get(si + 2).to_uint()
        let sb16 = sb * sa / 0xffU
        let sb16 = sb16 | (sb16 << 8)
        let dr = dst.pix.unsafe_get(di).to_uint()
        let dg = dst.pix.unsafe_get(di + 1).to_uint()
        let db = dst.pix.unsafe_get(di + 2).to_uint()
        let da = dst.pix.unsafe_get(di + 3).to_uint()
        dst.pix.unsafe_set(di, ((div65535(dr * a) + sr16) >> 8).to_byte())
        dst.pix.unsafe_set(di + 1, ((div65535(dg * a) + sg16) >> 8).to_byte())
        dst.pix.unsafe_set(di + 2, ((div65535(db * a) + sb16) >> 8).to_byte())
        dst.pix.unsafe_set(di + 3, ((div65535(da * a) + sa16) >> 8).to_byte())
      }
      di += 4
      si += 4
    }
    d_row += dst.stride
    s_row += src.stride
  }
}

///|
fn draw_gray(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageGray,
  sp : @image.Point,
) -> Unit {
  let dx = r.dx()
  let mut d_row = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let mut s_row = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x)
  for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
    let mut di = d_row
    let mut si = s_row
    for _x = 0; _x < dx; _x = _x + 1 {
      let y = src.pix.unsafe_get(si)
      dst.pix.unsafe_set(di, y)
      dst.pix.unsafe_set(di + 1, y)
      dst.pix.unsafe_set(di + 2, y)
      dst.pix.unsafe_set(di + 3, b'\xff')
      di += 4
      si += 1
    }
    d_row += dst.stride
    s_row += src.stride
  }
}

///|
fn draw_rgba(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
  mask : @image.AnyImage?,
  op : Op,
) -> Unit {
  for y = r.min_y; y < r.max_y; y = y + 1 {
    let sy = sp.y + y - r.min_y
    for x = r.min_x; x < r.max_x; x = x + 1 {
      let sx = sp.x + x - r.min_x
      let (sr0, sg0, sb0, sa0) = src.at(sx, sy).rgba()
      let (sr, sg, sb, sa) = match mask {
        Some(mask_img) => {
          let (_, _, _, ma) = mask_img.at(x, y).rgba()
          (
            div65535(sr0 * ma),
            div65535(sg0 * ma),
            div65535(sb0 * ma),
            div65535(sa0 * ma),
          )
        }
        None => (sr0, sg0, sb0, sa0)
      }
      let di = dst.pix_offset(x, y)
      if op == Over {
        let a = max_color - sa
        let dr = dst.pix.unsafe_get(di).to_uint()
        let dg = dst.pix.unsafe_get(di + 1).to_uint()
        let db = dst.pix.unsafe_get(di + 2).to_uint()
        let da = dst.pix.unsafe_get(di + 3).to_uint()
        let dr16 = dr | (dr << 8)
        let dg16 = dg | (dg << 8)
        let db16 = db | (db << 8)
        let da16 = da | (da << 8)
        dst.pix.unsafe_set(di, ((div65535(dr16 * a) + sr) >> 8).to_byte())
        dst.pix.unsafe_set(di + 1, ((div65535(dg16 * a) + sg) >> 8).to_byte())
        dst.pix.unsafe_set(di + 2, ((div65535(db16 * a) + sb) >> 8).to_byte())
        dst.pix.unsafe_set(di + 3, ((div65535(da16 * a) + sa) >> 8).to_byte())
      } else {
        dst.pix.unsafe_set(di, (sr >> 8).to_byte())
        dst.pix.unsafe_set(di + 1, (sg >> 8).to_byte())
        dst.pix.unsafe_set(di + 2, (sb >> 8).to_byte())
        dst.pix.unsafe_set(di + 3, (sa >> 8).to_byte())
      }
    }
  }
}

///|
fn draw_paletted(
  dst : @image.ImagePaletted,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
) -> Unit {
  let dx = r.dx()
  let mut d_row = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x)
  // Color cache: 256-entry direct-mapped cache (~95% hit rate for natural images).
  // Split key across two arrays to hold all 64 bits of RGBA.
  let cache_hi = FixedArray::make(256, -1) // (r << 16) | g
  let cache_lo = FixedArray::make(256, -1) // (b << 16) | a
  let cache_vals = FixedArray::make(256, 0)
  for _y = r.min_y; _y < r.max_y; _y = _y + 1 {
    let sy = sp.y + _y - r.min_y
    for _x = 0; _x < dx; _x = _x + 1 {
      let sx = sp.x + _x
      let c = src.at(sx, sy)
      let (cr, cg, cb, ca) = c.rgba()
      let hi = (cr.reinterpret_as_int() << 16) | cg.reinterpret_as_int()
      let lo = (cb.reinterpret_as_int() << 16) | ca.reinterpret_as_int()
      let slot = hi.lxor(lo).lxor(hi >> 8).land(0xFF)
      if cache_hi.unsafe_get(slot) == hi &&
        cache_lo.unsafe_get(slot) == lo {
        dst.pix.unsafe_set(d_row + _x, cache_vals.unsafe_get(slot).to_byte())
      } else {
        let idx = dst.palette.index(c)
        cache_hi.unsafe_set(slot, hi)
        cache_lo.unsafe_set(slot, lo)
        cache_vals.unsafe_set(slot, idx)
        dst.pix.unsafe_set(d_row + _x, idx.to_byte())
      }
    }
    d_row += dst.stride
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
  op : Op,
) -> Unit {
  for y = r.min_y; y < r.max_y; y = y + 1 {
    let sy = sp.y + y - r.min_y
    let my = mp.y + y - r.min_y
    for x = r.min_x; x < r.max_x; x = x + 1 {
      let sx = sp.x + x - r.min_x
      let mx = mp.x + x - r.min_x
      let (sr0, sg0, sb0, sa0) = src.at(sx, sy).rgba()
      let (sr1, sg1, sb1, sa1) = match mask {
        Some(mask_img) => {
          let (_, _, _, ma) = mask_img.at(mx, my).rgba()
          (
            div65535(sr0 * ma),
            div65535(sg0 * ma),
            div65535(sb0 * ma),
            div65535(sa0 * ma),
          )
        }
        None => (sr0, sg0, sb0, sa0)
      }
      let (sr, sg, sb, sa) = if op == Over {
        let (dr, dg, db, da) = dst.at(x, y).rgba()
        let a = max_color - sa1
        (
          div65535(dr * a) + sr1,
          div65535(dg * a) + sg1,
          div65535(db * a) + sb1,
          div65535(da * a) + sa1,
        )
      } else {
        (sr1, sg1, sb1, sa1)
      }
      match dst {
        @image.AnyImage::RGBA(img) =>
          img.set_rgba(x, y, {
            r: (sr >> 8).to_byte(),
            g: (sg >> 8).to_byte(),
            b: (sb >> 8).to_byte(),
            a: (sa >> 8).to_byte(),
          })
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
