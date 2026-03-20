///|
/// Quantize reduces an image to at most n_colors using median-cut.
fn quantize_image(
  img : @image.AnyImage,
  n_colors : Int,
) -> @image.ImagePaletted {
  let bounds = img.bounds()
  let w = bounds.dx()
  let h = bounds.dy()
  let n = if n_colors < 2 { 2 } else if n_colors > 256 { 256 } else { n_colors }
  // Collect pixel samples (sample if image is large)
  let pixels = Array::new(capacity=w * h)
  for y = bounds.min_y; y < bounds.max_y; y = y + 1 {
    for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
      let (rv, gv, bv, _) = img.at(x, y).rgba()
      pixels.push(
        ((rv >> 8).to_byte(), (gv >> 8).to_byte(), (bv >> 8).to_byte()),
      )
    }
  }
  // Median-cut to produce palette
  let palette = median_cut(pixels, n)
  // Create paletted image
  let pal = @color.Palette::{ colors: palette }
  let result = @image.new_image_paletted(bounds, pal)
  // Map each pixel to nearest palette entry
  for y = bounds.min_y; y < bounds.max_y; y = y + 1 {
    for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
      let c = img.at(x, y)
      let idx = pal.index(c)
      result.set_color_index(x, y, idx.to_byte())
    }
  }
  result
}

///|
fn median_cut(
  pixels : Array[(Byte, Byte, Byte)],
  n_colors : Int,
) -> Array[@color.AnyColor] {
  if pixels.is_empty() {
    return []
  }
  let boxes : Array[Array[(Byte, Byte, Byte)]] = [pixels]
  while boxes.length() < n_colors {
    let mut best_idx = 0
    let mut best_range = 0
    let mut best_channel = 0
    for i, box_ in boxes {
      if box_.length() < 2 {
        continue
      }
      for ch in 0..<3 {
        let mut lo = 255
        let mut hi = 0
        for p in box_ {
          let v = match ch {
            0 => p.0.to_int()
            1 => p.1.to_int()
            _ => p.2.to_int()
          }
          if v < lo {
            lo = v
          }
          if v > hi {
            hi = v
          }
        }
        let range = hi - lo
        if range > best_range {
          best_range = range
          best_idx = i
          best_channel = ch
        }
      }
    }
    if best_range == 0 {
      break
    }
    let box_ = boxes.unsafe_get(best_idx)
    box_.sort_by(fn(a, b) {
      let va = match best_channel {
        0 => a.0.to_int()
        1 => a.1.to_int()
        _ => a.2.to_int()
      }
      let vb = match best_channel {
        0 => b.0.to_int()
        1 => b.1.to_int()
        _ => b.2.to_int()
      }
      va - vb
    })
    let mid = box_.length() / 2
    let box2 = Array::new(capacity=box_.length() - mid)
    for i = mid; i < box_.length(); i = i + 1 {
      box2.push(box_.unsafe_get(i))
    }
    while box_.length() > mid {
      ignore(box_.pop())
    }
    boxes.push(box2)
  }
  let colors : Array[@color.AnyColor] = Array::new(capacity=boxes.length())
  for box_ in boxes {
    if box_.is_empty() {
      continue
    }
    let mut sr = 0
    let mut sg = 0
    let mut sb = 0
    for p in box_ {
      sr += p.0.to_int()
      sg += p.1.to_int()
      sb += p.2.to_int()
    }
    let nn = box_.length()
    colors.push(
      @color.AnyColor::RGBA({
        r: (sr / nn).to_byte(),
        g: (sg / nn).to_byte(),
        b: (sb / nn).to_byte(),
        a: b'\xff',
      }),
    )
  }
  colors
}
