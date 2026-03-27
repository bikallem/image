///|
fn qc_gif_size(seed : Int) -> Int {
  let normalized = seed % 4
  (if normalized < 0 { normalized + 4 } else { normalized }) + 1
}

///|
fn qc_gif_offset(seed : Int) -> Int {
  let normalized = seed % 5
  (if normalized < 0 { normalized + 5 } else { normalized }) - 2
}

///|
fn qc_gif_byte_at(data : Bytes, index : Int) -> Byte {
  if data.length() == 0 {
    b'\x00'
  } else {
    data.unsafe_get(index % data.length())
  }
}

///|
let qc_gif_palette : @color.Palette = {
  colors: [
    @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
    @color.AnyColor::RGBA({ r: b'\xff', g: b'\x00', b: b'\x00', a: b'\xff' }),
    @color.AnyColor::RGBA({ r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' }),
    @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' }),
  ],
}

///|
fn prop_gif_paletted_roundtrip_random(
  input : (Int, Int, Int, Int, Bytes),
) -> Bool {
  let (w_seed, h_seed, x_seed, y_seed, pixel_data) = input
  let width = qc_gif_size(w_seed)
  let height = qc_gif_size(h_seed)
  let left = qc_gif_offset(x_seed)
  let top = qc_gif_offset(y_seed)
  let rect = @image.rect(left, top, left + width, top + height)
  let img = @image.new_image_paletted(rect, qc_gif_palette)
  let palette_len = qc_gif_palette.colors.length()
  let mut offset = 0
  for y = rect.min_y; y < rect.max_y; y = y + 1 {
    for x = rect.min_x; x < rect.max_x; x = x + 1 {
      let index = qc_gif_byte_at(pixel_data, offset).to_int() % palette_len
      img.set_color_index(x, y, index.to_byte())
      offset += 1
    }
  }
  try encode_paletted(img) catch {
    _ => false
  } noraise {
    encoded =>
      try decode_all(encoded) catch {
        _ => false
      } noraise {
        decoded =>
          if decoded.config.width != width ||
            decoded.config.height != height ||
            decoded.image.length() != 1 ||
            !decoded.image[0].rect.eq(@image.rect(0, 0, width, height)) {
            false
          } else {
            let frame = decoded.image[0]
            let mut ok = true
            for y in 0..<height {
              for x in 0..<width {
                if frame.at(x, y).rgba() != img.at(left + x, top + y).rgba() {
                  ok = false
                }
              }
            }
            ok
          }
      }
  }
}

///|
test "gif_quickcheck_roundtrip" {
  @qc.quick_check_fn(
    prop_gif_paletted_roundtrip_random,
    max_success=150,
    max_size=24,
  )
}
