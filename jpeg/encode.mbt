///|
// Standard JPEG luminance (Y) quantization table (quality 50)
let luma_quant : FixedArray[Int] = [
  16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, 14, 13, 16, 24,
  40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62, 18, 22, 37, 56, 68, 109, 103, 77,
  24, 35, 55, 64, 81, 104, 113, 92, 49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95,
  98, 112, 100, 103, 99,
]

///|
// Standard JPEG chrominance (Cb/Cr) quantization table (quality 50)
let chroma_quant : FixedArray[Int] = [
  17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, 24, 26, 56, 99,
  99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99,
]

///|
// Standard JPEG luminance DC Huffman table
// (counts, symbols)
let luma_dc_counts : FixedArray[Int] = [
  0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
]

///|
let luma_dc_symbols : FixedArray[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
]

///|
// Standard JPEG luminance AC Huffman table
let luma_ac_counts : FixedArray[Int] = [
  0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125,
]

///|
let luma_ac_symbols : FixedArray[Int] = [
  1, 2, 3, 0, 4, 17, 5, 18, 33, 49, 65, 6, 19, 34, 50, 80, 20, 66, 114, 16, 32, 48,
  64, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 145, 146, 147, 148, 149,
  150, 151, 152, 153, 154, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 177,
  178, 179, 180, 181, 182, 183, 184, 185, 186, 193, 194, 195, 196, 197, 198, 199,
  200, 201, 202, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 225, 226, 227,
  228, 229, 230, 231, 232, 233, 234, 241, 242, 243, 244, 245, 246, 247, 248, 249,
  250,
]

///|
// Standard JPEG chrominance DC Huffman table
let chroma_dc_counts : FixedArray[Int] = [
  0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
]

///|
let chroma_dc_symbols : FixedArray[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
]

///|
// Standard JPEG chrominance AC Huffman table
let chroma_ac_counts : FixedArray[Int] = [
  0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119,
]

///|
let chroma_ac_symbols : FixedArray[Int] = [
  0, 1, 2, 3, 17, 4, 5, 33, 49, 6, 18, 65, 81, 7, 97, 113, 19, 34, 50, 129, 8, 20,
  66, 130, 145, 161, 177, 193, 9, 35, 51, 82, 240, 21, 98, 114, 209, 10, 22, 36, 52,
  225, 37, 241, 23, 24, 25, 26, 38, 39, 40, 41, 42, 53, 54, 55, 56, 57, 58, 67, 68,
  69, 70, 71, 72, 73, 74, 83, 84, 85, 86, 87, 88, 89, 90, 99, 100, 101, 102, 103,
  104, 105, 106, 115, 116, 117, 118, 119, 120, 121, 122, 131, 132, 133, 134, 135,
  136, 137, 138, 146, 147, 148, 149, 150, 151, 152, 153, 154, 162, 163, 164, 165,
  166, 167, 168, 169, 170, 178, 179, 180, 181, 182, 183, 184, 185, 186, 194, 195,
  196, 197, 198, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216, 217, 218,
  226, 227, 228, 229, 230, 231, 232, 233, 234, 242, 243, 244, 245, 246, 247, 248,
  249, 250,
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
  symbols : FixedArray[Int]
) -> (FixedArray[Int], FixedArray[Int]) {
  let codes = FixedArray::make(256, 0)
  let lengths = FixedArray::make(256, 0)
  let mut code = 0
  let mut sym_idx = 0
  for i in 0..<16 {
    let n = counts[i]
    let length = i + 1
    for _ in 0..<n {
      if sym_idx < symbols.length() {
        let sym = symbols[sym_idx]
        codes[sym] = code
        lengths[sym] = length
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
  sym : Int
) -> Unit {
  enc_write_bits(e, codes[sym], lengths[sym])
}

///|
/// Encode a DC coefficient difference using the given Huffman table.
fn enc_dc_coeff(
  e : Encoder,
  dc_codes : FixedArray[Int],
  dc_lengths : FixedArray[Int],
  diff : Int
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
  coeff : Int
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
  // Size = number of bits needed to represent abs_v
  let mut size = 0
  let mut tmp = abs_v
  while tmp > 0 {
    size += 1
    tmp = tmp >> 1
  }
  // Value: if positive, use abs_v; if negative, use abs_v - 2^size
  let value = if v > 0 { v } else { v + (1 << size) - 1 }
  (size, value)
}

///|
/// Encode a single 8x8 block.
/// block[] is in natural (row-major) order.
/// Returns the new DC predictor.
fn encode_block(
  e : Encoder,
  block : FixedArray[Int],
  quant : FixedArray[Int],
  dc_pred : Int,
  dc_codes : FixedArray[Int],
  dc_lengths : FixedArray[Int],
  ac_codes : FixedArray[Int],
  ac_lengths : FixedArray[Int]
) -> Int {
  // Quantize in zig-zag order
  let zig = FixedArray::make(64, 0)
  for k in 0..<64 {
    let qval = quant[k]
    let coeff = block[unzig[k]]
    // Round to nearest integer after dividing by quantization step
    let rounded = if coeff >= 0 {
      (coeff + qval / 2) / qval
    } else {
      -((-coeff + qval / 2) / qval)
    }
    zig[k] = rounded
  }
  // DC coefficient
  let dc_diff = zig[0] - dc_pred
  enc_dc_coeff(e, dc_codes, dc_lengths, dc_diff)
  // AC coefficients
  let mut run = 0
  for k = 1; k < 64; k = k + 1 {
    let coeff = zig[k]
    if coeff == 0 {
      run += 1
      if run == 16 {
        // ZRL
        enc_emit_symbol(e, ac_codes, ac_lengths, 0xF0)
        run = 0
      }
    } else {
      // Emit ZRL for full runs of 16
      while run >= 16 {
        enc_emit_symbol(e, ac_codes, ac_lengths, 0xF0)
        run -= 16
      }
      enc_ac_coeff(e, ac_codes, ac_lengths, run, coeff)
      run = 0
    }
  }
  // EOB if needed
  if run > 0 {
    enc_emit_symbol(e, ac_codes, ac_lengths, 0x00) // EOB
  }
  zig[0]
}

///|
/// Extract an 8x8 pixel block from a component plane.
fn extract_block(
  plane : FixedArray[Byte],
  plane_w : Int,
  plane_h : Int,
  bx : Int,
  by : Int,
  dst : FixedArray[Byte]
) -> Unit {
  for py in 0..<8 {
    for px in 0..<8 {
      let sx = bx * 8 + px
      let sy = by * 8 + py
      // Clamp to plane dimensions (edge replication)
      let csx = if sx >= plane_w { plane_w - 1 } else { sx }
      let csy = if sy >= plane_h { plane_h - 1 } else { sy }
      dst[py * 8 + px] = plane[csy * plane_w + csx]
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
  symbols : FixedArray[Int]
) -> Unit {
  let num_symbols = symbols.length()
  // Length = 2 (length field) + 1 (tc/th) + 16 (counts) + num_symbols
  let seg_len = (1 + 16 + num_symbols + 2).reinterpret_as_uint()
  enc_write_marker(e, marker_dht)
  enc_write_u16(e, seg_len)
  enc_write_raw(e, (((tc << 4) | th) & 0xFF).to_byte())
  for i in 0..<16 {
    enc_write_raw(e, counts[i].to_byte())
  }
  for i in 0..<num_symbols {
    enc_write_raw(e, symbols[i].to_byte())
  }
}

///|
/// Write a DQT (Define Quantization Table) segment.
fn write_dqt(e : Encoder, tq : Int, quant : FixedArray[Int]) -> Unit {
  // Length = 2 + 1 + 64 = 67
  enc_write_marker(e, marker_dqt)
  enc_write_u16(e, 67U)
  enc_write_raw(e, tq.to_byte())
  // Write in zig-zag order
  for k in 0..<64 {
    enc_write_raw(e, quant[k].to_byte())
  }
}

///|
/// Encode an image as a baseline JPEG.
pub fn encode(img : @image.AnyImage) -> Bytes raise JpegError {
  let e = Encoder::new()
  let bounds = img.bounds()
  let width = bounds.dx()
  let height = bounds.dy()
  // Build code tables
  let (luma_dc_codes, luma_dc_lengths) = build_enc_huffman_table(
    luma_dc_counts,
    luma_dc_symbols,
  )
  let (luma_ac_codes, luma_ac_lengths) = build_enc_huffman_table(
    luma_ac_counts,
    luma_ac_symbols,
  )
  let (chroma_dc_codes, chroma_dc_lengths) = build_enc_huffman_table(
    chroma_dc_counts,
    chroma_dc_symbols,
  )
  let (chroma_ac_codes, chroma_ac_lengths) = build_enc_huffman_table(
    chroma_ac_counts,
    chroma_ac_symbols,
  )
  // Determine if grayscale
  let is_gray = match img {
    @image.AnyImage::Gray(_) | @image.AnyImage::Gray16(_) => true
    _ => false
  }
  let num_components = if is_gray { 1 } else { 3 }
  // Convert image to component planes
  let y_plane = FixedArray::make(width * height, b'\x00')
  let cb_plane = FixedArray::make(width * height, b'\x80') // default 128
  let cr_plane = FixedArray::make(width * height, b'\x80')
  for py in 0..<height {
    for px in 0..<width {
      let ax = bounds.min.x + px
      let ay = bounds.min.y + py
      let idx = py * width + px
      match img {
        @image.AnyImage::Gray(g) => {
          y_plane[idx] = g.gray_at(ax, ay).y
        }
        @image.AnyImage::Gray16(g) => {
          y_plane[idx] = (g.gray16_at(ax, ay).y >> 8).to_byte()
        }
        _ => {
          let c = img.at(ax, ay)
          let (rv, gv, bv, av) = c.rgba()
          // Convert premultiplied to 8-bit
          let (r8, g8, b8) = if av == 0U {
            (b'\x00', b'\x00', b'\x00')
          } else {
            let r8 = (rv * 255U / av).to_byte()
            let g8 = (gv * 255U / av).to_byte()
            let b8 = (bv * 255U / av).to_byte()
            (r8, g8, b8)
          }
          let (yv, cbv, crv) = @color.rgb_to_ycbcr(r8, g8, b8)
          y_plane[idx] = yv
          cb_plane[idx] = cbv
          cr_plane[idx] = crv
        }
      }
    }
  }
  // SOI
  enc_write_marker(e, marker_soi)
  // APP0 (JFIF)
  enc_write_marker(e, marker_app0)
  enc_write_u16(e, 16U) // length
  // "JFIF\0"
  enc_write_raw(e, b'\x4a') // J
  enc_write_raw(e, b'\x46') // F
  enc_write_raw(e, b'\x49') // I
  enc_write_raw(e, b'\x46') // F
  enc_write_raw(e, b'\x00') // null
  enc_write_raw(e, b'\x01') // version major
  enc_write_raw(e, b'\x01') // version minor
  enc_write_raw(e, b'\x00') // pixel aspect ratio units: 0=no units
  enc_write_u16(e, 1U) // X density
  enc_write_u16(e, 1U) // Y density
  enc_write_raw(e, b'\x00') // thumbnail width
  enc_write_raw(e, b'\x00') // thumbnail height
  // DQT segments
  write_dqt(e, 0, luma_quant)
  if !is_gray {
    write_dqt(e, 1, chroma_quant)
  }
  // SOF0
  enc_write_marker(e, marker_sof0)
  let sof_len = if is_gray { 11U } else { 17U }
  enc_write_u16(e, sof_len)
  enc_write_raw(e, b'\x08') // 8-bit precision
  enc_write_u16(e, height.reinterpret_as_uint())
  enc_write_u16(e, width.reinterpret_as_uint())
  enc_write_raw(e, num_components.to_byte())
  if is_gray {
    enc_write_raw(e, b'\x01') // component ID 1
    enc_write_raw(e, b'\x11') // H=1, V=1
    enc_write_raw(e, b'\x00') // quant table 0
  } else {
    // Y component: 1x1 sampling
    enc_write_raw(e, b'\x01')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x00')
    // Cb component
    enc_write_raw(e, b'\x02')
    enc_write_raw(e, b'\x11')
    enc_write_raw(e, b'\x01')
    // Cr component
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
    enc_write_raw(e, b'\x01') // component 1
    enc_write_raw(e, b'\x00') // DC table 0, AC table 0
  } else {
    enc_write_raw(e, b'\x01') // Y
    enc_write_raw(e, b'\x00') // DC 0, AC 0
    enc_write_raw(e, b'\x02') // Cb
    enc_write_raw(e, b'\x11') // DC 1, AC 1
    enc_write_raw(e, b'\x03') // Cr
    enc_write_raw(e, b'\x11') // DC 1, AC 1
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
  for by in 0..<block_h {
    for bx in 0..<block_w {
      // Y
      extract_block(y_plane, width, height, bx, by, pixels)
      fdct(pixels, block)
      y_dc_pred = encode_block(
        e,
        block,
        luma_quant,
        y_dc_pred,
        luma_dc_codes,
        luma_dc_lengths,
        luma_ac_codes,
        luma_ac_lengths,
      )
      if !is_gray {
        // Cb
        extract_block(cb_plane, width, height, bx, by, pixels)
        fdct(pixels, block)
        cb_dc_pred = encode_block(
          e,
          block,
          chroma_quant,
          cb_dc_pred,
          chroma_dc_codes,
          chroma_dc_lengths,
          chroma_ac_codes,
          chroma_ac_lengths,
        )
        // Cr
        extract_block(cr_plane, width, height, bx, by, pixels)
        fdct(pixels, block)
        cr_dc_pred = encode_block(
          e,
          block,
          chroma_quant,
          cr_dc_pred,
          chroma_dc_codes,
          chroma_dc_lengths,
          chroma_ac_codes,
          chroma_ac_lengths,
        )
      }
    }
  }
  enc_flush_bits(e)
  // EOI
  enc_write_marker(e, marker_eoi)
  e.buf.to_bytes()
}
