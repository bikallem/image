///|
/// Decodes a JPEG image from raw bytes.
pub fn decode(data : Bytes) -> @image.AnyImage raise Error {
  let d = Decoder::new(data)
  decode_jpeg(d)
}

///|
/// Decodes just the configuration (color model and dimensions) of a JPEG.
pub fn decode_config(data : Bytes) -> @image.Config raise Error {
  let d = Decoder::new(data)
  let m = read_marker(d)
  if m != marker_soi {
    raise JpegError::FormatError("missing SOI marker")
  }
  let mut seen_sof = false
  let mut done = false
  while !done && d.r.remaining() > 0 {
    let marker = read_marker(d)
    match marker {
      m if m == marker_eoi => done = true
      m if m == marker_sof0 => {
        d.baseline = true
        d.progressive = false
        process_sof(d)
        seen_sof = true
      }
      m if m == marker_sof1 => {
        d.baseline = false
        d.progressive = false
        process_sof(d)
        seen_sof = true
      }
      m if m == marker_sof2 => {
        d.baseline = false
        d.progressive = true
        process_sof(d)
        seen_sof = true
      }
      m if m == marker_sos => {
        let length = d.r.read_uint16_be()
        let seg_len = length.reinterpret_as_int() - 2
        if seg_len < 0 {
          raise JpegError::FormatError("short segment length")
        }
        d.r.skip(seg_len)
        done = true
      }
      m if m == marker_dht || m == marker_dqt || m == marker_dri =>
        skip_segment(d)
      m if m == marker_app0 => process_app0_marker(d)
      m if m == marker_app14 => process_app14_marker(d)
      m if (m >= marker_app0 && m <= marker_app15) || m == marker_com =>
        skip_segment(d)
      m if is_restart_marker(m) => ()
      _ => reject_unknown_marker(marker)
    }
  }
  if !seen_sof {
    raise JpegError::FormatError("missing SOF marker")
  }
  { color_model: jpeg_color_model(d), width: d.width, height: d.height }
}

///|
/// Read a 2-byte JPEG marker (0xFF followed by marker byte).
fn read_marker(d : Decoder) -> UInt raise JpegError {
  let mut b = d.r.read_byte()
  while true {
    while b != b'\xFF' {
      b = d.r.read_byte()
    }
    while b == b'\xFF' {
      b = d.r.read_byte()
    }
    if b != b'\x00' {
      return 0xFF00U | b.to_uint()
    }
    b = d.r.read_byte()
  }
  raise JpegError::UnexpectedEOF
}

///|
fn is_restart_marker(marker : UInt) -> Bool {
  marker >= marker_rst0 && marker <= marker_rst7
}

///|
fn reject_unknown_marker(marker : UInt) -> Unit raise JpegError {
  if marker < marker_sof0 {
    raise JpegError::FormatError("unknown marker")
  }
  raise JpegError::UnsupportedError("unknown marker")
}

///|
fn jpeg_color_model(d : Decoder) -> @color.AnyModel raise JpegError {
  match d.num_components {
    1 => @color.AnyModel::GrayModel
    3 =>
      if is_rgb_jpeg(d) {
        @color.AnyModel::RGBAModel
      } else {
        @color.AnyModel::YCbCrModel
      }
    4 => @color.AnyModel::CMYKModel
    _ => raise JpegError::FormatError("missing SOF marker")
  }
}

///|
fn skip_segment(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let seg_len = length.reinterpret_as_int() - 2
  if seg_len < 0 {
    raise JpegError::FormatError("short segment length")
  }
  d.r.skip(seg_len)
}

///|
fn process_app0_marker(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let mut remaining = length.reinterpret_as_int() - 2
  if remaining < 0 {
    raise JpegError::FormatError("short segment length")
  }
  if remaining < 5 {
    d.r.skip(remaining)
    return
  }
  let ident = d.r.read_bytes(5)
  remaining -= 5
  d.jfif = ident.unsafe_get(0) == b'J' &&
    ident.unsafe_get(1) == b'F' &&
    ident.unsafe_get(2) == b'I' &&
    ident.unsafe_get(3) == b'F' &&
    ident.unsafe_get(4) == b'\x00'
  if remaining > 0 {
    d.r.skip(remaining)
  }
}

///|
fn process_app14_marker(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let mut remaining = length.reinterpret_as_int() - 2
  if remaining < 0 {
    raise JpegError::FormatError("short segment length")
  }
  if remaining < 12 {
    d.r.skip(remaining)
    return
  }
  let block = d.r.read_bytes(12)
  remaining -= 12
  if block.unsafe_get(0) == b'A' &&
    block.unsafe_get(1) == b'd' &&
    block.unsafe_get(2) == b'o' &&
    block.unsafe_get(3) == b'b' &&
    block.unsafe_get(4) == b'e' {
    d.adobe_transform_valid = true
    d.adobe_transform = block.unsafe_get(11).to_int()
  }
  if remaining > 0 {
    d.r.skip(remaining)
  }
}

///|
/// Main JPEG decode function.
fn decode_jpeg(d : Decoder) -> @image.AnyImage raise JpegError {
  let soi = read_marker(d)
  if soi != marker_soi {
    raise JpegError::FormatError("missing SOI marker")
  }
  let mut done = false
  let mut saw_scan = false
  while !done && d.r.remaining() > 0 {
    let marker = read_marker(d)
    match marker {
      m if m == marker_eoi => done = true
      m if m == marker_sof0 => {
        d.baseline = true
        d.progressive = false
        process_sof(d)
      }
      m if m == marker_sof1 => {
        d.baseline = false
        d.progressive = false
        process_sof(d)
      }
      m if m == marker_sof2 => {
        d.baseline = false
        d.progressive = true
        process_sof(d)
      }
      m if m == marker_dht => process_dht(d)
      m if m == marker_dqt => process_dqt(d)
      m if m == marker_dri => process_dri(d)
      m if m == marker_sos => {
        process_sos(d)
        saw_scan = true
      }
      m if m == marker_app0 => process_app0_marker(d)
      m if m == marker_app14 => process_app14_marker(d)
      m if (m >= marker_app0 && m <= marker_app15) || m == marker_com =>
        skip_segment(d)
      m if is_restart_marker(m) => ()
      _ => reject_unknown_marker(marker)
    }
  }
  if !saw_scan {
    raise JpegError::FormatError("missing SOS marker")
  }
  reconstruct_coefficients(d)
}

///|
/// Process a SOF segment (Start of Frame).
fn process_sof(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let seg_len = length.reinterpret_as_int() - 2
  if d.num_components != 0 {
    raise JpegError::FormatError("multiple SOF markers")
  }
  if seg_len < 9 {
    raise JpegError::FormatError("bad SOF segment length")
  }
  let precision = d.r.read_byte()
  if precision != b'\x08' {
    raise JpegError::UnsupportedError("only 8-bit precision supported")
  }
  d.height = d.r.read_uint16_be().reinterpret_as_int()
  d.width = d.r.read_uint16_be().reinterpret_as_int()
  d.num_components = d.r.read_byte().to_int()
  if d.num_components != 1 && d.num_components != 3 && d.num_components != 4 {
    raise JpegError::UnsupportedError(
      "only 1, 3 or 4 component JPEG supported, got " +
      d.num_components.to_string(),
    )
  }
  if seg_len != 6 + 3 * d.num_components {
    raise JpegError::FormatError("bad SOF segment length")
  }
  for i in 0..<d.num_components {
    let comp_id = d.r.read_byte().to_int()
    let sampling = d.r.read_byte().to_int()
    let qt_idx = d.r.read_byte().to_int()
    let mut h = (sampling >> 4) & 0x0F
    let mut v = sampling & 0x0F
    d.comp.unsafe_get(i).id = comp_id
    d.comp.unsafe_get(i).qt = qt_idx
    if h < 1 || h > 4 || v < 1 || v > 4 {
      raise JpegError::FormatError("bad sampling factor")
    }
    if h == 3 || v == 3 {
      raise JpegError::UnsupportedError("unsupported subsampling ratio")
    }
    match d.num_components {
      1 => {
        h = 1
        v = 1
      }
      4 =>
        match i {
          0 =>
            if !((h == 1 && v == 1) || (h == 2 && v == 2)) {
              raise JpegError::UnsupportedError("unsupported subsampling ratio")
            }
          1 | 2 =>
            if h != 1 || v != 1 {
              raise JpegError::UnsupportedError("unsupported subsampling ratio")
            }
          3 =>
            if d.comp.unsafe_get(0).h != h || d.comp.unsafe_get(0).v != v {
              raise JpegError::UnsupportedError("unsupported subsampling ratio")
            }
          _ => ()
        }
      _ => ()
    }
    d.comp.unsafe_get(i).h = h
    d.comp.unsafe_get(i).v = v
    if qt_idx >= 4 {
      raise JpegError::FormatError("quantization table index out of range")
    }
    for j in 0..<i {
      if d.comp.unsafe_get(j).id == comp_id {
        raise JpegError::FormatError("repeated component identifier")
      }
    }
  }
  if d.num_components == 3 {
    let mut max_h = 1
    let mut max_v = 1
    for i in 0..<3 {
      if d.comp.unsafe_get(i).h > max_h {
        max_h = d.comp.unsafe_get(i).h
      }
      if d.comp.unsafe_get(i).v > max_v {
        max_v = d.comp.unsafe_get(i).v
      }
    }
    for i in 0..<3 {
      if max_h % d.comp.unsafe_get(i).h != 0 ||
        max_v % d.comp.unsafe_get(i).v != 0 {
        raise JpegError::UnsupportedError("unsupported subsampling ratio")
      }
    }
  }
}

///|
/// Process a DHT segment (Define Huffman Table).
fn process_dht(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let mut remaining = length.reinterpret_as_int() - 2
  while remaining > 0 {
    if remaining < 17 {
      raise JpegError::FormatError("bad DHT segment")
    }
    let tc_th = d.r.read_byte().to_int()
    remaining -= 1
    let tc = (tc_th >> 4) & 0x0F
    let th = tc_th & 0x0F
    if tc > 1 || th > 3 {
      raise JpegError::FormatError("bad Huffman table class or index")
    }
    let bits_count = FixedArray::make(16, 0)
    let mut total_symbols = 0
    for i in 0..<16 {
      let n = d.r.read_byte().to_int()
      bits_count.unsafe_set(i, n)
      total_symbols += n
    }
    remaining -= 16
    if remaining < total_symbols {
      raise JpegError::FormatError("bad DHT segment: not enough symbols")
    }
    let symbols = FixedArray::make(total_symbols, 0)
    for i in 0..<total_symbols {
      symbols.unsafe_set(i, d.r.read_byte().to_int())
    }
    remaining -= total_symbols
    build_huffman_table(d.huff.unsafe_get(tc)[th], bits_count, symbols)
  }
}

///|
/// Process a DQT segment (Define Quantization Table).
fn process_dqt(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let mut remaining = length.reinterpret_as_int() - 2
  while remaining > 0 {
    if remaining < 1 {
      raise JpegError::FormatError("bad DQT segment")
    }
    let pq_tq = d.r.read_byte().to_int()
    remaining -= 1
    let pq = (pq_tq >> 4) & 0x0F
    let tq = pq_tq & 0x0F
    if tq >= 4 {
      raise JpegError::FormatError("quantization table index out of range")
    }
    if pq == 0 {
      if remaining < 64 {
        raise JpegError::FormatError("bad DQT segment: not enough data")
      }
      for i in 0..<64 {
        d.quant.unsafe_get(tq).data.unsafe_set(i, d.r.read_byte().to_int())
      }
      remaining -= 64
    } else if pq == 1 {
      if remaining < 128 {
        raise JpegError::FormatError("bad DQT segment: not enough data")
      }
      for i in 0..<64 {
        let hi = d.r.read_byte().to_int()
        let lo = d.r.read_byte().to_int()
        d.quant.unsafe_get(tq).data.unsafe_set(i, (hi << 8) | lo)
      }
      remaining -= 128
    } else {
      raise JpegError::FormatError("bad DQT precision")
    }
  }
}

///|
/// Process a DRI segment (Define Restart Interval).
fn process_dri(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  if length != 4U {
    raise JpegError::FormatError("bad DRI segment length")
  }
  d.restart_interval = d.r.read_uint16_be().reinterpret_as_int()
}
