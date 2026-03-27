///|
/// Port of Go's TestDecode from reader_test.go.
/// Basic GIF decoding.
test "gif_decode" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  let img = decode(data)
  let b = img.bounds()
  assert_true(b.dx() > 0)
  assert_true(b.dy() > 0)
}

///|
/// Test decode_all for multi-frame info.
test "gif_decode_all" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  let gif = decode_all(data)
  assert_true(gif.image.length() > 0)
  assert_true(gif.config.width > 0)
  assert_true(gif.config.height > 0)
}

///|
test "gif_interlaced_pixels_match_reference" {
  let interlaced = decode_all(
    @fs.read_file_to_bytes("testdata/video-001.interlaced.gif"),
  )
  let normal = decode_all(@fs.read_file_to_bytes("testdata/video-001.gif"))
  assert_eq(interlaced.image.length(), normal.image.length())
  let interlaced_frame = interlaced.image[0]
  let normal_frame = normal.image[0]
  assert_eq(interlaced_frame.rect, normal_frame.rect)
  for y = interlaced_frame.rect.min_y
      y < interlaced_frame.rect.max_y
      y = y + 1 {
    for x = interlaced_frame.rect.min_x
        x < interlaced_frame.rect.max_x
        x = x + 1 {
      let (r1, g1, b1, a1) = @image.AnyImage::Paletted(interlaced_frame)
        .at(x, y)
        .rgba()
      let (r2, g2, b2, a2) = @image.AnyImage::Paletted(normal_frame)
        .at(x, y)
        .rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
    }
  }
}

///|
/// Port of Go's TestBounds from reader_test.go.
test "gif_bounds" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  let gif = decode_all(data)
  for frame in gif.image {
    // Each frame should have valid bounds
    assert_true(
      frame.rect.dx() > 0 || frame.rect.dy() > 0 || frame.rect.dx() == 0,
    )
  }
}

///|
/// Port of Go's TestWriter from writer_test.go.
/// GIF encode -> decode roundtrip.
test "gif_writer" {
  let pal : @color.Palette = {
    colors: Array::makei(256, fn(i) {
      @color.AnyColor::RGBA({
        r: i.to_byte(),
        g: (255 - i).to_byte(),
        b: b'\x80',
        a: b'\xff',
      })
    }),
  }
  let m = @image.new_image_paletted(@image.rect(0, 0, 32, 32), pal)
  for y in 0..<32 {
    for x in 0..<32 {
      m.set_color_index(x, y, ((x + y) % 256).to_byte())
    }
  }
  let encoded = encode(@image.AnyImage::Paletted(m))
  let decoded = decode(encoded)
  let b = decoded.bounds()
  assert_eq(b.dx(), 32)
  assert_eq(b.dy(), 32)
}

///|
/// Test that truncated GIFs don't crash.
test "gif_unexpected_eof" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  // Truncate at various points
  for len in [6, 13, 100, 500] {
    if len < data.length() {
      let truncated = Bytes::makei(len, fn(i) { data[i] })
      ignore(try? decode(truncated))
    }
  }
}

///|
fn make_test_gif(
  logical_width : Int,
  logical_height : Int,
  left : Int,
  top : Int,
  image_width : Int,
  image_height : Int,
  pixels : Bytes,
) -> Bytes raise Error {
  let buf = @blit.Buffer::new()
  for b in [b'G', b'I', b'F', b'8', b'9', b'a'] {
    buf.write_byte(b)
  }
  write_uint16_le(buf, logical_width.reinterpret_as_uint())
  write_uint16_le(buf, logical_height.reinterpret_as_uint())
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xff')
  buf.write_byte(image_descriptor)
  write_uint16_le(buf, left.reinterpret_as_uint())
  write_uint16_le(buf, top.reinterpret_as_uint())
  write_uint16_le(buf, image_width.reinterpret_as_uint())
  write_uint16_le(buf, image_height.reinterpret_as_uint())
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x02')
  let compressed = @lzw.compress(pixels, @lzw.BitOrder::LSB, 2)
  write_sub_blocks(buf, compressed)
  buf.write_byte(trailer)
  buf.to_bytes()
}

///|
fn make_gif_with_bad_second_frame() -> Bytes raise Error {
  let buf = @blit.Buffer::new()
  for b in [b'G', b'I', b'F', b'8', b'9', b'a'] {
    buf.write_byte(b)
  }
  write_uint16_le(buf, 1U)
  write_uint16_le(buf, 1U)
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xff')
  buf.write_byte(image_descriptor)
  write_uint16_le(buf, 0U)
  write_uint16_le(buf, 0U)
  write_uint16_le(buf, 1U)
  write_uint16_le(buf, 1U)
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x02')
  write_sub_blocks(
    buf,
    @lzw.compress(Bytes::from_array([b'\x00']), @lzw.BitOrder::LSB, 2),
  )
  buf.write_byte(image_descriptor)
  write_uint16_le(buf, 0U)
  write_uint16_le(buf, 0U)
  write_uint16_le(buf, 1U)
  write_uint16_le(buf, 1U)
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x01')
  buf.write_byte(b'\x00')
  buf.write_byte(trailer)
  buf.to_bytes()
}

///|
fn make_gif_with_unknown_extension() -> Bytes raise Error {
  let buf = @blit.Buffer::new()
  for b in [b'G', b'I', b'F', b'8', b'9', b'a'] {
    buf.write_byte(b)
  }
  write_uint16_le(buf, 1U)
  write_uint16_le(buf, 1U)
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xff')
  buf.write_byte(ext_introducer)
  buf.write_byte(b'\x02')
  buf.write_byte(b'\x01')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(image_descriptor)
  write_uint16_le(buf, 0U)
  write_uint16_le(buf, 0U)
  write_uint16_le(buf, 1U)
  write_uint16_le(buf, 1U)
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x02')
  write_sub_blocks(
    buf,
    @lzw.compress(Bytes::from_array([b'\x00']), @lzw.BitOrder::LSB, 2),
  )
  buf.write_byte(trailer)
  buf.to_bytes()
}

///|
fn assert_empty_palette_model(
  color_model : @color.AnyModel,
) -> Unit raise Error {
  match color_model {
    @color.AnyModel::PaletteModel(p) => assert_eq(p.colors.length(), 0)
    _ => fail("expected empty palette model")
  }
}

///|
fn make_test_palette(size : Int) -> @color.Palette {
  {
    colors: Array::makei(size, fn(i) {
      @color.AnyColor::RGBA({
        r: i.to_byte(),
        g: (i * 3).to_byte(),
        b: (i * 7).to_byte(),
        a: b'\xff',
      })
    }),
  }
}

///|
test "gif_rejects_frame_bounds_outside_screen" {
  let result = try? decode(
    make_test_gif(1, 1, 1, 0, 1, 1, Bytes::makei(1, fn(_) { b'\x00' })),
  )
  assert_true(result is Err(_))
}

///|
test "gif_rejects_short_image_data" {
  let result = try? decode(
    make_test_gif(2, 1, 0, 0, 2, 1, Bytes::makei(1, fn(_) { b'\x00' })),
  )
  assert_true(result is Err(_))
}

///|
test "gif_rejects_bad_palette_index" {
  let result = try? decode(
    make_test_gif(1, 1, 0, 0, 1, 1, Bytes::makei(1, fn(_) { b'\x02' })),
  )
  assert_true(result is Err(_))
}

///|
test "gif_rejects_bad_lzw_min" {
  let data = make_test_gif(1, 1, 0, 0, 1, 1, Bytes::makei(1, fn(_) { b'\x00' }))
  let bad = Bytes::makei(data.length(), fn(i) {
    if i == 29 {
      b'\x01'
    } else {
      data[i]
    }
  })
  let result = try? decode(bad)
  assert_true(result is Err(_))
}

///|
test "gif_decode_stops_after_first_frame" {
  let data = make_gif_with_bad_second_frame()
  let img = decode(data)
  assert_eq(img.bounds(), @image.rect(0, 0, 1, 1))
  let result = try? decode_all(data)
  assert_true(result is Err(_))
}

///|
test "gif_rejects_unknown_extension" {
  let data = make_gif_with_unknown_extension()
  assert_true((try? decode(data)) is Err(_))
  assert_true((try? decode_all(data)) is Err(_))
}

///|
/// Port of Go's TestLoopCount from reader_test.go.
test "gif_loop_count" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  frame.set_color_index(0, 0, b'\x00')
  let gif : GIF = {
    image: [frame, frame],
    delay: [0, 0],
    loop_count: 0,
    disposal: [b'\x00', b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal),
      width: 1,
      height: 1,
    },
  }
  let encoded = encode_all(gif)
  let decoded_gif = decode_all(encoded)
  assert_eq(decoded_gif.loop_count, 0)
}

///|
test "gif_roundtrip_frame_metadata" {
  let pal1 : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\x00', b: b'\x00', a: b'\xff' }),
    ],
  }
  let frame1 = @image.new_image_paletted(@image.rect(0, 0, 4, 4), pal1)
  for y in 0..<4 {
    for x in 0..<4 {
      frame1.set_color_index(
        x,
        y,
        if (x + y) % 2 == 0 {
          b'\x01'
        } else {
          b'\x00'
        },
      )
    }
  }
  let pal2 : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }),
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' }),
    ],
  }
  let frame2 = @image.new_image_paletted(@image.rect(1, 1, 3, 3), pal2)
  frame2.set_color_index(1, 1, b'\x00')
  frame2.set_color_index(2, 1, b'\x01')
  frame2.set_color_index(1, 2, b'\x01')
  frame2.set_color_index(2, 2, b'\x00')
  let gif : GIF = {
    image: [frame1, frame2],
    delay: [7, 11],
    loop_count: 5,
    disposal: [disposal_none, disposal_background],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal1),
      width: 4,
      height: 4,
    },
  }
  let decoded = decode_all(encode_all(gif))
  assert_eq(decoded.loop_count, 5)
  assert_eq(decoded.delay, [7, 11])
  assert_eq(decoded.disposal, [disposal_none, disposal_background])
  assert_eq(decoded.image.length(), 2)
  assert_eq(decoded.image[0].rect, @image.rect(0, 0, 4, 4))
  assert_eq(decoded.image[1].rect, @image.rect(1, 1, 3, 3))
  let (_, _, _, a0) = @image.AnyImage::Paletted(decoded.image[1])
    .at(1, 1)
    .rgba()
  let (_, g1, _, a1) = @image.AnyImage::Paletted(decoded.image[1])
    .at(2, 1)
    .rgba()
  assert_eq(a0, 0U)
  assert_eq(g1, 0xffffU)
  assert_eq(a1, 0xffffU)
}

///|
/// Port of Go's TestEncodeZeroGIF from writer_test.go.
/// Encoding a GIF with no frames should fail.
test "gif_encode_zero" {
  let gif : GIF = {
    image: [],
    delay: [],
    loop_count: 0,
    disposal: [],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel({ colors: [] }),
      width: 1,
      height: 1,
    },
  }
  assert_true((try? encode_all(gif)) is Err(_))
}

///|
/// Test encoding and decoding with different palette sizes.
test "gif_palettes" {
  let sizes = [2, 4, 16, 256]
  for size in sizes {
    let pal : @color.Palette = {
      colors: Array::makei(size, fn(i) {
        @color.AnyColor::RGBA({
          r: (i * (256 / size)).to_byte(),
          g: b'\x00',
          b: b'\x00',
          a: b'\xff',
        })
      }),
    }
    let m = @image.new_image_paletted(@image.rect(0, 0, 4, 4), pal)
    for y in 0..<4 {
      for x in 0..<4 {
        m.set_color_index(x, y, ((x + y) % size).to_byte())
      }
    }
    let encoded = encode(@image.AnyImage::Paletted(m))
    let decoded = decode(encoded)
    assert_eq(decoded.bounds().dx(), 4)
    assert_eq(decoded.bounds().dy(), 4)
  }
}

///|
/// Test encoding an RGBA image as GIF (auto-quantization).
test "gif_encode_rgba" {
  let m = @image.new_image_rgba(@image.rect(0, 0, 16, 16))
  for y in 0..<16 {
    for x in 0..<16 {
      m.set_rgba(x, y, {
        r: (x * 16).to_byte(),
        g: (y * 16).to_byte(),
        b: b'\x80',
        a: b'\xff',
      })
    }
  }
  let encoded = encode_image(@image.AnyImage::RGBA(m))
  let decoded = decode(encoded)
  assert_eq(decoded.bounds().dx(), 16)
  assert_eq(decoded.bounds().dy(), 16)
}

///|
test "gif_encode_normalizes_non_zero_paletted_bounds" {
  let frame = @image.new_image_paletted(@image.rect(2, 3, 8, 9), @color.Palette::{
    colors: Array::makei(16, fn(i) { @palette.plan9[i] }),
  })
  for y = frame.rect.min_y; y < frame.rect.max_y; y = y + 1 {
    for x = frame.rect.min_x; x < frame.rect.max_x; x = x + 1 {
      frame.set_color_index(x, y, ((x + y) % 16).to_byte())
    }
  }
  let decoded = decode(encode_paletted(frame))
  assert_eq(decoded.bounds(), @image.rect(0, 0, 6, 6))
  let (r0, _, _, _) = decoded.at(0, 0).rgba()
  let (r1, _, _, _) = decoded.at(5, 5).rgba()
  let (want0, _, _, _) = frame.at(2, 3).rgba()
  let (want1, _, _, _) = frame.at(7, 8).rgba()
  assert_eq(r0 >> 8, want0 >> 8)
  assert_eq(r1 >> 8, want1 >> 8)
}

///|
test "gif_encode_image_normalizes_non_zero_generic_bounds" {
  let img = @image.new_image_rgba(@image.rect(2, 2, 8, 8))
  for i in 0..<6 {
    let v = (0x22 + i * 0x11).to_byte()
    img.set_rgba(2 + i, 2 + i, { r: v, g: v, b: v, a: b'\xff' })
  }
  let decoded = decode(encode_image(@image.AnyImage::RGBA(img)))
  assert_eq(decoded.bounds(), @image.rect(0, 0, 6, 6))
  let (r0, _, _, _) = decoded.at(0, 0).rgba()
  let (r1, _, _, _) = decoded.at(5, 5).rgba()
  assert_true(r0 >> 8 > 0U)
  assert_true(r1 >> 8 > 0U)
}

///|
test "gif_encode_image_requantizes_paletted_sources_to_requested_cap" {
  let pal : @color.Palette = {
    colors: Array::makei(16, fn(i) { @palette.plan9[i] }),
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 4, 4), pal)
  for y in 0..<4 {
    for x in 0..<4 {
      frame.set_color_index(x, y, ((x + y * 4) % 16).to_byte())
    }
  }
  let decoded = decode_all(
    encode_image(@image.AnyImage::Paletted(frame), n_colors=2),
  )
  assert_eq(decoded.image.length(), 1)
  assert_eq(decoded.image[0].palette.colors.length(), 2)
}

///|
test "gif_encode_image_supports_one_color" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 3, 2))
  for y in 0..<2 {
    for x in 0..<3 {
      img.set_rgba(x, y, {
        r: (x * 70 + y * 20).to_byte(),
        g: (x * 30 + y * 50).to_byte(),
        b: (x * 10 + y * 90).to_byte(),
        a: b'\xff',
      })
    }
  }
  let decoded = decode_all(encode_image(@image.AnyImage::RGBA(img), n_colors=1))
  assert_eq(decoded.image.length(), 1)
  assert_eq(decoded.image[0].rect, @image.rect(0, 0, 3, 2))
  assert_eq(decoded.image[0].palette.colors.length(), 2)
  for y in 0..<2 {
    for x in 0..<3 {
      assert_eq(decoded.image[0].color_index_at(x, y), b'\x00')
    }
  }
}

///|
test "gif_encode_options_custom_quantizer_and_drawer" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 4, 2))
  for y in 0..<2 {
    for x in 0..<4 {
      let v = if x < 2 { b'\x10' } else { b'\xf0' }
      img.set_rgba(x, y, { r: v, g: v, b: v, a: b'\xff' })
    }
  }
  let options : Options = {
    num_colors: 2,
    quantizer: Some(fn(_src, _n_colors) {
      {
        colors: [
          @color.AnyColor::RGBA({
            r: b'\x00',
            g: b'\x00',
            b: b'\x00',
            a: b'\xff',
          }),
          @color.AnyColor::RGBA({
            r: b'\xff',
            g: b'\xff',
            b: b'\xff',
            a: b'\xff',
          }),
        ],
      }
    }),
    drawer: Some(fn(dst, r, src, sp) {
      for y = r.min_y; y < r.max_y; y = y + 1 {
        for x = r.min_x; x < r.max_x; x = x + 1 {
          let sx = sp.x + x - r.min_x
          let sy = sp.y + y - r.min_y
          let (rv, _, _, _) = src.at(sx, sy).rgba()
          dst.set_color_index(
            x,
            y,
            if rv >> 8 < 0x80U {
              b'\x00'
            } else {
              b'\x01'
            },
          )
        }
      }
    }),
  }
  let decoded = decode_all(encode(@image.AnyImage::RGBA(img), options~))
  assert_eq(decoded.image.length(), 1)
  assert_eq(decoded.image[0].palette.colors.length(), 2)
  for y in 0..<2 {
    assert_eq(decoded.image[0].color_index_at(0, y), b'\x00')
    assert_eq(decoded.image[0].color_index_at(1, y), b'\x00')
    assert_eq(decoded.image[0].color_index_at(2, y), b'\x01')
    assert_eq(decoded.image[0].color_index_at(3, y), b'\x01')
  }
}

///|
/// Test GIF encoding/decoding pixel parity.
test "gif_pixel_parity" {
  let pal : @color.Palette = {
    colors: Array::makei(4, fn(i) {
      @color.AnyColor::RGBA({
        r: (i * 85).to_byte(),
        g: (i * 85).to_byte(),
        b: (i * 85).to_byte(),
        a: b'\xff',
      })
    }),
  }
  let m = @image.new_image_paletted(@image.rect(0, 0, 8, 8), pal)
  for y in 0..<8 {
    for x in 0..<8 {
      m.set_color_index(x, y, ((x + y) % 4).to_byte())
    }
  }
  let encoded = encode(@image.AnyImage::Paletted(m))
  let decoded = decode_all(encoded)
  assert_true(decoded.image.length() > 0)
  let frame = decoded.image[0]
  // Compare color indices
  for y in 0..<8 {
    for x in 0..<8 {
      let (r1, g1, b1, a1) = @image.AnyImage::Paletted(m).at(x, y).rgba()
      let (r2, g2, b2, a2) = @image.AnyImage::Paletted(frame).at(x, y).rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
    }
  }
}

///|
/// Port of Go's TestTransparentIndex.
test "gif_transparent_index" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  let gif = decode_all(data)
  assert_true(gif.image.length() > 0)
  // Verify disposal and delay arrays match image count
  assert_eq(gif.delay.length(), gif.image.length())
  assert_eq(gif.disposal.length(), gif.image.length())
}

///|
/// Test GIF encode_image auto-quantizes an RGBA image.
test "gif_encode_image" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 8, 8))
  for y in 0..<8 {
    for x in 0..<8 {
      img.set_rgba(x, y, {
        r: (x * 32).to_byte(),
        g: (y * 32).to_byte(),
        b: b'\x40',
        a: b'\xff',
      })
    }
  }
  let encoded = encode_image(@image.AnyImage::RGBA(img))
  let decoded = decode(encoded)
  assert_eq(decoded.bounds().dx(), 8)
  assert_eq(decoded.bounds().dy(), 8)
}

///|
/// Test GIF decode_config returns correct dimensions.
test "gif_decode_config" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  let config = decode_config(data)
  assert_true(config.width > 0)
  assert_true(config.height > 0)
}

///|
test "gif_decode_config_local_palette_model" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  frame.set_color_index(0, 0, b'\x01')
  let encoded = encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel({ colors: [] }),
      width: 1,
      height: 1,
    },
  })
  let config = decode_config(encoded)
  assert_empty_palette_model(config.color_model)
  let decoded = decode_all(encoded)
  assert_empty_palette_model(decoded.config.color_model)
}

///|
test "gif_encode_explicit_canvas_without_global_palette" {
  let pal0 : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\x00', b: b'\x00', a: b'\xff' }),
    ],
  }
  let pal1 : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' }),
    ],
  }
  let frame0 = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal0)
  let frame1 = @image.new_image_paletted(@image.rect(1, 0, 2, 1), pal1)
  frame0.set_color_index(0, 0, b'\x01')
  frame1.set_color_index(1, 0, b'\x01')
  let encoded = encode_all({
    image: [frame0, frame1],
    delay: [0, 0],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: { color_model: @color.AnyModel::RGBAModel, width: 2, height: 1 },
  })
  let decoded = decode_all(encoded)
  assert_eq(decoded.config.width, 2)
  assert_eq(decoded.config.height, 1)
  assert_empty_palette_model(decoded.config.color_model)
  assert_eq(decoded.image.length(), 2)
  assert_eq(decoded.image[0].rect, @image.rect(0, 0, 1, 1))
  assert_eq(decoded.image[1].rect, @image.rect(1, 0, 2, 1))
}

///|
test "gif_encode_defaults_zero_config_from_first_frame" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(2, 3, 5, 7), pal)
  let encoded = encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: { color_model: @color.AnyModel::RGBAModel, width: 0, height: 0 },
  })
  let decoded = decode_all(encoded)
  assert_eq(decoded.config.width, 5)
  assert_eq(decoded.config.height, 7)
}

///|
test "gif_encode_rejects_mismatched_delay_length" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  let result = try? encode_all({
    image: [frame],
    delay: [],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal),
      width: 1,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
test "gif_encode_rejects_mismatched_disposal_length" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  let result = try? encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [b'\x00', b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal),
      width: 1,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
test "gif_encode_non_palette_config_model_means_no_global_palette" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  frame.set_color_index(0, 0, b'\x01')
  let encoded = encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: { color_model: @color.AnyModel::RGBAModel, width: 1, height: 1 },
  })
  let decoded = decode_all(encoded)
  assert_empty_palette_model(decoded.config.color_model)
  assert_eq(decoded.config.width, 1)
  assert_eq(decoded.config.height, 1)
}

///|
test "gif_encode_rejects_empty_frame_palette" {
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), { colors: [] })
  let result = try? encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel({ colors: [] }),
      width: 1,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
test "gif_encode_rejects_oversize_global_palette" {
  let pal = make_test_palette(257)
  let frame = @image.new_image_paletted(
    @image.rect(0, 0, 1, 1),
    make_test_palette(2),
  )
  frame.set_color_index(0, 0, b'\x00')
  let result = try? encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal),
      width: 1,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
test "gif_encode_rejects_oversize_local_palette" {
  let pal = make_test_palette(257)
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  frame.set_color_index(0, 0, b'\x00')
  let result = try? encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(make_test_palette(2)),
      width: 1,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
test "gif_encode_rejects_oversize_canvas" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  frame.set_color_index(0, 0, b'\x00')
  let result = try? encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal),
      width: 1 << 16,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
test "gif_encode_rejects_oversize_block" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let frame = @image.new_image_paletted(@image.rect(65535, 0, 65536, 1), pal)
  frame.set_color_index(65535, 0, b'\x01')
  let result = try? encode_all({
    image: [frame],
    delay: [0],
    loop_count: -1,
    disposal: [b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(pal),
      width: 65535,
      height: 1,
    },
  })
  assert_true(result is Err(_))
}

///|
/// Test encoding with very small palette.
test "gif_small_palette" {
  let pal : @color.Palette = {
    colors: [
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' }),
      @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
    ],
  }
  let m = @image.new_image_paletted(@image.rect(0, 0, 4, 4), pal)
  for y in 0..<4 {
    for x in 0..<4 {
      m.set_color_index(x, y, ((x + y) % 2).to_byte())
    }
  }
  let encoded = encode(@image.AnyImage::Paletted(m))
  let decoded = decode_all(encoded)
  assert_true(decoded.image.length() > 0)
  let frame = decoded.image[0]
  assert_eq(frame.rect.dx(), 4)
  assert_eq(frame.rect.dy(), 4)
}
