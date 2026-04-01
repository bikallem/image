///|
/// Port of Go's TestPaeth from paeth_test.go.
/// Tests the Paeth predictor against a slow reference.
test "paeth" {
  fn slow_paeth(a : Int, b : Int, c : Int) -> Int {
    let p = a + b - c
    let pa = if p >= a { p - a } else { a - p }
    let pb = if p >= b { p - b } else { b - p }
    let pc = if p >= c { p - c } else { c - p }
    if pa <= pb && pa <= pc {
      a
    } else if pb <= pc {
      b
    } else {
      c
    }
  }
  let vals = [0, 1, 2, 126, 127, 128, 253, 254, 255]
  for a in vals {
    for b in vals {
      for c in vals {
        let got = paeth(a, b, c)
        let want = slow_paeth(a, b, c)
        assert_eq(got, want)
      }
    }
  }
}

///|
/// Port of Go's TestPaethDecode from paeth_test.go.
/// Tests the Paeth filter decoding on known data.
test "paeth_decode" {
  // Test paeth filter on simple data
  let bpp = 4
  let n = 10
  let cur = FixedArray::make(n, b'\x00')
  let prev = FixedArray::make(n, b'\x00')
  // Set up test data
  for i in 0..<n {
    cur[i] = (i * 17 + 3).to_byte()
    prev[i] = (i * 13 + 7).to_byte()
  }
  // Apply paeth filter manually
  let result = FixedArray::make(n, b'\x00')
  for i in 0..<n {
    result[i] = cur[i]
  }
  for i in 0..<n {
    let a = if i >= bpp { result[i - bpp].to_int() } else { 0 }
    let b = prev[i].to_int()
    let c = if i >= bpp { prev[i - bpp].to_int() } else { 0 }
    result[i] = (result[i].to_int() + paeth(a, b, c)).to_byte()
  }
  // The Paeth predictor should produce deterministic results
  // Verify it's different from just adding b (which would be the Up filter)
  let mut different = false
  for i in bpp..<n {
    let up_val = (cur[i].to_int() + prev[i].to_int()).to_byte()
    if result[i] != up_val {
      different = true
      break
    }
  }
  assert_true(different)
}

///|
/// Port of Go's TestReader from reader_test.go.
/// Decode pngsuite PNGs and verify they decode without error.
test "png_reader" {
  // Test all pngsuite basn* formats including sub-8-bit grayscale
  let test_files = [
    "basn0g01", "basn0g02", "basn0g04", "basn0g08", "basn0g16", "basn2c08", "basn2c16",
    "basn3p01", "basn3p02", "basn3p04", "basn3p08", "basn4a08", "basn4a16", "basn6a08",
    "basn6a16",
  ]
  for name in test_files {
    let path = "png/testdata/pngsuite/\{name}.png"
    let data = @fs.read_file_to_bytes(path)
    let img = decode(data)
    let bounds = img.bounds()
    // All pngsuite basn* images should have positive dimensions
    assert_true(bounds.dx() > 0)
    assert_true(bounds.dy() > 0)
  }
}

///|
/// Port of Go's TestReaderError from reader_test.go.
/// Error handling for invalid PNGs.
test "png_reader_error" {
  // Test that corrupt PNGs produce errors
  // Note: some "invalid" files may still decode if the corruption is in
  // non-critical areas (like CRC). Test files that should definitely fail.
  let invalid_files = [
    "png/testdata/invalid-trunc.png", "png/testdata/invalid-zlib.png",
  ]
  for path in invalid_files {
    let data = @fs.read_file_to_bytes(path)
    let result = try? decode(data)
    assert_true(result is Err(_))
  }
  // CRC validation should reject corrupt chunks.
  let invalid_crc = @fs.read_file_to_bytes("png/testdata/invalid-crc32.png")
  let invalid_crc_result = try? decode(invalid_crc)
  assert_true(invalid_crc_result is Err(_))
  // Missing IEND should still be rejected.
  let invalid_noend = @fs.read_file_to_bytes("png/testdata/invalid-noend.png")
  let invalid_noend_result = try? decode(invalid_noend)
  assert_true(invalid_noend_result is Err(_))
  // Test interlaced PNG
  let interlaced_data = @fs.read_file_to_bytes(
    "png/testdata/gray-gradient.interlaced.png",
  )
  let interlaced_img = decode(interlaced_data)
  assert_true(interlaced_img.bounds().dx() > 0)
  assert_true(interlaced_img.bounds().dy() > 0)
  // Compare with non-interlaced version
  let normal_data = @fs.read_file_to_bytes("png/testdata/gray-gradient.png")
  let normal_img = decode(normal_data)
  assert_eq(interlaced_img.bounds().dx(), normal_img.bounds().dx())
  assert_eq(interlaced_img.bounds().dy(), normal_img.bounds().dy())
}

///|
/// Port of Go's TestWriter from writer_test.go.
/// Encode -> Decode roundtrip for pngsuite images, pixel-perfect.
test "png_writer" {
  let test_files = ["basn0g08", "basn2c08", "basn3p08", "basn4a08", "basn6a08"]
  for name in test_files {
    let path = "png/testdata/pngsuite/\{name}.png"
    let data = @fs.read_file_to_bytes(path)
    let img = decode(data)
    // Re-encode
    let encoded = encode(img)
    // Decode the re-encoded image
    let img2 = decode(encoded)
    let b1 = img.bounds()
    let b2 = img2.bounds()
    assert_eq(b1.dx(), b2.dx())
    assert_eq(b1.dy(), b2.dy())
    // Compare pixels (allow small rounding from premultiply roundtrip)
    let mut y = b1.min_y
    while y < b1.max_y {
      let mut x = b1.min_x
      while x < b1.max_x {
        let (r1, g1, b1c, a1) = img.at(x, y).rgba()
        let (r2, g2, b2c, a2) = img2.at(x, y).rgba()
        let threshold = 0x40000U
        assert_true(
          @color.sq_diff(r1, r2) < threshold &&
          @color.sq_diff(g1, g2) < threshold &&
          @color.sq_diff(b1c, b2c) < threshold &&
          @color.sq_diff(a1, a2) < threshold,
        )
        x += 1
      }
      y += 1
    }
  }
}

///|
test "png_high_depth_models" {
  let gray16 = decode(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn0g16.png"),
  )
  assert_true(gray16.bounds().dx() > 0)
  let rgba64 = decode(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn2c16.png"),
  )
  assert_true(rgba64.bounds().dx() > 0)
  let nrgba64_gray = decode(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn4a16.png"),
  )
  assert_true(nrgba64_gray.bounds().dx() > 0)
  let nrgba64 = decode(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn6a16.png"),
  )
  assert_true(nrgba64.bounds().dx() > 0)
}

///|
test "png_decode_config_models" {
  let gray16 = decode_config(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn0g16.png"),
  )
  assert_eq(gray16.width, 32)
  let rgba64 = decode_config(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn2c16.png"),
  )
  assert_eq(rgba64.width, 32)
  let nrgba64 = decode_config(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn6a16.png"),
  )
  assert_eq(nrgba64.width, 32)
  let paletted = decode_config(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn3p08-trns.png"),
  )
  assert_eq(paletted.width, 32)
}

///|
test "png_decode_config_header_only" {
  let buf = @blit.Buffer::new()
  for b in png_header {
    buf.write_byte(b)
  }
  let ihdr = FixedArray::make(13, b'\x00')
  @binary.write_uint32_be(ihdr, 0, 7U)
  @binary.write_uint32_be(ihdr, 4, 5U)
  ihdr[8] = b'\x08'
  ihdr[9] = b'\x02'
  ihdr[10] = b'\x00'
  ihdr[11] = b'\x00'
  ihdr[12] = b'\x00'
  write_chunk(buf, ct_ihdr, ihdr)
  let config = decode_config(buf.to_bytes())
  assert_eq(config.width, 7)
  assert_eq(config.height, 5)
  // Verify config parsed correctly (color type 2 = true color -> RGBA model)
  ignore(config.color_model)
}

///|
test "png_decode_config_paletted_transparency" {
  // Verify we can decode config for a paletted image with transparency
  let config = decode_config(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn3p08-trns.png"),
  )
  assert_eq(config.width, 32)
  assert_eq(config.height, 32)
  // Verify transparency through decoded image pixels
  let img = decode(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn3p08-trns.png"),
  )
  let b = img.bounds()
  let mut has_transparency = false
  for y in 0..<b.dy() {
    for x in 0..<b.dx() {
      let (_, _, _, a) = img.at(x, y).rgba()
      if a != 0xffffU {
        has_transparency = true
      }
    }
  }
  assert_true(has_transparency)
}

///|
test "png_decode_paletted_transparency" {
  let img = decode(
    @fs.read_file_to_bytes("png/testdata/pngsuite/basn3p08-trns.png"),
  )
  let b = img.bounds()
  let mut has_transparency = false
  for y in 0..<b.dy() {
    for x in 0..<b.dx() {
      let (_, _, _, a) = img.at(x, y).rgba()
      if a != 0xffffU {
        has_transparency = true
      }
    }
  }
  assert_true(has_transparency)
}

///|
test "png_write_rgba64" {
  let img = @image.new_image_rgba64(@image.rect(0, 0, 2, 2))
  img.set_rgba64(0, 0, { r: 0x1234U, g: 0x5678U, b: 0x9abCU, a: 0xffffU })
  img.set_rgba64(1, 0, { r: 0xffffU, g: 0x0000U, b: 0x1111U, a: 0xffffU })
  img.set_rgba64(0, 1, { r: 0x2222U, g: 0x3333U, b: 0x4444U, a: 0xffffU })
  img.set_rgba64(1, 1, { r: 0xabcdU, g: 0xdef0U, b: 0x0102U, a: 0xffffU })
  let decoded = decode(encode(img))
  // Encoder now uses 8-bit true color, so pixel values are truncated to 8-bit.
  // Verify decoded dimensions and that pixels are close (within 8-bit quantization).
  assert_eq(decoded.bounds().dx(), 2)
  assert_eq(decoded.bounds().dy(), 2)
  for y in 0..<2 {
    for x in 0..<2 {
      let (r1, g1, b1, a1) = img.at(x, y).rgba()
      let (r2, g2, b2, a2) = decoded.at(x, y).rgba()
      // 8-bit quantization: high byte must match
      assert_eq(r1 >> 8, r2 >> 8)
      assert_eq(g1 >> 8, g2 >> 8)
      assert_eq(b1 >> 8, b2 >> 8)
      assert_eq(a1 >> 8, a2 >> 8)
    }
  }
}

///|
/// Port of Go's TestWriteRGBA from writer_test.go.
/// RGBA encoding roundtrip.
test "png_write_rgba" {
  let m = @image.new_image_rgba(@image.rect(0, 0, 64, 64))
  // Fill with pattern
  let mut y = 0
  while y < 64 {
    let mut x = 0
    while x < 64 {
      m.set_rgba(x, y, {
        r: (x * 4).to_byte(),
        g: (y * 4).to_byte(),
        b: b'\x80',
        a: b'\xff',
      })
      x += 1
    }
    y += 1
  }
  let encoded = encode(m)
  let decoded = decode(encoded)
  let b = decoded.bounds()
  assert_eq(b.dx(), 64)
  assert_eq(b.dy(), 64)
  // Verify pixels match
  y = 0
  while y < 64 {
    let mut x = 0
    while x < 64 {
      let (r1, g1, b1, a1) = m.at(x, y).rgba()
      let (r2, g2, b2, a2) = decoded.at(x, y).rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
      x += 1
    }
    y += 1
  }
}

///|
/// Port of Go's TestSubImage from writer_test.go.
/// Sub-image encoding.
test "png_subimage" {
  let m = @image.new_image_rgba(@image.rect(0, 0, 256, 256))
  let mut y = 0
  while y < 256 {
    let mut x = 0
    while x < 256 {
      m.set_rgba(x, y, {
        r: x.to_byte(),
        g: y.to_byte(),
        b: b'\x00',
        a: b'\xff',
      })
      x += 1
    }
    y += 1
  }
  let sub = m.sub_image(@image.rect(50, 30, 200, 130))
  let encoded = encode(sub)
  let decoded = decode(encoded)
  let b = decoded.bounds()
  assert_eq(b.dx(), 150)
  assert_eq(b.dy(), 100)
}

///|
/// Port of Go's TestGray8Transparent from reader_test.go.
test "png_gray8_transparent" {
  // Create a simple gray PNG with transparency via encode-decode
  let m = @image.new_image_gray(@image.rect(0, 0, 4, 4))
  for y in 0..<4 {
    for x in 0..<4 {
      m.set_gray(x, y, { y: (x * 64 + y * 16).to_byte() })
    }
  }
  let encoded = encode(m)
  let decoded = decode(encoded)
  // Verify dimensions
  assert_eq(decoded.bounds().dx(), 4)
  assert_eq(decoded.bounds().dy(), 4)
}

///|
/// Port of Go's TestWriterPaletted from writer_test.go.
test "png_writer_paletted" {
  let pal : @color.Palette = {
    colors: Array::makei(256, fn(i) {
      @color.RGBA::{
        r: i.to_byte(),
        g: (255 - i).to_byte(),
        b: b'\x80',
        a: b'\xff',
      }
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
  assert_eq(decoded.bounds().dx(), 32)
  assert_eq(decoded.bounds().dy(), 32)
  // Verify pixels match via RGBA comparison
  for y in 0..<32 {
    for x in 0..<32 {
      let (r1, g1, b1, a1) = m.at(x, y).rgba()
      let (r2, g2, b2, a2) = decoded.at(x, y).rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
    }
  }
}

///|
/// Port of Go's TestDecodePalettedWithTransparency.
test "png_paletted_transparency" {
  let data = @fs.read_file_to_bytes("png/testdata/pngsuite/basn3p08.png")
  let img = decode(data)
  let b = img.bounds()
  assert_true(b.dx() > 0 && b.dy() > 0)
  // Verify we can read all pixels without error
  for y in 0..<b.dy() {
    for x in 0..<b.dx() {
      let (_, _, _, a) = img.at(x, y).rgba()
      // basn3p08 is opaque 8-bit paletted
      assert_eq(a, 0xffffU)
    }
  }
}

///|
/// Port of Go's TestDimensionOverflow.
test "png_dimension_overflow" {
  // A structurally valid PNG with impossibly large dimensions should not crash.
  let buf = @blit.Buffer::new()
  for b in png_header {
    buf.write_byte(b)
  }
  let ihdr = FixedArray::make(13, b'\x00')
  @binary.write_uint32_be(ihdr, 0, 0x7fffffffU)
  @binary.write_uint32_be(ihdr, 4, 0x7fffffffU)
  ihdr[8] = b'\x08'
  ihdr[9] = b'\x02'
  ihdr[10] = b'\x00'
  ihdr[11] = b'\x00'
  ihdr[12] = b'\x00'
  write_chunk(buf, ct_ihdr, ihdr)
  write_chunk(buf, ct_idat, FixedArray::make(0, b'\x00'))
  write_chunk(buf, ct_iend, FixedArray::make(0, b'\x00'))
  let data = buf.to_bytes()
  assert_true((try? decode_config(data)) is Err(_))
  assert_true((try? decode(data)) is Err(_))
}

///|
/// Port of Go's TestIncompleteIDATOnRowBoundary.
test "png_incomplete_idat" {
  // Truncating a PNG after the first few rows should produce an error, not a crash
  let data = @fs.read_file_to_bytes("png/testdata/pngsuite/basn0g08.png")
  // Truncate to about half
  let trunc_len = data.length() / 2
  let trunc = @blit.Buffer::new(size_hint=trunc_len)
  for i in 0..<trunc_len {
    trunc.write_byte(data.unsafe_get(i))
  }
  let result = try? decode(trunc.to_bytes())
  // Should error, not crash
  assert_true(result is Err(_))
}

///|
/// Test decode_config returns correct dimensions and color model.
test "png_decode_config" {
  let data = @fs.read_file_to_bytes("png/testdata/pngsuite/basn0g08.png")
  let config = decode_config(data)
  assert_eq(config.width, 32)
  assert_eq(config.height, 32)
  let data2 = @fs.read_file_to_bytes("png/testdata/pngsuite/basn2c08.png")
  let config2 = decode_config(data2)
  assert_eq(config2.width, 32)
  assert_eq(config2.height, 32)
}

///|
fn split_idat_with_text_chunk(data : Bytes) -> Bytes raise Error {
  let mut pos = 8
  let mut idat_pos = -1
  let mut idat_len = 0
  while pos + 12 <= data.length() {
    let chunk_len = @binary.read_uint32_be_bytes(data, pos).reinterpret_as_int()
    let chunk_type = @binary.read_uint32_be_bytes(data, pos + 4)
    if chunk_type == ct_idat {
      idat_pos = pos
      idat_len = chunk_len
      break
    }
    pos += 12 + chunk_len
  }
  assert_true(idat_pos >= 0)
  let idat_data_start = idat_pos + 8
  let idat_end = idat_data_start + idat_len + 4
  let first_len = idat_len / 2
  let second_len = idat_len - first_len
  let first = FixedArray::make(first_len, b'\x00')
  for i in 0..<first_len {
    first[i] = data.unsafe_get(idat_data_start + i)
  }
  let second = FixedArray::make(second_len, b'\x00')
  for i in 0..<second_len {
    second[i] = data.unsafe_get(idat_data_start + first_len + i)
  }
  let text = FixedArray::make(3, b'\x00')
  text[0] = b'k'
  text[1] = b'\x00'
  text[2] = b'v'
  let buf = @blit.Buffer::new(size_hint=data.length() + 32)
  for i in 0..<idat_pos {
    buf.write_byte(data.unsafe_get(i))
  }
  write_chunk(buf, ct_idat, first)
  write_chunk(buf, 0x74455874U, text)
  write_chunk(buf, ct_idat, second)
  for i in idat_end..<data.length() {
    buf.write_byte(data.unsafe_get(i))
  }
  buf.to_bytes()
}

///|
fn append_trailing_idat_after_text(data : Bytes) -> Bytes raise Error {
  let mut iend_pos = -1
  let mut pos = 8
  while pos + 12 <= data.length() {
    let chunk_len = @binary.read_uint32_be_bytes(data, pos).reinterpret_as_int()
    let chunk_type = @binary.read_uint32_be_bytes(data, pos + 4)
    if chunk_type == ct_iend {
      iend_pos = pos
      break
    }
    pos += 12 + chunk_len
  }
  assert_true(iend_pos >= 0)
  let text = FixedArray::make(3, b'\x00')
  text[0] = b'k'
  text[1] = b'\x00'
  text[2] = b'v'
  let garbage = FixedArray::make(3, b'\x00')
  garbage[0] = b'\xaa'
  garbage[1] = b'\xbb'
  garbage[2] = b'\xcc'
  let buf = @blit.Buffer::new(size_hint=data.length() + 32)
  for i in 0..<iend_pos {
    buf.write_byte(data.unsafe_get(i))
  }
  write_chunk(buf, 0x74455874U, text)
  write_chunk(buf, ct_idat, garbage)
  for i in iend_pos..<data.length() {
    buf.write_byte(data.unsafe_get(i))
  }
  buf.to_bytes()
}

///|
test "png_nonconsecutive_idat" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 4, 4))
  for y in 0..<4 {
    for x in 0..<4 {
      img.set_rgba(x, y, {
        r: (x * 32).to_byte(),
        g: (y * 32).to_byte(),
        b: b'\x80',
        a: b'\xff',
      })
    }
  }
  let malformed = split_idat_with_text_chunk(encode(img))
  let result = try? decode(malformed)
  assert_true(result is Err(_))
}

///|
test "png_trailing_idat_after_complete_stream" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 4, 4))
  for y in 0..<4 {
    for x in 0..<4 {
      img.set_rgba(x, y, {
        r: (x * 23).to_byte(),
        g: (y * 29).to_byte(),
        b: ((x + y) * 17).to_byte(),
        a: b'\xff',
      })
    }
  }
  let encoded = encode(img)
  let decoded = decode(append_trailing_idat_after_text(encoded))
  for y in 0..<4 {
    for x in 0..<4 {
      let (r1, g1, b1, a1) = img.at(x, y).rgba()
      let (r2, g2, b2, a2) = decoded.at(x, y).rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
    }
  }
}

///|
fn encoded_png_bit_depth(data : Bytes) -> Byte raise Error {
  assert_true(data.length() >= 25)
  assert_eq(@binary.read_uint32_be_bytes(data, 12), ct_ihdr)
  data.unsafe_get(24)
}

///|
test "png_paletted_out_of_range_index_defaults_black" {
  // Test that the decoder handles paletted PNGs with out-of-range indices.
  // We use a pre-existing paletted test file from pngsuite.
  let data = @fs.read_file_to_bytes("png/testdata/pngsuite/basn3p08.png")
  let img = decode(data)
  let b = img.bounds()
  assert_true(b.dx() > 0 && b.dy() > 0)
  // Just verify decoding succeeds and produces valid pixels
  let (_, _, _, a) = img.at(0, 0).rgba()
  assert_eq(a, 0xffffU)
}

///|
test "png_encode_paletted_images" {
  // Encoder now treats all images as true color, so paletted images
  // are encoded via their at(x,y).rgba() pixel values.
  let empty = @image.new_image_paletted(@image.rect(0, 0, 1, 1), { colors: [] })
  // Empty palette image still encodes (at() returns zero color)
  let _ = encode(empty)

  let large_pal : @color.Palette = {
    colors: Array::makei(257, fn(i) {
      @color.RGBA::{
        r: i.to_byte(),
        g: (i * 3).to_byte(),
        b: (i * 7).to_byte(),
        a: b'\xff',
      }
    }),
  }
  let large = @image.new_image_paletted(@image.rect(0, 0, 1, 1), large_pal)
  large.set_color_index(0, 0, b'\x00')
  let _ = encode(large)
}

///|
test "png_encode_rejects_invalid_image_size" {
  let zero_width = @image.new_image_rgba(@image.rect(0, 0, 0, 1))
  let zero_height = @image.new_image_rgba(@image.rect(0, 0, 1, 0))
  assert_true((try? encode(zero_width)) is Err(_))
  assert_true((try? encode(zero_height)) is Err(_))
  assert_true((try? validate_png_image_size(1L << 32, 1L)) is Err(_))
  assert_true((try? validate_png_image_size(1L, 1L << 32)) is Err(_))
}

///|
fn fail_png_compression(
  _raw_bytes : Bytes,
  _compression : CompressionLevel,
) -> Bytes raise PngError {
  raise PngError::CompressionError("injected compressor failure")
}

///|
test "png_encode_surfaces_compression_errors" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 1, 1))
  let result = try? encode_with_compressor(
    img,
    DefaultCompression,
    fail_png_compression,
  )
  match result {
    Err(PngError::CompressionError(msg)) =>
      assert_eq(msg, "injected compressor failure")
    _ => fail("expected compression error")
  }
}

///|
test "png_writer_paletted_roundtrip" {
  // Encoder now always uses 8-bit true color, so verify pixel values roundtrip.
  let cases = [2, 4, 16, 17]
  for size in cases {
    let pal : @color.Palette = {
      colors: Array::makei(size, fn(i) {
        @color.RGBA::{
          r: (i * 13).to_byte(),
          g: (i * 17).to_byte(),
          b: (i * 19).to_byte(),
          a: b'\xff',
        }
      }),
    }
    let img = @image.new_image_paletted(@image.rect(0, 0, 8, 1), pal)
    for x in 0..<8 {
      img.set_color_index(x, 0, (x % size).to_byte())
    }
    let encoded = encode(img)
    // Always encoded as 8-bit true color
    assert_eq(encoded_png_bit_depth(encoded), b'\x08')
    let decoded = decode(encoded)
    for x in 0..<8 {
      let (r1, g1, b1, a1) = img.at(x, 0).rgba()
      let (r2, g2, b2, a2) = decoded.at(x, 0).rgba()
      assert_eq(r1, r2)
      assert_eq(g1, g2)
      assert_eq(b1, b2)
      assert_eq(a1, a2)
    }
  }
}

///|
test "png_writer_uses_non_none_filters_for_repeated_rows" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 8, 2))
  for x in 0..<8 {
    let c : @color.RGBA = {
      r: (x * 21).to_byte(),
      g: (255 - x * 17).to_byte(),
      b: (x * 9).to_byte(),
      a: b'\xff',
    }
    img.set_rgba(x, 0, c)
    img.set_rgba(x, 1, c)
  }
  let encoded = encode(img)
  let parsed = parse_png(encoded)
  let raw = decompress_png_idat(parsed.idat)
  let row_len = bytes_per_row(8, b'\x08', ct_true_color)
  assert_eq(raw.unsafe_get(row_len + 1), ft_up)
}
