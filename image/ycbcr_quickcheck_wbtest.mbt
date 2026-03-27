///|
fn qc_ratio(seed : Int) -> YCbCrSubsampleRatio {
  let normalized = seed % 6
  match (if normalized < 0 { normalized + 6 } else { normalized }) {
    0 => Ratio444
    1 => Ratio422
    2 => Ratio420
    3 => Ratio440
    4 => Ratio411
    _ => Ratio410
  }
}

///|
fn qc_non_negative_coord(seed : Int) -> Int {
  let normalized = seed % 9
  if normalized < 0 {
    normalized + 9
  } else {
    normalized
  }
}

///|
fn qc_non_negative_rect(coords : (Int, Int, Int, Int)) -> Rectangle {
  let (x0, y0, x1, y1) = coords
  rect(
    qc_non_negative_coord(x0),
    qc_non_negative_coord(y0),
    qc_non_negative_coord(x1),
    qc_non_negative_coord(y1),
  )
}

///|
fn qc_fill_ycbcr(img : ImageYCbCr) -> Unit {
  for y = img.rect.min_y; y < img.rect.max_y; y = y + 1 {
    for x = img.rect.min_x; x < img.rect.max_x; x = x + 1 {
      let yi = img.y_offset(x, y)
      let ci = img.c_offset(x, y)
      img.y_[yi] = (yi % 256).to_byte()
      img.cb[ci] = ((ci * 3 + 5) % 256).to_byte()
      img.cr[ci] = ((ci * 7 + 11) % 256).to_byte()
    }
  }
}

///|
fn prop_ycbcr_sub_image_preserves_pixels(
  input : ((Int, Int, Int, Int), (Int, Int, Int, Int), Int),
) -> Bool {
  let (image_rect_seed, sub_rect_seed, ratio_seed) = input
  let image_rect = qc_non_negative_rect(image_rect_seed)
  let requested = qc_non_negative_rect(sub_rect_seed)
  let ratio = qc_ratio(ratio_seed)
  let img = new_image_ycbcr(image_rect, ratio)
  qc_fill_ycbcr(img)
  let sub = img.sub_image(requested)
  let expected = requested.intersect(image_rect)
  if !sub.rect.eq(expected) || sub.subsample_ratio != ratio || !sub.is_opaque() {
    return false
  }
  for y = expected.min_y; y < expected.max_y; y = y + 1 {
    for x = expected.min_x; x < expected.max_x; x = x + 1 {
      if sub.ycbcr_at(x, y) != img.ycbcr_at(x, y) {
        return false
      }
    }
  }
  true
}

///|
fn prop_ycbcr_out_of_bounds_is_zero(
  input : ((Int, Int, Int, Int), Int, Int),
) -> Bool {
  let (image_rect_seed, px_seed, ratio_seed) = input
  let image_rect = qc_non_negative_rect(image_rect_seed)
  let ratio = qc_ratio(ratio_seed)
  let img = new_image_ycbcr(image_rect, ratio)
  qc_fill_ycbcr(img)
  let px = qc_small_coord(px_seed)
  let outside = if image_rect.empty() {
    { x: px, y: qc_small_coord(px_seed + 1) }
  } else {
    { x: image_rect.max_x, y: image_rect.min_y + px % 3 }
  }
  img.ycbcr_at(outside.x, outside.y) == { y: b'\x00', cb: b'\x00', cr: b'\x00' }
}

///|
test "ycbcr_quickcheck" {
  @qc.quick_check_fn(
    prop_ycbcr_sub_image_preserves_pixels,
    max_success=200,
    max_size=24,
  )
  @qc.quick_check_fn(
    prop_ycbcr_out_of_bounds_is_zero,
    max_success=200,
    max_size=24,
  )
}
