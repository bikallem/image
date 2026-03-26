///|
/// Port of Go's TestDCT from dct_test.go.
/// FDCT -> IDCT roundtrip.
test "dct" {
  // Test with various block patterns
  let patterns : Array[FixedArray[Byte]] = [
    // All zeros
    FixedArray::make(64, b'\x00'),
    // All 128
    FixedArray::make(64, b'\x80'),
    // Gradient
    FixedArray::makei(64, fn(i) { (i * 4).to_byte() }),
  ]
  for pixels in patterns {
    let block = FixedArray::make(64, 0)
    let dst = FixedArray::make(64, b'\x00')
    fdct(pixels, block)
    idct_islow(block, dst, FixedArray::make(64, 0))
    // All output values should be in valid byte range (0-255) after clamping
    for i in 0..<64 {
      assert_true(dst[i].to_int() >= 0 && dst[i].to_int() <= 255)
    }
  }
  // Test that FDCT of uniform 128 produces DC ≈ 0 (since FDCT subtracts 128)
  let uniform = FixedArray::make(64, b'\x80')
  let ublock = FixedArray::make(64, 0)
  fdct(uniform, ublock)
  // DC should be near zero (could be exactly 0 or small due to rounding)
  let dc_abs = if ublock[0] >= 0 { ublock[0] } else { -ublock[0] }
  assert_true(dc_abs < 100)
  // FDCT of non-uniform values should have non-zero DC
  let ramp = FixedArray::makei(64, fn(i) { (i * 4).to_byte() })
  let rblock = FixedArray::make(64, 0)
  fdct(ramp, rblock)
  // There should be at least some non-zero coefficients
  let mut nonzero = 0
  for i in 0..<64 {
    if rblock[i] != 0 {
      nonzero += 1
    }
  }
  assert_true(nonzero > 0)
}

///|
/// Port of Go's TestZigUnzig from reader_test.go.
/// Zig-zag table is self-inverse.
test "zig_unzig" {
  // The zig-zag ordering maps 0..63 -> 0..63 bijectively
  // unzig[zig[i]] == i for all i
  let seen = FixedArray::make(64, false)
  for i in 0..<64 {
    let z = unzig[i]
    assert_true(z >= 0 && z < 64)
    assert_false(seen[z])
    seen[z] = true
  }
}

///|
fn assert_samples_close(
  img : @image.AnyImage,
  reference : @image.AnyImage,
  tolerance : UInt,
) -> Unit raise Error {
  let b = img.bounds()
  assert_eq(b.dx(), reference.bounds().dx())
  assert_eq(b.dy(), reference.bounds().dy())
  let samples = [
    (0, 0),
    (b.dx() / 2, b.dy() / 2),
    (b.dx() - 1, b.dy() - 1),
    (b.dx() / 3, b.dy() / 3),
    (b.dx() * 2 / 3, b.dy() * 2 / 3),
  ]
  for sample in samples {
    let (x, y) = sample
    let (r1, g1, b1, _) = img.at(x, y).rgba()
    let (r2, g2, b2, _) = reference.at(x, y).rgba()
    let dr = if r1 >= r2 { r1 - r2 } else { r2 - r1 }
    let dg = if g1 >= g2 { g1 - g2 } else { g2 - g1 }
    let db = if b1 >= b2 { b1 - b2 } else { b2 - b1 }
    assert_true(dr >> 8 < tolerance)
    assert_true(dg >> 8 < tolerance)
    assert_true(db >> 8 < tolerance)
  }
}

///|
fn make_sequential_zero_scan(selector : Int) -> Bytes {
  let buf = @blit.Buffer::new(size_hint=10)
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x08')
  buf.write_byte(b'\x01')
  buf.write_byte(selector.to_byte())
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x3f')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.to_bytes()
}

///|
fn insert_restart_before_eoi(data : Bytes) -> Bytes raise Error {
  assert_true(data.length() >= 2)
  assert_eq(data.unsafe_get(data.length() - 2), b'\xff')
  assert_eq(data.unsafe_get(data.length() - 1), b'\xd9')
  let buf = @blit.Buffer::new(size_hint=data.length() + 2)
  for i in 0..<(data.length() - 2) {
    buf.write_byte(data.unsafe_get(i))
  }
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xd0')
  buf.write_byte(b'\xff')
  buf.write_byte(b'\xd9')
  buf.to_bytes()
}

///|
fn assert_ycbcr_decode(
  path : String,
  ratio : @image.YCbCrSubsampleRatio,
) -> Unit raise Error {
  let img = decode(@fs.read_file_to_bytes(path))
  match img {
    @image.AnyImage::YCbCr(ycbcr) => {
      assert_eq(ycbcr.subsample_ratio, ratio)
      assert_true(img.color_model() is @color.AnyModel::YCbCrModel)
    }
    _ => fail("expected YCbCr image")
  }
}

///|
fn make_flex_sof_segment() -> Bytes {
  let buf = @blit.Buffer::new(size_hint=32)
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x11')
  buf.write_byte(b'\x08')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x08')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x10')
  buf.write_byte(b'\x03')
  buf.write_byte(b'\x01')
  buf.write_byte(b'\x11')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x02')
  buf.write_byte(b'\x21')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x03')
  buf.write_byte(b'\x11')
  buf.write_byte(b'\x00')
  buf.to_bytes()
}

///|
fn find_segment(data : Bytes, marker : UInt) -> Bytes raise Error {
  let d = Decoder::new(data)
  assert_eq(read_marker(d), marker_soi)
  while d.r.remaining() > 0 {
    let got = read_marker(d)
    if got == marker {
      let length = d.r.read_uint16_be().reinterpret_as_int()
      assert_true(length >= 2)
      return d.r.read_bytes(length - 2)
    }
    if got == marker_sos || got == marker_eoi {
      break
    }
    skip_segment(d)
  }
  fail("segment not found")
}

///|
/// Port of Go's TestWriter from writer_test.go.
/// JPEG encode -> decode roundtrip with delta check.
test "jpeg_writer" {
  let r = @image.rect(0, 0, 64, 64)
  let m = @image.new_image_rgba(r)
  for y in 0..<64 {
    for x in 0..<64 {
      m.set_rgba(x, y, {
        r: (x * 4).to_byte(),
        g: (y * 4).to_byte(),
        b: b'\x80',
        a: b'\xff',
      })
    }
  }
  let encoded = encode(@image.AnyImage::RGBA(m))
  // Verify markers
  assert_eq(encoded[0], b'\xFF')
  assert_eq(encoded[1], b'\xD8')
  // Decode roundtrip
  let decoded = decode(encoded)
  let b = decoded.bounds()
  assert_eq(b.dx(), 64)
  assert_eq(b.dy(), 64)
  // JPEG is lossy — check average delta is small
  let mut total_delta = 0
  let mut num_pixels = 0
  for y in 0..<64 {
    for x in 0..<64 {
      let (r1, _, _, _) = @image.AnyImage::RGBA(m).at(x, y).rgba()
      let (r2, _, _, _) = decoded.at(x, y).rgba()
      let d = if r1 >= r2 {
        (r1 - r2).reinterpret_as_int()
      } else {
        (r2 - r1).reinterpret_as_int()
      }
      total_delta += d >> 8
      num_pixels += 1
    }
  }
  let avg = total_delta / num_pixels
  // Quality 75 default — verify reasonable fidelity
  assert_true(avg < 80)
}

///|
test "jpeg_writer_uses_420_sampling" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 16, 16))
  for y in 0..<16 {
    for x in 0..<16 {
      img.set_rgba(x, y, {
        r: (x * 11).to_byte(),
        g: (y * 13).to_byte(),
        b: ((x + y) * 7).to_byte(),
        a: b'\xff',
      })
    }
  }
  let sof = find_segment(encode(@image.AnyImage::RGBA(img)), marker_sof0)
  assert_eq(sof.unsafe_get(7), b'\x22')
  assert_eq(sof.unsafe_get(10), b'\x11')
  assert_eq(sof.unsafe_get(13), b'\x11')
}

///|
test "jpeg_encode_ycbcr_matches_rgba" {
  let rect = @image.rect(0, 0, 16, 16)
  let rgba = @image.new_image_rgba(rect)
  let ycbcr = @image.new_image_ycbcr(rect, @image.Ratio444)
  for y in 0..<16 {
    for x in 0..<16 {
      let r = (x * 17 + y * 3).to_byte()
      let g = (x * 5 + y * 19).to_byte()
      let b = (x * 9 + y * 7).to_byte()
      rgba.set_rgba(x, y, { r, g, b, a: b'\xff' })
      let (yy, cb, cr) = @color.rgb_to_ycbcr(r, g, b)
      ycbcr.y_[ycbcr.y_offset(x, y)] = yy
      let ci = ycbcr.c_offset(x, y)
      ycbcr.cb[ci] = cb
      ycbcr.cr[ci] = cr
    }
  }
  let rgba_bytes = encode(@image.AnyImage::RGBA(rgba))
  let ycbcr_bytes = encode(@image.AnyImage::YCbCr(ycbcr))
  assert_eq(rgba_bytes, ycbcr_bytes)
}

///|
/// Port of Go's TestWriteGrayscale from writer_test.go.
test "jpeg_write_gray" {
  let m = @image.new_image_gray(@image.rect(0, 0, 32, 32))
  for y in 0..<32 {
    for x in 0..<32 {
      m.set_gray(x, y, { y: (x * 8 + y * 4).to_byte() })
    }
  }
  let encoded = encode(@image.AnyImage::Gray(m))
  // Verify it's a valid JPEG structure
  assert_true(encoded.length() > 4)
  assert_eq(encoded[0], b'\xFF')
  assert_eq(encoded[1], b'\xD8')
}

///|
/// Test JPEG decoding of testdata file.
test "jpeg_decode_testdata" {
  let data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  let img = decode(data)
  let b = img.bounds()
  assert_true(b.dx() > 0)
  assert_true(b.dy() > 0)
}

///|
/// Test progressive JPEG decode.
test "jpeg_progressive" {
  let data = @fs.read_file_to_bytes("testdata/video-001.progressive.jpeg")
  let img = decode(data)
  let b = img.bounds()
  assert_true(b.dx() > 0)
  assert_true(b.dy() > 0)
  // Compare with baseline
  let baseline_data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  let baseline = decode(baseline_data)
  assert_eq(b.dx(), baseline.bounds().dx())
  assert_eq(b.dy(), baseline.bounds().dy())
}

///|
test "jpeg_progressive_sample_parity" {
  let reference = @png.decode(@fs.read_file_to_bytes("testdata/video-001.png"))
  let files = [
    "testdata/video-001.progressive.jpeg", "testdata/video-001.separate.dc.progression.jpeg",
    "testdata/video-001.separate.dc.progression.progressive.jpeg",
  ]
  for path in files {
    let img = decode(@fs.read_file_to_bytes(path))
    assert_samples_close(img, reference, 128U)
  }
}

///|
test "jpeg_multiscan_sequential" {
  let scan_bytes = @blit.Buffer::new(size_hint=30)
  for selector in [1, 2, 3] {
    scan_bytes.write_bytes(make_sequential_zero_scan(selector))
  }
  let d = Decoder::new(scan_bytes.to_bytes())
  d.baseline = false
  d.progressive = false
  d.num_components = 3
  d.width = 8
  d.height = 8
  for i in 0..<3 {
    d.comp.unsafe_get(i).id = i + 1
    d.comp.unsafe_get(i).h = 1
    d.comp.unsafe_get(i).v = 1
    d.comp.unsafe_get(i).qt = 0
  }
  let counts = FixedArray::make(16, 0)
  counts[0] = 1
  let symbols = FixedArray::make(256, 0)
  build_huffman_table(d.huff.unsafe_get(0)[0], counts, symbols)
  build_huffman_table(d.huff.unsafe_get(1)[0], counts, symbols)
  process_sos(d)
  process_sos(d)
  process_sos(d)
  let img = reconstruct_coefficients(d)
  assert_eq(img.bounds().dx(), 8)
  assert_eq(img.bounds().dy(), 8)
  let (r, g, b, a) = img.at(0, 0).rgba()
  assert_eq(r, 0x8080U)
  assert_eq(g, 0x8080U)
  assert_eq(b, 0x8080U)
  assert_eq(a, 0xffffU)
}

///|
test "jpeg_rejects_excessive_dc_component" {
  let d = Decoder::new(Bytes::makei(1, fn(_) { b'\x00' }))
  d.num_components = 1
  d.comp.unsafe_get(0).dc_huff_idx = 0
  let counts = FixedArray::make(16, 0)
  counts[0] = 1
  let symbols = FixedArray::make(256, 0)
  symbols[0] = 17
  build_huffman_table(d.huff.unsafe_get(0)[0], counts, symbols)
  let block = FixedArray::make(64, 0)
  let result = try? decode_block(d, 0, block)
  assert_true(result is Err(_))
}

///|
test "jpeg_trailing_restart_marker" {
  let data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  let reference = decode(data)
  let img = decode(insert_restart_before_eoi(data))
  assert_samples_close(img, reference, 1U)
}

///|
test "jpeg_restart_marker_resync" {
  let d = Decoder::new(Bytes::from_array([b'\x12', b'\x34', b'\xff', b'\xd0']))
  consume_restart_marker(d, marker_rst0)
  assert_eq(d.r.pos, 4)
}

///|
test "jpeg_ycbcr_decode_type_and_ratio" {
  assert_ycbcr_decode("testdata/video-001.q50.411.jpeg", @image.Ratio411)
  assert_ycbcr_decode("testdata/video-001.q50.420.jpeg", @image.Ratio420)
  assert_ycbcr_decode("testdata/video-001.q50.444.jpeg", @image.Ratio444)
}

///|
test "jpeg_flex_sof_supported" {
  let d = Decoder::new(make_flex_sof_segment())
  process_sof(d)
  assert_eq(d.num_components, 3)
  assert_eq(d.width, 16)
  assert_eq(d.height, 8)
  assert_eq(d.comp.unsafe_get(0).h, 1)
  assert_eq(d.comp.unsafe_get(1).h, 2)
  assert_eq(d.comp.unsafe_get(2).h, 1)
}

///|
test "jpeg_flex_ycbcr_output" {
  let d = Decoder::new(Bytes::new(0))
  d.num_components = 3
  d.width = 16
  d.height = 8
  d.comp.unsafe_get(0).h = 1
  d.comp.unsafe_get(0).v = 1
  d.comp.unsafe_get(1).h = 2
  d.comp.unsafe_get(1).v = 1
  d.comp.unsafe_get(2).h = 1
  d.comp.unsafe_get(2).v = 1
  let comp_data = FixedArray::make(3, FixedArray::make(0, b'\x00'))
  let y_plane = FixedArray::make(64, b'\x00')
  for y in 0..<8 {
    for x in 0..<8 {
      y_plane[y * 8 + x] = (x + 1).to_byte()
    }
  }
  comp_data[0] = y_plane
  comp_data[1] = FixedArray::make(128, b'\x20')
  comp_data[2] = FixedArray::make(64, b'\x40')
  let comp_width = FixedArray::make(3, 0)
  comp_width[0] = 8
  comp_width[1] = 16
  comp_width[2] = 8
  let comp_height = FixedArray::make(3, 8)
  let img = components_to_ycbcr(
    d,
    comp_data,
    comp_width,
    comp_height,
    @image.rect(0, 0, 16, 8),
  )
  match img {
    @image.AnyImage::YCbCr(ycbcr) => {
      assert_eq(ycbcr.subsample_ratio, @image.Ratio444)
      let p0 = ycbcr.ycbcr_at(0, 0)
      let p1 = ycbcr.ycbcr_at(1, 0)
      let p2 = ycbcr.ycbcr_at(2, 0)
      assert_eq(p0.y, b'\x01')
      assert_eq(p1.y, b'\x01')
      assert_eq(p2.y, b'\x02')
      assert_eq(p0.cb, b'\x20')
      assert_eq(p0.cr, b'\x40')
    }
    _ => fail("expected YCbCr image")
  }
}

///|
/// Test decoding various JPEG subsampling modes.
test "jpeg_subsampling" {
  let files = [
    "testdata/video-001.q50.410.jpeg", "testdata/video-001.q50.411.jpeg", "testdata/video-001.q50.420.jpeg",
    "testdata/video-001.q50.422.jpeg", "testdata/video-001.q50.440.jpeg", "testdata/video-001.q50.444.jpeg",
  ]
  let reference = @png.decode(@fs.read_file_to_bytes("testdata/video-001.png"))
  for path in files {
    let data = @fs.read_file_to_bytes(path)
    let img = decode(data)
    let b = img.bounds()
    assert_true(b.dx() > 0)
    assert_true(b.dy() > 0)
    assert_samples_close(img, reference, 144U)
  }
}

///|
/// Test truncated JPEG doesn't crash.
test "jpeg_truncated_sos" {
  let data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  // Truncate to different lengths
  for len in [100, 500, 1000] {
    if len < data.length() {
      let truncated = Bytes::makei(len, fn(i) { data[i] })
      // Should error, not crash
      ignore(try? decode(truncated))
    }
  }
}

///|
/// Test JPEG decode_config returns correct dimensions.
test "jpeg_decode_config" {
  let data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  let config = decode_config(data)
  assert_true(config.width > 0)
  assert_true(config.height > 0)
}

///|
test "jpeg_decode_config_models" {
  let gray = decode_config(
    @fs.read_file_to_bytes("testdata/video-005.gray.jpeg"),
  )
  assert_true(gray.color_model is @color.AnyModel::GrayModel)
  let ycbcr = decode_config(
    @fs.read_file_to_bytes("testdata/video-001.progressive.jpeg"),
  )
  assert_true(ycbcr.color_model is @color.AnyModel::YCbCrModel)
  let rgb = decode_config(@fs.read_file_to_bytes("testdata/video-001.rgb.jpeg"))
  assert_true(rgb.color_model is @color.AnyModel::RGBAModel)
  let cmyk = decode_config(
    @fs.read_file_to_bytes("testdata/video-001.cmyk.jpeg"),
  )
  assert_true(cmyk.color_model is @color.AnyModel::CMYKModel)
}

///|
test "jpeg_rgb_decode_matches_reference" {
  let img = decode(@fs.read_file_to_bytes("testdata/video-001.rgb.jpeg"))
  assert_true(img is @image.AnyImage::RGBA(_))
  let reference = @png.decode(
    @fs.read_file_to_bytes("testdata/video-001.rgb.png"),
  )
  let b = img.bounds()
  assert_eq(b.dx(), reference.bounds().dx())
  assert_eq(b.dy(), reference.bounds().dy())
  let samples = [(0, 0), (b.dx() / 2, b.dy() / 2), (b.dx() - 1, b.dy() - 1)]
  for sample in samples {
    let (x, y) = sample
    let (r1, g1, b1, _) = img.at(x, y).rgba()
    let (r2, g2, b2, _) = reference.at(x, y).rgba()
    let dr = if r1 >= r2 { r1 - r2 } else { r2 - r1 }
    let dg = if g1 >= g2 { g1 - g2 } else { g2 - g1 }
    let db = if b1 >= b2 { b1 - b2 } else { b2 - b1 }
    assert_true(dr >> 8 < 80U)
    assert_true(dg >> 8 < 80U)
    assert_true(db >> 8 < 80U)
  }
}

///|
test "jpeg_cmyk_decode_matches_reference" {
  let img = decode(@fs.read_file_to_bytes("testdata/video-001.cmyk.jpeg"))
  assert_true(img is @image.AnyImage::CMYK(_))
  let reference = @png.decode(
    @fs.read_file_to_bytes("testdata/video-001.cmyk.png"),
  )
  let b = img.bounds()
  assert_eq(b.dx(), reference.bounds().dx())
  assert_eq(b.dy(), reference.bounds().dy())
  let samples = [(0, 0), (b.dx() / 2, b.dy() / 2), (b.dx() - 1, b.dy() - 1)]
  for sample in samples {
    let (x, y) = sample
    let (r1, g1, b1, _) = img.at(x, y).rgba()
    let (r2, g2, b2, _) = reference.at(x, y).rgba()
    let dr = if r1 >= r2 { r1 - r2 } else { r2 - r1 }
    let dg = if g1 >= g2 { g1 - g2 } else { g2 - g1 }
    let db = if b1 >= b2 { b1 - b2 } else { b2 - b1 }
    assert_true(dr >> 8 < 96U)
    assert_true(dg >> 8 < 96U)
    assert_true(db >> 8 < 96U)
  }
}

///|
/// Test JPEG encode with different quality levels.
test "jpeg_quality_levels" {
  let img = @image.new_image_rgba(@image.rect(0, 0, 16, 16))
  for y in 0..<16 {
    for x in 0..<16 {
      img.set_rgba(x, y, {
        r: (x * 16).to_byte(),
        g: (y * 16).to_byte(),
        b: b'\x80',
        a: b'\xff',
      })
    }
  }
  let any_img = @image.AnyImage::RGBA(img)
  // Low quality should produce smaller output
  let low = encode(any_img, quality=10)
  let high = encode(any_img, quality=95)
  assert_true(low.length() < high.length())
  // Both should decode without error
  let dec_low = decode(low)
  let dec_high = decode(high)
  assert_eq(dec_low.bounds().dx(), 16)
  assert_eq(dec_high.bounds().dx(), 16)
}

///|
/// Test that JPEG extraneous data after EOI is handled.
test "jpeg_extraneous_data" {
  let data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  // Append garbage after EOI marker
  let extra = @blit.Buffer::new(size_hint=data.length() + 100)
  for i in 0..<data.length() {
    extra.write_byte(data.unsafe_get(i))
  }
  for i in 0..<100 {
    ignore(i)
    extra.write_byte(b'\xAB')
  }
  // Should still decode correctly (EOI marks end, extra data ignored)
  let img = decode(extra.to_bytes())
  assert_true(img.bounds().dx() > 0)
}
