///|
fn clamp16(v : Int) -> UInt {
  if v < 0 {
    0U
  } else if v > 0xffff {
    0xffffU
  } else {
    v.reinterpret_as_uint()
  }
}

///|
/// Accumulates weighted RGBA error at offset `base` in `arr`.
fn diffuse(
  arr : FixedArray[Int],
  base : Int,
  dr : Int,
  dg : Int,
  db : Int,
  da : Int,
  num : Int,
) -> Unit {
  arr.unsafe_set(base, arr.unsafe_get(base) + dr * num / 16)
  arr.unsafe_set(base + 1, arr.unsafe_get(base + 1) + dg * num / 16)
  arr.unsafe_set(base + 2, arr.unsafe_get(base + 2) + db * num / 16)
  arr.unsafe_set(base + 3, arr.unsafe_get(base + 3) + da * num / 16)
}

///|
/// Floyd-Steinberg error diffusion dithering for paletted images.
pub fn floyd_steinberg_draw(
  dst : @image.ImagePaletted,
  r : @image.Rectangle,
  src : &@image.Image,
  sp : @image.Point,
) -> Unit {
  if r.empty() || dst.palette.colors.is_empty() {
    return
  }
  let w = r.dx()
  let quant_err_cur = FixedArray::make(w * 4, 0)
  let quant_err_next = FixedArray::make(w * 4, 0)
  for y = r.min_y; y < r.max_y; y = y + 1 {
    for i in 0..<(w * 4) {
      quant_err_next.unsafe_set(i, 0)
    }
    let sy = sp.y + y - r.min_y
    for x = r.min_x; x < r.max_x; x = x + 1 {
      let sx = sp.x + x - r.min_x
      let (sr, sg, sb, sa) = src.at(sx, sy).rgba()
      let ei = (x - r.min_x) * 4
      let er = clamp16(sr.reinterpret_as_int() + quant_err_cur.unsafe_get(ei))
      let eg = clamp16(
        sg.reinterpret_as_int() + quant_err_cur.unsafe_get(ei + 1),
      )
      let eb = clamp16(
        sb.reinterpret_as_int() + quant_err_cur.unsafe_get(ei + 2),
      )
      let ea = clamp16(
        sa.reinterpret_as_int() + quant_err_cur.unsafe_get(ei + 3),
      )
      let wanted : @color.RGBA64 = { r: er, g: eg, b: eb, a: ea }
      let idx = dst.palette.index(wanted)
      dst.set_color_index(x, y, idx.to_byte())
      let (pr, pg, pb, pa) = dst.palette.colors.unsafe_get(idx).rgba()
      let dr = er.reinterpret_as_int() - pr.reinterpret_as_int()
      let dg = eg.reinterpret_as_int() - pg.reinterpret_as_int()
      let db = eb.reinterpret_as_int() - pb.reinterpret_as_int()
      let da = ea.reinterpret_as_int() - pa.reinterpret_as_int()
      // Floyd-Steinberg coefficients:  _ X 7/16  /  3/16 5/16 1/16
      let xi = x - r.min_x
      if xi + 1 < w {
        diffuse(quant_err_cur, (xi + 1) * 4, dr, dg, db, da, 7)
      }
      if xi > 0 {
        diffuse(quant_err_next, (xi - 1) * 4, dr, dg, db, da, 3)
      }
      diffuse(quant_err_next, xi * 4, dr, dg, db, da, 5)
      if xi + 1 < w {
        diffuse(quant_err_next, (xi + 1) * 4, dr, dg, db, da, 1)
      }
    }
    FixedArray::unsafe_blit(quant_err_cur, 0, quant_err_next, 0, w * 4)
  }
}
