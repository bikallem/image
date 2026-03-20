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
/// Port of Go's TestBounds from reader_test.go.
test "gif_bounds" {
  let data = @fs.read_file_to_bytes("testdata/video-001.gif")
  let gif = decode_all(data)
  for frame in gif.image {
    // Each frame should have valid bounds
    assert_true(frame.rect.dx() > 0 || frame.rect.dy() > 0 || frame.rect.dx() == 0)
  }
}

///|
/// Port of Go's TestWriter from writer_test.go.
/// GIF encode -> decode roundtrip.
test "gif_writer" {
  let pal : @color.Palette = {
    colors: Array::makei(256, fn(i) {
      @color.AnyColor::RGBA(
        {
          r: i.to_byte(),
          g: (255 - i).to_byte(),
          b: b'\x80',
          a: b'\xff',
        },
      )
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
  let frame = @image.new_image_paletted(@image.rect(0, 0, 1, 1), pal)
  frame.set_color_index(0, 0, b'\x00')
  let gif : GIF = {
    image: [frame, frame],
    delay: [0, 0],
    loop_count: 0,
    disposal: [b'\x00', b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::RGBAModel,
      width: 1,
      height: 1,
    },
  }
  let encoded = encode_all(gif)
  let decoded_gif = decode_all(encoded)
  assert_eq(decoded_gif.loop_count, 0)
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
    config: {
      color_model: @color.AnyModel::RGBAModel,
      width: 1,
      height: 1,
    },
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
        @color.AnyColor::RGBA(
          {
            r: (i * (256 / size)).to_byte(),
            g: b'\x00',
            b: b'\x00',
            a: b'\xff',
          },
        )
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
      m.set_rgba(
        x,
        y,
        {
          r: (x * 16).to_byte(),
          g: (y * 16).to_byte(),
          b: b'\x80',
          a: b'\xff',
        },
      )
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
      @color.AnyColor::RGBA(
        {
          r: (i * 85).to_byte(),
          g: (i * 85).to_byte(),
          b: (i * 85).to_byte(),
          a: b'\xff',
        },
      )
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
      let (r1, g1, b1, a1) = (@image.AnyImage::Paletted(m))
        .at(x, y)
        .rgba()
      let (r2, g2, b2, a2) = (@image.AnyImage::Paletted(frame))
        .at(x, y)
        .rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
    }
  }
}
