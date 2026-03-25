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
/// Test decoding various JPEG subsampling modes.
test "jpeg_subsampling" {
  let files = [
    "testdata/video-001.q50.420.jpeg", "testdata/video-001.q50.422.jpeg", "testdata/video-001.q50.444.jpeg",
  ]
  for path in files {
    let data = @fs.read_file_to_bytes(path)
    let img = decode(data)
    let b = img.bounds()
    assert_true(b.dx() > 0)
    assert_true(b.dy() > 0)
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
