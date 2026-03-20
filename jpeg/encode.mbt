///|
// Unscaled quantization tables in zig-zag order (from JPEG spec section K.1).
// Scaled by quality at encode time.
let unscaled_quant_luma : FixedArray[Int] = [
  16, 11, 12, 14, 12, 10, 16, 14, 13, 14, 18, 17, 16, 19, 24, 40, 26, 24, 22, 22,
  24, 49, 35, 37, 29, 40, 58, 51, 61, 60, 57, 51, 56, 55, 64, 72, 92, 78, 64, 68,
  87, 69, 55, 56, 80, 109, 81, 87, 95, 98, 103, 104, 103, 62, 77, 113, 121, 112,
  100, 120, 92, 101, 103, 99,
]

///|
let unscaled_quant_chroma : FixedArray[Int] = [
  17, 18, 18, 24, 21, 24, 47, 26, 26, 47, 99, 66, 56, 66, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99,
]

///|
// Standard JPEG luminance DC Huffman table
let luma_dc_counts : FixedArray[Int] = [
  0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
]

///|
let luma_dc_symbols : FixedArray[Int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

///|
// Standard JPEG luminance AC Huffman table (162 symbols)
let luma_ac_counts : FixedArray[Int] = [
  0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125,
]

///|
let luma_ac_symbols : FixedArray[Int] = [
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51,
  0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1,
  0x15, 0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18,
  0x19, 0x1a, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57,
  0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75,
  0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92,
  0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
  0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
  0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8,
  0xd9, 0xda, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2,
  0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa,
]

///|
// Standard JPEG chrominance DC Huffman table
let chroma_dc_counts : FixedArray[Int] = [
  0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
]

///|
let chroma_dc_symbols : FixedArray[Int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

///|
// Standard JPEG chrominance AC Huffman table (162 symbols)
let chroma_ac_counts : FixedArray[Int] = [
  0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119,
]

///|
let chroma_ac_symbols : FixedArray[Int] = [
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07,
  0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09,
  0x23, 0x33, 0x52, 0xf0, 0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25,
  0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38,
  0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56,
  0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74,
  0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
  0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
  0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba,
  0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6,
  0xd7, 0xd8, 0xd9, 0xda, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2,
  0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa,
]

///|
/// Encoder state for bit-level output.
priv struct Encoder {
  buf : @buffer.Buffer
  mut bit_buf : Int
  mut bit_count : Int
}

///|
fn Encoder::new() -> Encoder {
  { buf: @buffer.new(), bit_buf: 0, bit_count: 0 }
}

///|
/// Write a byte to the output buffer, with 0xFF byte-stuffing.
fn enc_write_byte(e : Encoder, b : Byte) -> Unit {
  e.buf.write_byte(b)
  if b == b'\xFF' {
    e.buf.write_byte(b'\x00')
  }
}

///|
/// Write n bits (value v) to the entropy-coded output.
fn enc_write_bits(e : Encoder, v : Int, n : Int) -> Unit {
  e.bit_buf = (e.bit_buf << n) | v
  e.bit_count = e.bit_count + n
  while e.bit_count >= 8 {
    e.bit_count = e.bit_count - 8
    let byte_val = ((e.bit_buf >> e.bit_count) & 0xFF).to_byte()
    enc_write_byte(e, byte_val)
  }
}

///|
/// Flush any remaining bits in the bit buffer (padding with 1s as per JPEG spec).
fn enc_flush_bits(e : Encoder) -> Unit {
  if e.bit_count > 0 {
    let remaining = 8 - e.bit_count
    let byte_val = (((e.bit_buf << remaining) | ((1 << remaining) - 1)) & 0xFF).to_byte()
    enc_write_byte(e, byte_val)
    e.bit_buf = 0
    e.bit_count = 0
  }
}

///|
/// Write a raw byte to the output (not entropy-coded; for markers).
fn enc_write_raw(e : Encoder, b : Byte) -> Unit {
  e.buf.write_byte(b)
}

///|
/// Write a 2-byte big-endian uint16.
fn enc_write_u16(e : Encoder, v : UInt) -> Unit {
  e.buf.write_byte((v >> 8).to_byte())
  e.buf.write_byte(v.to_byte())
}

///|
/// Write a JPEG marker (2 bytes).
fn enc_write_marker(e : Encoder, marker : UInt) -> Unit {
  enc_write_raw(e, (marker >> 8).to_byte())
  enc_write_raw(e, marker.to_byte())
}

///|
/// Build Huffman code tables from counts and symbols arrays.
/// Returns (codes, lengths) arrays indexed by symbol value (0..255).
fn build_enc_huffman_table(
  counts : FixedArray[Int],
  symbols : FixedArray[Int],
) -> (FixedArray[Int], FixedArray[Int]) {
  let codes = FixedArray::make(256, 0)
  let lengths = FixedArray::make(256, 0)
  let mut code = 0
  let mut sym_idx = 0
  for i in 0..<16 {
    let n = counts.unsafe_get(i)
    let length = i + 1
    for _ in 0..<n {
      if sym_idx < symbols.length() {
        let sym = symbols.unsafe_get(sym_idx)
        codes.unsafe_set(sym, code)
        lengths.unsafe_set(sym, length)
        sym_idx += 1
        code += 1
      }
    }
    code = code << 1
  }
  (codes, lengths)
}

///|
/// Emit a Huffman-coded symbol.
fn enc_emit_symbol(
  e : Encoder,
  codes : FixedArray[Int],
  lengths : FixedArray[Int],
  sym : Int,
) -> Unit {
  enc_write_bits(e, codes.unsafe_get(sym), lengths.unsafe_get(sym))
}

///|
/// Encode a DC coefficient difference using the given Huffman table.
fn enc_dc_coeff(
  e : Encoder,
  dc_codes : FixedArray[Int],
  dc_lengths : FixedArray[Int],
  diff : Int,
) -> Unit {
  let (size, value) = coeff_to_size_value(diff)
  enc_emit_symbol(e, dc_codes, dc_lengths, size)
  if size > 0 {
    enc_write_bits(e, value, size)
  }
}

///|
/// Encode an AC coefficient using the given Huffman table.
fn enc_ac_coeff(
  e : Encoder,
  ac_codes : FixedArray[Int],
  ac_lengths : FixedArray[Int],
  run : Int,
  coeff : Int,
) -> Unit {
  let (size, value) = coeff_to_size_value(coeff)
  let rs = (run << 4) | size
  enc_emit_symbol(e, ac_codes, ac_lengths, rs)
  if size > 0 {
    enc_write_bits(e, value, size)
  }
}

///|
/// Convert a coefficient value to (size, value) for JPEG encoding.
/// size = number of bits needed; value = bit pattern.
fn coeff_to_size_value(v : Int) -> (Int, Int) {
  if v == 0 {
    return (0, 0)
  }
  let abs_v = if v < 0 { -v } else { v }
  let mut size = 0
  let mut tmp = abs_v
  while tmp > 0 {
    size += 1
    tmp = tmp >> 1
  }
  let value = if v > 0 { v } else { v + (1 << size) - 1 }
  (size, value)
}

///|
/// Divide a by b, rounding to nearest (not toward zero), matching Go's div().
fn jpeg_div(a : Int, b : Int) -> Int {
  if a >= 0 {
    (a + (b >> 1)) / b
  } else {
    -((-a + (b >> 1)) / b)
  }
}

///|
/// Encode a single 8x8 block.
/// block[] is in natural (row-major) order after FDCT.
/// quant[] is in zig-zag order.
/// Returns the new DC predictor.
fn encode_block(
  e : Encoder,
  block : FixedArray[Int],
  quant : FixedArray[Int],
  dc_pred : Int,
  dc_codes : FixedArray[Int],
  dc_lengths : FixedArray[Int],
  ac_codes : FixedArray[Int],
  ac_lengths : FixedArray[Int],
) -> Int {
  // DC coefficient: quantize with 8x scale factor (matching Go)
  let dc = jpeg_div(block.unsafe_get(0), 8 * quant.unsafe_get(0))
  enc_dc_coeff(e, dc_codes, dc_lengths, dc - dc_pred)
  // AC coefficients in zig-zag order
  let mut run = 0
  for zig = 1; zig < 64; zig = zig + 1 {
    let ac = jpeg_div(
      block.unsafe_get(unzig.unsafe_get(zig)),
      8 * quant.unsafe_get(zig),
    )
    if ac == 0 {
      run += 1
    } else {
      while run > 15 {
        enc_emit_symbol(e, ac_codes, ac_lengths, 0xF0)
        run -= 16
      }
      enc_ac_coeff(e, ac_codes, ac_lengths, run, ac)
      run = 0
    }
  }
  if run > 0 {
    enc_emit_symbol(e, ac_codes, ac_lengths, 0x00) // EOB
  }
  dc
}

///|
/// Extract an 8x8 pixel block from a component plane.
fn extract_block(
  plane : FixedArray[Byte],
  plane_w : Int,
  plane_h : Int,
  bx : Int,
  by : Int,
  dst : FixedArray[Byte],
) -> Unit {
  for py in 0..<8 {
    for px in 0..<8 {
      let sx = bx * 8 + px
      let sy = by * 8 + py
      let csx = if sx >= plane_w { plane_w - 1 } else { sx }
      let csy = if sy >= plane_h { plane_h - 1 } else { sy }
      dst.unsafe_set(py * 8 + px, plane[csy * plane_w + csx])
    }
  }
}

///|
/// Write a DHT (Define Huffman Table) segment.
fn write_dht(
  e : Encoder,
  tc : Int,
  th : Int,
  counts : FixedArray[Int],
  symbols : FixedArray[Int],
) -> Unit {
  let num_symbols = symbols.length()
  let seg_len = (1 + 16 + num_symbols + 2).reinterpret_as_uint()
  enc_write_marker(e, marker_dht)
  enc_write_u16(e, seg_len)
  enc_write_raw(e, (((tc << 4) | th) & 0xFF).to_byte())
  for i in 0..<16 {
    enc_write_raw(e, counts.unsafe_get(i).to_byte())
  }
  for i in 0..<num_symbols {
    enc_write_raw(e, symbols.unsafe_get(i).to_byte())
  }
}

///|
/// Write a DQT (Define Quantization Table) segment.
/// quant[] is in zig-zag order.
fn write_dqt(e : Encoder, tq : Int, quant : FixedArray[Byte]) -> Unit {
  enc_write_marker(e, marker_dqt)
  enc_write_u16(e, 67U)
  enc_write_raw(e, tq.to_byte())
  for k in 0..<64 {
    enc_write_raw(e, quant.unsafe_get(k))
  }
}

///|
/// Scale quantization table by quality (1-100). Returns table in zig-zag order.
fn scale_quant(unscaled : FixedArray[Int], quality : Int) -> FixedArray[Byte] {
  let q = if quality < 1 { 1 } else if quality > 100 { 100 } else { quality }
  let scale = if q < 50 { 5000 / q } else { 200 - q * 2 }
  let result = FixedArray::make(64, b'\x00')
  for i in 0..<64 {
    let x = (unscaled.unsafe_get(i) * scale + 50) / 100
    let clamped = if x < 1 { 1 } else if x > 255 { 255 } else { x }
    result.unsafe_set(i, clamped.to_byte())
  }
  result
}

///|
/// Encode an image as a baseline JPEG.
/// quality: 1 (worst) to 100 (best), default 75.
pub fn encode(img : @image.AnyImage, quality? : Int = 75) -> Bytes {
  let e = Encoder::new()
  let bounds = img.bounds()
  let width = bounds.dx()
  let height = bounds.dy()
  // Scale quantization tables by quality
  let luma_q = scale_quant(unscaled_quant_luma, quality)
  let chroma_q = scale_quant(unscaled_quant_chroma, quality)
  // Build code tables
  let (luma_dc_codes, luma_dc_lens) = build_enc_huffman_table(
    luma_dc_counts, luma_dc_symbols,
  )
  let (luma_ac_codes, luma_ac_lens) = build_enc_huffman_table(
    luma_ac_counts, luma_ac_symbols,
  )
  let (chroma_dc_codes, chroma_dc_lens) = build_enc_huffman_table(
    chroma_dc_counts, chroma_dc_symbols,
  )
  let (chroma_ac_codes, chroma_ac_lens) = build_enc_huffman_table(
    chroma_ac_counts, chroma_ac_symbols,
  )
  // Determine if grayscale
  let is_gray = match img {
    @image.AnyImage::Gray(_) | @image.AnyImage::Gray16(_) => true
    _ => false
  }
  let num_components = if is_gray { 1 } else { 3 }
  // Convert image to component planes
  let y_plane = FixedArray::make(width * height, b'\x00')
  let cb_plane = FixedArray::make(width * height, b'\x80')
  let cr_plane = FixedArray::make(width * height, b'\x80')
  for py in 0..<height {
    for px in 0..<width {
      let ax = bounds.min_x + px
      let ay = bounds.min_y + py
      let idx = py * width + px
      match img {
        @image.AnyImage::Gray(g) => y_plane.unsafe_set(idx, g.gray_at(ax, ay).y)
        @image.AnyImage::Gray16(g) =>
          y_plane.unsafe_set(idx, (g.gray16_at(ax, ay).y >> 8).to_byte())
        _ => {
          let c = img.at(ax, ay)
          let (rv, gv, bv, av) = c.rgba()
          let (r8, g8, b8) = if av == 0U {
            (b'\x00', b'\x00', b'\x00')
          } else {
            (
              (rv * 255U / av).to_byte(),
              (gv * 255U / av).to_byte(),
              (bv * 255U / av).to_byte(),
            )
          }
          let (yv, cbv, crv) = @color.rgb_to_ycbcr(r8, g8, b8)
          y_plane.unsafe_set(idx, yv)
          cb_plane.unsafe_set(idx, cbv)
          cr_plane.unsafe_set(idx, crv)
        }
      }
    }
  }
  // SOI
  enc_write_marker(e, marker_soi)
  // APP0 (JFIF)
  enc_write_marker(e, marker_app0)
  enc_write_u16(e, 16U)
  enc_write_raw(e, b'\x4a') // J
  enc_write_raw(e, b'\x46') // F
  enc_write_raw(e, b'\x49') // I
  enc_write_raw(e, b'\x46') // F
  enc_write_raw(e, b'\x00')
  enc_write_raw(e, b'\x01')
  enc_write_raw(e, b'\x01')
  enc_write_raw(e, b'\x00')
  enc_write_u16(e, 1U)
  enc_write_u16(e, 1U)
  enc_write_raw(e, b'\x00')
  enc_write_raw(e, b'\x00')
  // DQT segments
  write_dqt(e, 0, luma_q)
  if !is_gray {
    write_dqt(e, 1, chroma_q)
  }
  // SOF0
  enc_write_marker(e, marker_sof0)
  let sof_len = if is_gray { 11U } else { 17U }
  enc_write_u16(e, sof_len)
  enc_write_raw(e, b'\x08')
  enc_write_u16(e, height.reinterpret_as_uint())
  enc_write_u16(e, width.reinterpret_as_uint())
  enc_write_raw(e, num_components.to_byte())
  if is_gray {
    enc_write_raw(e, b'\x01')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x00')
  } else {
    enc_write_raw(e, b'\x01')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x00')
    enc_write_raw(e, b'\x02')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x01')
    enc_write_raw(e, b'\x03')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x01')
  }
  // DHT segments
  write_dht(e, 0, 0, luma_dc_counts, luma_dc_symbols)
  write_dht(e, 1, 0, luma_ac_counts, luma_ac_symbols)
  if !is_gray {
    write_dht(e, 0, 1, chroma_dc_counts, chroma_dc_symbols)
    write_dht(e, 1, 1, chroma_ac_counts, chroma_ac_symbols)
  }
  // SOS
  enc_write_marker(e, marker_sos)
  let sos_len = if is_gray { 8U } else { 12U }
  enc_write_u16(e, sos_len)
  enc_write_raw(e, num_components.to_byte())
  if is_gray {
    enc_write_raw(e, b'\x01')
    enc_write_raw(e, b'\x00')
  } else {
    enc_write_raw(e, b'\x01')
    enc_write_raw(e, b'\x00')
    enc_write_raw(e, b'\x02')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x03')
    enc_write_raw(e, b'\x11')
  }
  enc_write_raw(e, b'\x00') // Ss
  enc_write_raw(e, b'\x3f') // Se
  enc_write_raw(e, b'\x00') // Ah=0, Al=0
  // Encode scan data
  let block_w = (width + 7) / 8
  let block_h = (height + 7) / 8
  let pixels = FixedArray::make(64, b'\x00')
  let block = FixedArray::make(64, 0)
  let mut y_dc_pred = 0
  let mut cb_dc_pred = 0
  let mut cr_dc_pred = 0
  // quant tables as Int arrays for encode_block
  let luma_qi = FixedArray::makei(64, fn(i) { luma_q[i].to_int() })
  let chroma_qi = FixedArray::makei(64, fn(i) { chroma_q[i].to_int() })
  for by in 0..<block_h {
    for bx in 0..<block_w {
      extract_block(y_plane, width, height, bx, by, pixels)
      fdct(pixels, block)
      y_dc_pred = encode_block(
        e, block, luma_qi, y_dc_pred, luma_dc_codes, luma_dc_lens, luma_ac_codes,
        luma_ac_lens,
      )
      if !is_gray {
        extract_block(cb_plane, width, height, bx, by, pixels)
        fdct(pixels, block)
        cb_dc_pred = encode_block(
          e, block, chroma_qi, cb_dc_pred, chroma_dc_codes, chroma_dc_lens, chroma_ac_codes,
          chroma_ac_lens,
        )
        extract_block(cr_plane, width, height, bx, by, pixels)
        fdct(pixels, block)
        cr_dc_pred = encode_block(
          e, block, chroma_qi, cr_dc_pred, chroma_dc_codes, chroma_dc_lens, chroma_ac_codes,
          chroma_ac_lens,
        )
      }
    }
  }
  enc_flush_bits(e)
  enc_write_marker(e, marker_eoi)
  e.buf.to_bytes()
}
