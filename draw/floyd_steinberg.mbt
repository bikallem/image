///|
/// Floyd-Steinberg error diffusion dithering for paletted images.
pub fn floyd_steinberg_draw(
  dst : @image.ImagePaletted,
  r : @image.Rectangle,
  src : @image.AnyImage,
  sp : @image.Point,
) -> Unit {
  if r.empty() || dst.palette.colors.is_empty() {
    return
  }
  let w = r.dx()
  // quantError is the accumulated Floyd-Steinberg error for each pixel.
  // We use two rows: current and next.
  let quant_err_cur = FixedArray::make(w * 4, 0)
  let quant_err_next = FixedArray::make(w * 4, 0)
  for y = r.min.y; y < r.max.y; y = y + 1 {
    // Clear next row
    for i in 0..<(w * 4) {
      quant_err_next[i] = 0
    }
    let sy = sp.y + y - r.min.y
    for x = r.min.x; x < r.max.x; x = x + 1 {
      let sx = sp.x + x - r.min.x
      let (sr, sg, sb, sa) = src.at(sx, sy).rgba()
      let ei = (x - r.min.x) * 4
      // Add quantization error from previous pixels.
      let er = sr.reinterpret_as_int() + quant_err_cur[ei]
      let eg = sg.reinterpret_as_int() + quant_err_cur[ei + 1]
      let eb = sb.reinterpret_as_int() + quant_err_cur[ei + 2]
      let ea = sa.reinterpret_as_int() + quant_err_cur[ei + 3]
      // Clamp to [0, 0xffff].
      let er = if er < 0 {
        0U
      } else if er > 0xffff {
        0xffffU
      } else {
        er.reinterpret_as_uint()
      }
      let eg = if eg < 0 {
        0U
      } else if eg > 0xffff {
        0xffffU
      } else {
        eg.reinterpret_as_uint()
      }
      let eb = if eb < 0 {
        0U
      } else if eb > 0xffff {
        0xffffU
      } else {
        eb.reinterpret_as_uint()
      }
      let ea = if ea < 0 {
        0U
      } else if ea > 0xffff {
        0xffffU
      } else {
        ea.reinterpret_as_uint()
      }
      let wanted = @color.AnyColor::RGBA64({ r: er, g: eg, b: eb, a: ea })
      let idx = dst.palette.index(wanted)
      dst.set_color_index(x, y, idx.to_byte())
      // Compute the error.
      let (pr, pg, pb, pa) = dst.palette.colors[idx].rgba()
      let diff_r = er.reinterpret_as_int() - pr.reinterpret_as_int()
      let diff_g = eg.reinterpret_as_int() - pg.reinterpret_as_int()
      let diff_b = eb.reinterpret_as_int() - pb.reinterpret_as_int()
      let diff_a = ea.reinterpret_as_int() - pa.reinterpret_as_int()
      // Distribute error to neighbors using Floyd-Steinberg coefficients:
      //   _ X 7/16
      // 3/16 5/16 1/16
      let xi = x - r.min.x
      if xi + 1 < w {
        quant_err_cur[(xi + 1) * 4] = quant_err_cur[(xi + 1) * 4] +
          diff_r * 7 / 16
        quant_err_cur[(xi + 1) * 4 + 1] = quant_err_cur[(xi + 1) * 4 + 1] +
          diff_g * 7 / 16
        quant_err_cur[(xi + 1) * 4 + 2] = quant_err_cur[(xi + 1) * 4 + 2] +
          diff_b * 7 / 16
        quant_err_cur[(xi + 1) * 4 + 3] = quant_err_cur[(xi + 1) * 4 + 3] +
          diff_a * 7 / 16
      }
      if xi > 0 {
        quant_err_next[(xi - 1) * 4] = quant_err_next[(xi - 1) * 4] +
          diff_r * 3 / 16
        quant_err_next[(xi - 1) * 4 + 1] = quant_err_next[(xi - 1) * 4 + 1] +
          diff_g * 3 / 16
        quant_err_next[(xi - 1) * 4 + 2] = quant_err_next[(xi - 1) * 4 + 2] +
          diff_b * 3 / 16
        quant_err_next[(xi - 1) * 4 + 3] = quant_err_next[(xi - 1) * 4 + 3] +
          diff_a * 3 / 16
      }
      quant_err_next[xi * 4] = quant_err_next[xi * 4] + diff_r * 5 / 16
      quant_err_next[xi * 4 + 1] = quant_err_next[xi * 4 + 1] + diff_g * 5 / 16
      quant_err_next[xi * 4 + 2] = quant_err_next[xi * 4 + 2] + diff_b * 5 / 16
      quant_err_next[xi * 4 + 3] = quant_err_next[xi * 4 + 3] + diff_a * 5 / 16
      if xi + 1 < w {
        quant_err_next[(xi + 1) * 4] = quant_err_next[(xi + 1) * 4] +
          diff_r / 16
        quant_err_next[(xi + 1) * 4 + 1] = quant_err_next[(xi + 1) * 4 + 1] +
          diff_g / 16
        quant_err_next[(xi + 1) * 4 + 2] = quant_err_next[(xi + 1) * 4 + 2] +
          diff_b / 16
        quant_err_next[(xi + 1) * 4 + 3] = quant_err_next[(xi + 1) * 4 + 3] +
          diff_a / 16
      }
    }
    // Swap rows
    FixedArray::unsafe_blit(quant_err_cur, 0, quant_err_next, 0, w * 4)
  }
}
