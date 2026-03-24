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
  // RGBA destination, no mask — specialized fast paths
  if dst is @image.AnyImage::RGBA(dst0) && mask is None {
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
      @image.AnyImage::RGBA(src0) => {
        if op == Src {
          draw_copy_src(dst0, r, src0, sp)
        } else {
          draw_copy_over(dst0, r, src0, sp)
        }
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
      @image.AnyImage::RGBA64(src0) => {
        draw_rgba64_to_rgba(dst0, r, src0, sp, op)
        return
      }
      @image.AnyImage::NRGBA64(_)
      | @image.AnyImage::Alpha(_)
      | @image.AnyImage::Alpha16(_)
      | @image.AnyImage::Gray16(_)
      | @image.AnyImage::Paletted(_)
      | @image.AnyImage::NYCbCrA(_)
      | @image.AnyImage::CMYK(_) => ()
    }
    draw_rgba(dst0, r, src, sp, mask, op)
    return
  }
  // RGBA destination + Uniform source + Alpha mask (glyph rendering)
  if dst is @image.AnyImage::RGBA(dst0) &&
    src is @image.AnyImage::Uniform(u) &&
    mask is Some(@image.AnyImage::Alpha(mask_alpha)) {
    draw_glyph_over(dst0, r, u.c, mask_alpha, mp)
    return
  }
  // Paletted destination, no mask
  if dst is @image.AnyImage::Paletted(dst0) && mask is None {
    if src is @image.AnyImage::Uniform(u) {
      let idx = dst0.palette.index(u.c).to_byte()
      let dx = r.dx()
      let row0 = dst0.pix_offset +
        (r.min_y - dst0.rect.min_y) * dst0.stride +
        (r.min_x - dst0.rect.min_x)
      for y in r.min_y..<r.max_y {
        let row_off = row0 + (y - r.min_y) * dst0.stride
        for i in 0..<dx {
          dst0.pix.unsafe_set(row_off + i, idx)
        }
      }
    } else {
      draw_paletted(dst0, r, src, sp)
    }
    return
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
  let row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  if r_byte == g_byte && g_byte == b_byte && b_byte == a_byte {
    // All channels same value — single memset per row
    for y in r.min_y..<r.max_y {
      @blit.fill_bytes(dst.pix, row0 + (y - r.min_y) * dst.stride, r_byte, n)
    }
  } else {
    // Fill first row pixel by pixel, then blit to remaining rows
    for x in 0..<dx {
      let i = row0 + x * 4
      dst.pix.unsafe_set(i, r_byte)
      dst.pix.unsafe_set(i + 1, g_byte)
      dst.pix.unsafe_set(i + 2, b_byte)
      dst.pix.unsafe_set(i + 3, a_byte)
    }
    for y in (r.min_y + 1)..<r.max_y {
      @blit.blit_fixed_array(
        dst.pix, row0 + (y - r.min_y) * dst.stride, dst.pix, row0, n,
      )
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
  let row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  for y in r.min_y..<r.max_y {
    let row_off = row0 + (y - r.min_y) * dst.stride
    for x in 0..<dx {
      let i = row_off + x * 4
      let dr = dst.pix.unsafe_get(i).to_uint()
      let dg = dst.pix.unsafe_get(i + 1).to_uint()
      let db = dst.pix.unsafe_get(i + 2).to_uint()
      let da = dst.pix.unsafe_get(i + 3).to_uint()
      dst.pix.unsafe_set(i, ((div65535(dr * a) + sr) >> 8).to_byte())
      dst.pix.unsafe_set(i + 1, ((div65535(dg * a) + sg) >> 8).to_byte())
      dst.pix.unsafe_set(i + 2, ((div65535(db * a) + sb) >> 8).to_byte())
      dst.pix.unsafe_set(i + 3, ((div65535(da * a) + sa) >> 8).to_byte())
    }
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
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let s_row0 = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 4
  for y in r.min_y..<r.max_y {
    let dy = y - r.min_y
    @blit.blit_fixed_array(
      dst.pix, d_row0 + dy * dst.stride, src.pix, s_row0 + dy * src.stride, n,
    )
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
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let s_row0 = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 4
  for y in r.min_y..<r.max_y {
    let dy = y - r.min_y
    let d_row = d_row0 + dy * dst.stride
    let s_row = s_row0 + dy * src.stride
    for x in 0..<dx {
      let di = d_row + x * 4
      let si = s_row + x * 4
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
    }
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
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let s_row0 = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 4
  for y in r.min_y..<r.max_y {
    let dy = y - r.min_y
    let d_row = d_row0 + dy * dst.stride
    let s_row = s_row0 + dy * src.stride
    for x in 0..<dx {
      let di = d_row + x * 4
      let si = s_row + x * 4
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
    }
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
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let s_row0 = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x)
  for y in r.min_y..<r.max_y {
    let dy = y - r.min_y
    let d_row = d_row0 + dy * dst.stride
    let s_row = s_row0 + dy * src.stride
    for x in 0..<dx {
      let di = d_row + x * 4
      let v = src.pix.unsafe_get(s_row + x)
      dst.pix.unsafe_set(di, v)
      dst.pix.unsafe_set(di + 1, v)
      dst.pix.unsafe_set(di + 2, v)
      dst.pix.unsafe_set(di + 3, b'\xff')
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
/// Fast path for RGBA64 source → RGBA destination (no mask).
/// Avoids per-pixel AnyImage dispatch and refcounting.
fn draw_rgba64_to_rgba(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src : @image.ImageRGBA64,
  sp : @image.Point,
  op : Op,
) -> Unit {
  let dx = r.dx()
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let s_row0 = src.pix_offset +
    (sp.y - src.rect.min_y) * src.stride +
    (sp.x - src.rect.min_x) * 8
  for y in r.min_y..<r.max_y {
    let dy = y - r.min_y
    let d_row = d_row0 + dy * dst.stride
    let s_row = s_row0 + dy * src.stride
    for x in 0..<dx {
      let di = d_row + x * 4
      let si = s_row + x * 8
      let sr = (src.pix.unsafe_get(si).to_uint() << 8) |
        src.pix.unsafe_get(si + 1).to_uint()
      let sg = (src.pix.unsafe_get(si + 2).to_uint() << 8) |
        src.pix.unsafe_get(si + 3).to_uint()
      let sb = (src.pix.unsafe_get(si + 4).to_uint() << 8) |
        src.pix.unsafe_get(si + 5).to_uint()
      let sa = (src.pix.unsafe_get(si + 6).to_uint() << 8) |
        src.pix.unsafe_get(si + 7).to_uint()
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
        dst.pix.unsafe_set(
          di + 1, ((div65535(dg16 * a) + sg) >> 8).to_byte(),
        )
        dst.pix.unsafe_set(
          di + 2, ((div65535(db16 * a) + sb) >> 8).to_byte(),
        )
        dst.pix.unsafe_set(
          di + 3, ((div65535(da16 * a) + sa) >> 8).to_byte(),
        )
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
/// Fast path for glyph rendering: RGBA dst + uniform color + Alpha mask.
/// Avoids per-pixel AnyImage dispatch and refcounting.
fn draw_glyph_over(
  dst : @image.ImageRGBA,
  r : @image.Rectangle,
  src_color : @color.AnyColor,
  mask : @image.ImageAlpha,
  mp : @image.Point,
) -> Unit {
  let (sr, sg, sb, sa) = src_color.rgba()
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x) * 4
  let m_row0 = mask.pix_offset +
    (mp.y - mask.rect.min_y) * mask.stride +
    (mp.x - mask.rect.min_x)
  let dx = r.dx()
  for y in r.min_y..<r.max_y {
    let dy = y - r.min_y
    let d_row = d_row0 + dy * dst.stride
    let m_row = m_row0 + dy * mask.stride
    for x in 0..<dx {
      let ma8 = mask.pix.unsafe_get(m_row + x).to_uint()
      if ma8 == 0U {
        continue
      }
      let ma = ma8 | (ma8 << 8)
      let di = d_row + x * 4
      let sr1 = div65535(sr * ma)
      let sg1 = div65535(sg * ma)
      let sb1 = div65535(sb * ma)
      let sa1 = div65535(sa * ma)
      let a = max_color - sa1
      let dr = dst.pix.unsafe_get(di).to_uint()
      let dg = dst.pix.unsafe_get(di + 1).to_uint()
      let db = dst.pix.unsafe_get(di + 2).to_uint()
      let da = dst.pix.unsafe_get(di + 3).to_uint()
      let dr16 = dr | (dr << 8)
      let dg16 = dg | (dg << 8)
      let db16 = db | (db << 8)
      let da16 = da | (da << 8)
      dst.pix.unsafe_set(di, ((div65535(dr16 * a) + sr1) >> 8).to_byte())
      dst.pix.unsafe_set(di + 1, ((div65535(dg16 * a) + sg1) >> 8).to_byte())
      dst.pix.unsafe_set(di + 2, ((div65535(db16 * a) + sb1) >> 8).to_byte())
      dst.pix.unsafe_set(di + 3, ((div65535(da16 * a) + sa1) >> 8).to_byte())
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
  let d_row0 = dst.pix_offset +
    (r.min_y - dst.rect.min_y) * dst.stride +
    (r.min_x - dst.rect.min_x)
  // Color cache: 256-entry direct-mapped cache (~95% hit rate for natural images).
  // Split key across two arrays to hold all 64 bits of RGBA.
  let cache_hi = FixedArray::make(256, -1) // (r << 16) | g
  let cache_lo = FixedArray::make(256, -1) // (b << 16) | a
  let cache_vals = FixedArray::make(256, 0)
  for y in r.min_y..<r.max_y {
    let sy = sp.y + y - r.min_y
    let d_row = d_row0 + (y - r.min_y) * dst.stride
    for x in 0..<dx {
      let sx = sp.x + x
      let c = src.at(sx, sy)
      let (cr, cg, cb, ca) = c.rgba()
      let hi = (cr.reinterpret_as_int() << 16) | cg.reinterpret_as_int()
      let lo = (cb.reinterpret_as_int() << 16) | ca.reinterpret_as_int()
      let slot = hi.lxor(lo).lxor(hi >> 8).land(0xFF)
      if cache_hi.unsafe_get(slot) == hi &&
        cache_lo.unsafe_get(slot) == lo {
        dst.pix.unsafe_set(d_row + x, cache_vals.unsafe_get(slot).to_byte())
      } else {
        let idx = dst.palette.index(c)
        cache_hi.unsafe_set(slot, hi)
        cache_lo.unsafe_set(slot, lo)
        cache_vals.unsafe_set(slot, idx)
        dst.pix.unsafe_set(d_row + x, idx.to_byte())
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
        @image.AnyImage::RGBA64(_)
        | @image.AnyImage::NRGBA(_)
        | @image.AnyImage::NRGBA64(_)
        | @image.AnyImage::Alpha(_)
        | @image.AnyImage::Alpha16(_)
        | @image.AnyImage::Gray16(_)
        | @image.AnyImage::YCbCr(_)
        | @image.AnyImage::NYCbCrA(_)
        | @image.AnyImage::CMYK(_)
        | @image.AnyImage::Uniform(_) => ()
      }
    }
  }
}
