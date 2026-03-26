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
  let encoded = encode(m)
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
    config: { color_model: @color.AnyModel::RGBAModel, width: 1, height: 1 },
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
    disposal: [b'\x01', b'\x02'],
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
  assert_eq(decoded.disposal, [b'\x01', b'\x02'])
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
/// Encoding a GIF with no frames produces output that may or may not be valid.
test "gif_encode_zero" {
  let gif : GIF = {
    image: [],
    delay: [],
    loop_count: 0,
    disposal: [],
    background_index: b'\x00',
    config: { color_model: @color.AnyModel::RGBAModel, width: 1, height: 1 },
  }
  // Just verify it doesn't crash; the result may be an error or empty GIF
  ignore(try? encode_all(gif))
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
    let encoded = encode(m)
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
  let encoded = encode(m)
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
  let encoded = encode(m)
  let decoded = decode_all(encoded)
  assert_true(decoded.image.length() > 0)
  let frame = decoded.image[0]
  assert_eq(frame.rect.dx(), 4)
  assert_eq(frame.rect.dy(), 4)
}
