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
  // Check SOI marker
  let m = read_marker(d)
  if m != marker_soi {
    raise JpegError::FormatError("missing SOI marker")
  }
  // Scan for SOF marker
  let mut found = false
  let mut w = 0
  let mut h = 0
  let mut nc = 0
  while !found {
    let marker = read_marker(d)
    if marker == marker_eoi {
      raise JpegError::FormatError("no SOF marker found")
    }
    let length = d.r.read_uint16_be()
    let seg_len = length.reinterpret_as_int() - 2
    if marker == marker_sof0 || marker == marker_sof1 {
      if seg_len < 6 {
        raise JpegError::FormatError("bad SOF segment")
      }
      let _prec = d.r.read_byte()
      h = d.r.read_uint16_be().reinterpret_as_int()
      w = d.r.read_uint16_be().reinterpret_as_int()
      nc = d.r.read_byte().to_int()
      found = true
    } else {
      d.r.skip(seg_len)
    }
  }
  let cm : @color.AnyModel = if nc == 1 {
    @color.AnyModel::GrayModel
  } else {
    @color.AnyModel::YCbCrModel
  }
  { color_model: cm, width: w, height: h }
}

///|
/// Read a 2-byte JPEG marker (0xFF followed by marker byte).
fn read_marker(d : Decoder) -> UInt raise JpegError {
  // Scan for 0xFF
  let mut b = d.r.read_byte()
  while b != b'\xFF' {
    b = d.r.read_byte()
  }
  // Skip any padding 0xFF bytes
  while b == b'\xFF' {
    b = d.r.read_byte()
  }
  0xFF00U | b.to_uint()
}

///|
/// Main JPEG decode function.
fn decode_jpeg(d : Decoder) -> @image.AnyImage raise JpegError {
  // Check SOI
  let soi = read_marker(d)
  if soi != marker_soi {
    raise JpegError::FormatError("missing SOI marker")
  }
  let mut done = false
  let mut img : @image.AnyImage = @image.AnyImage::Gray(
    @image.new_image_gray({ min_x: 0, min_y: 0, max_x: 0, max_y: 0 }),
  )
  while !done && d.r.remaining() > 0 {
    let marker = read_marker(d)
    if marker == marker_eoi {
      done = true
    } else if marker == marker_sof0 || marker == marker_sof0 + 1U {
      process_sof(d)
    } else if marker == marker_sof2 {
      d.progressive = true
      process_sof(d)
    } else if marker == marker_dht {
      process_dht(d)
    } else if marker == marker_dqt {
      process_dqt(d)
    } else if marker == marker_dri {
      process_dri(d)
    } else if marker == marker_sos {
      if d.progressive {
        process_sos_progressive(d)
      } else {
        img = process_sos(d)
        done = true
      }
    } else if marker >= marker_app0 && marker <= marker_app15 {
      let length = d.r.read_uint16_be()
      d.r.skip(length.reinterpret_as_int() - 2)
    } else if marker == marker_com {
      let length = d.r.read_uint16_be()
      d.r.skip(length.reinterpret_as_int() - 2)
    } else {
      let length = d.r.read_uint16_be()
      let skip_len = length.reinterpret_as_int() - 2
      if skip_len >= 0 {
        d.r.skip(skip_len)
      }
    }
  }
  if d.progressive {
    img = reconstruct_progressive(d)
  }
  img
}

///|
/// Process a SOF0 segment (Start of Frame, Baseline DCT).
fn process_sof(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let seg_len = length.reinterpret_as_int() - 2
  if seg_len < 6 {
    raise JpegError::FormatError("bad SOF segment length")
  }
  let precision = d.r.read_byte()
  if precision != b'\x08' {
    raise JpegError::UnsupportedError("only 8-bit precision supported")
  }
  d.height = d.r.read_uint16_be().reinterpret_as_int()
  d.width = d.r.read_uint16_be().reinterpret_as_int()
  d.num_components = d.r.read_byte().to_int()
  if d.num_components != 1 && d.num_components != 3 {
    raise JpegError::UnsupportedError(
      "only 1 or 3 component JPEG supported, got " +
      d.num_components.to_string(),
    )
  }
  let expected_len = 3 * d.num_components
  if seg_len < 6 + expected_len - 3 {
    // The 6 bytes above (prec+h+w+nc) = 6, then 3 per component
    ignore(expected_len)
  }
  for i in 0..<d.num_components {
    let comp_id = d.r.read_byte().to_int()
    let sampling = d.r.read_byte().to_int()
    let qt_idx = d.r.read_byte().to_int()
    d.comp.unsafe_get(i).id = comp_id
    d.comp.unsafe_get(i).h = (sampling >> 4) & 0x0F
    d.comp.unsafe_get(i).v = sampling & 0x0F
    d.comp.unsafe_get(i).qt = qt_idx
    if qt_idx >= 4 {
      raise JpegError::FormatError("quantization table index out of range")
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
    let tc = (tc_th >> 4) & 0x0F // table class: 0=DC, 1=AC
    let th = tc_th & 0x0F // table index
    if tc > 1 || th > 3 {
      raise JpegError::FormatError("bad Huffman table class or index")
    }
    // Read 16 bytes: number of codes of each length
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
    let pq = (pq_tq >> 4) & 0x0F // precision: 0=8bit, 1=16bit
    let tq = pq_tq & 0x0F // table index
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
