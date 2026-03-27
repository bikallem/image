///|
fn qc_small_size(n : Int) -> Int {
  let m = n % 4
  let normalized = if m < 0 { m + 4 } else { m }
  normalized + 1
}

///|
fn qc_byte_at(data : Bytes, index : Int) -> Byte {
  if data.length() == 0 {
    b'\x00'
  } else {
    data.unsafe_get(index % data.length())
  }
}

///|
fn qc_make_nrgba_image(
  width : Int,
  height : Int,
  data : Bytes,
) -> @image.ImageNRGBA {
  let img = @image.new_image_nrgba(@image.rect(0, 0, width, height))
  let mut offset = 0
  for y in 0..<height {
    for x in 0..<width {
      img.set_nrgba(x, y, {
        r: qc_byte_at(data, offset),
        g: qc_byte_at(data, offset + 1),
        b: qc_byte_at(data, offset + 2),
        a: qc_byte_at(data, offset + 3),
      })
      offset += 4
    }
  }
  img
}

///|
fn qc_images_equal(lhs : @image.AnyImage, rhs : @image.AnyImage) -> Bool {
  let lb = lhs.bounds()
  let rb = rhs.bounds()
  if !lb.eq(rb) {
    return false
  }
  for y = lb.min_y; y < lb.max_y; y = y + 1 {
    for x = lb.min_x; x < lb.max_x; x = x + 1 {
      if lhs.at(x, y).rgba() != rhs.at(x, y).rgba() {
        return false
      }
    }
  }
  true
}

///|
fn prop_png_nrgba_roundtrip_random(input : (Int, Int, Bytes)) -> Bool {
  let (w_seed, h_seed, pixel_data) = input
  let width = qc_small_size(w_seed)
  let height = qc_small_size(h_seed)
  let img = qc_make_nrgba_image(width, height, pixel_data)
  let original = @image.AnyImage::NRGBA(img)
  try encode(original) catch {
    _ => false
  } noraise {
    encoded =>
      try decode_config(encoded) catch {
        _ => false
      } noraise {
        config =>
          if config.width != width || config.height != height {
            false
          } else {
            try decode(encoded) catch {
              _ => false
            } noraise {
              decoded => qc_images_equal(original, decoded)
            }
          }
      }
  }
}

///|
test "png_quickcheck_roundtrip" {
  @qc.quick_check_fn(
    prop_png_nrgba_roundtrip_random,
    max_success=150,
    max_size=24,
  )
}
