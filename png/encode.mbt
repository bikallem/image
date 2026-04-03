///|
/// PNG compression level.
pub(all) enum CompressionLevel {
  DefaultCompression
  NoCompression
  BestSpeed
  BestCompression
} derive(Eq, Debug)

///|
/// Encodes an image as PNG.
pub fn encode(
  img : &@image.Image,
  compression? : CompressionLevel = DefaultCompression,
) -> Bytes raise Error {
  encode_with_compressor(img, compression, zlib_compress_png_data)
}

///|
fn encode_with_compressor(
  img : &@image.Image,
  compression : CompressionLevel,
  compressor : (Bytes, CompressionLevel) -> Bytes raise PngError,
) -> Bytes raise Error {
  let bounds = img.bounds()
  let width = bounds.dx()
  let height = bounds.dy()
  validate_png_image_size(width.to_int64(), height.to_int64())
  let buf = @blit.Buffer::new()
  // Write PNG signature
  for i in 0..<8 {
    buf.write_byte(png_header.unsafe_get(i))
  }
  let all_opaque = png_is_opaque(img)
  // Determine color type: always use true color (with or without alpha), 8-bit
  let (color_type, bit_depth) : (Byte, Byte) = if all_opaque {
    (ct_true_color, b'\x08')
  } else {
    (ct_true_color_alpha, b'\x08')
  }
  // Write IHDR
  let ihdr = FixedArray::make(13, b'\x00')
  @binary.write_uint32_be(ihdr, 0, width.reinterpret_as_uint())
  @binary.write_uint32_be(ihdr, 4, height.reinterpret_as_uint())
  ihdr.unsafe_set(8, bit_depth)
  ihdr.unsafe_set(9, color_type)
  ihdr.unsafe_set(10, b'\x00') // compression
  ihdr.unsafe_set(11, b'\x00') // filter
  ihdr.unsafe_set(12, b'\x00') // interlace
  write_chunk(buf, ct_ihdr, ihdr)
  // No PLTE chunk needed - always encoding as true color
  // Build raw image data (filter byte + row data)
  let raw_buf = @blit.Buffer::new()
  for y = bounds.min_y; y < bounds.max_y; y = y + 1 {
    // Write filter byte (None for simplicity)
    raw_buf.write_byte(ft_none)
    match color_type {
      t if t == ct_true_color =>
        for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
          let (r, g, b, a) = img.at(x, y).rgba()
          let (rr, gg, bb) = if a == 0U {
            (0U, 0U, 0U)
          } else if a == 0xffffU {
            (r, g, b)
          } else {
            (r * 0xffffU / a, g * 0xffffU / a, b * 0xffffU / a)
          }
          raw_buf.write_byte((rr >> 8).to_byte())
          raw_buf.write_byte((gg >> 8).to_byte())
          raw_buf.write_byte((bb >> 8).to_byte())
        }
      _ =>
        // ct_true_color_alpha, 8-bit
        for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
          let (r, g, b, a) = img.at(x, y).rgba()
          if a == 0U {
            raw_buf.write_byte(b'\x00')
            raw_buf.write_byte(b'\x00')
            raw_buf.write_byte(b'\x00')
            raw_buf.write_byte(b'\x00')
          } else if a == 0xffffU {
            raw_buf.write_byte((r >> 8).to_byte())
            raw_buf.write_byte((g >> 8).to_byte())
            raw_buf.write_byte((b >> 8).to_byte())
            raw_buf.write_byte(b'\xff')
          } else {
            raw_buf.write_byte(((r * 0xffffU / a) >> 8).to_byte())
            raw_buf.write_byte(((g * 0xffffU / a) >> 8).to_byte())
            raw_buf.write_byte(((b * 0xffffU / a) >> 8).to_byte())
            raw_buf.write_byte((a >> 8).to_byte())
          }
        }
    }
  }
  let raw_bytes = filter_png_rows(
    raw_buf.to_bytes(),
    width,
    height,
    bit_depth,
    color_type,
    compression,
  )
  let idat_bytes = compressor(raw_bytes, compression)
  // Write IDAT chunk: length + type + data + CRC
  write_u32_be(buf, idat_bytes.length().reinterpret_as_uint())
  write_u32_be(buf, ct_idat)
  buf.write_bytes(idat_bytes)
  // CRC over "IDAT" type + data — inline to avoid Buffer+Bytes copy
  let mut idat_crc = 0xFFFFFFFFU
  idat_crc = crc32_byte(idat_crc, (ct_idat >> 24).to_byte())
  idat_crc = crc32_byte(idat_crc, (ct_idat >> 16).to_byte())
  idat_crc = crc32_byte(idat_crc, (ct_idat >> 8).to_byte())
  idat_crc = crc32_byte(idat_crc, ct_idat.to_byte())
  for i in 0..<idat_bytes.length() {
    idat_crc = crc32_byte(idat_crc, idat_bytes.unsafe_get(i))
  }
  write_u32_be(buf, idat_crc.lxor(0xFFFFFFFFU))
  // Write IEND
  write_chunk(buf, ct_iend, FixedArray::make(0, b'\x00'))
  buf.to_bytes()
}

///|
fn zlib_compress_png_data(
  raw_bytes : Bytes,
  compression : CompressionLevel,
) -> Bytes raise PngError {
  let flate_level : @flate.CompressionLevel = match compression {
    DefaultCompression => @flate.DefaultCompression
    NoCompression => @flate.NoCompression
    BestSpeed => @flate.BestSpeed
    BestCompression => @flate.BestCompression
  }
  let deflater = @zlib.Deflater::new(level=flate_level)
  let out = @blit.Buffer::new(size_hint=raw_bytes.length())
  match deflater.encode(Some(raw_bytes[:])) {
    @zlib.Data(chunk) => out.write_bytesview(chunk)
    @zlib.Ok | @zlib.End => ()
    @zlib.Error(e) =>
      raise PngError::CompressionError(
        "zlib compression failed: " + e.to_string(),
      )
  }
  for enc = deflater.encode(None) {
    match enc {
      @zlib.Data(chunk) => {
        out.write_bytesview(chunk)
        continue deflater.encode(None)
      }
      @zlib.End | @zlib.Ok => break
      @zlib.Error(e) =>
        raise PngError::CompressionError(
          "zlib compression failed: " + e.to_string(),
        )
    }
  }
  out.to_bytes()
}

///|
fn png_is_opaque(img : &@image.Image) -> Bool {
  let bounds = img.bounds()
  for y = bounds.min_y; y < bounds.max_y; y = y + 1 {
    for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
      let (_, _, _, a) = img.at(x, y).rgba()
      if a != 0xffffU {
        return false
      }
    }
  }
  true
}

///|
fn validate_png_image_size(
  width : Int64,
  height : Int64,
) -> Unit raise PngError {
  if width <= 0L || height <= 0L || width >= 1L << 32 || height >= 1L << 32 {
    raise PngError::FormatError(
      "invalid image size: " + width.to_string() + "x" + height.to_string(),
    )
  }
}

///|
fn abs8(v : Byte) -> Int {
  let n = v.to_int()
  if n < 128 {
    n
  } else {
    256 - n
  }
}

///|
fn filter_png_rows(
  raw_bytes : Bytes,
  width : Int,
  height : Int,
  bit_depth : Byte,
  color_type : Byte,
  compression : CompressionLevel,
) -> Bytes {
  if compression == NoCompression || color_type == ct_paletted {
    return raw_bytes
  }
  let row_len = bytes_per_row(width, bit_depth, color_type)
  let bpp = bytes_per_pixel(bit_depth, color_type)
  let prev_row = FixedArray::make(row_len, b'\x00')
  let cur_row = FixedArray::make(row_len, b'\x00')
  let best_row = FixedArray::make(row_len, b'\x00')
  let out = @blit.Buffer::new(size_hint=raw_bytes.length())
  for y in 0..<height {
    let row_start = y * (row_len + 1)
    for i in 0..<row_len {
      cur_row[i] = raw_bytes.unsafe_get(row_start + 1 + i)
    }
    out.write_byte(select_png_filter(cur_row, prev_row, bpp, best_row))
    for i in 0..<row_len {
      out.write_byte(best_row[i])
    }
    @blit.blit_fixed_array(prev_row, 0, cur_row, 0, row_len)
  }
  out.to_bytes()
}

///|
fn select_png_filter(
  cur_row : FixedArray[Byte],
  prev_row : FixedArray[Byte],
  bpp : Int,
  best_row : FixedArray[Byte],
) -> Byte {
  let n = cur_row.length()
  let trial = FixedArray::make(n, b'\x00')
  let mut best_sum = 0
  for i in 0..<n {
    let v = (cur_row[i].to_int() - prev_row[i].to_int()).to_byte()
    trial[i] = v
    best_sum += abs8(v)
  }
  let mut best_filter = ft_up
  @blit.blit_fixed_array(best_row, 0, trial, 0, n)

  let mut sum = 0
  for i in 0..<n {
    let left = if i >= bpp { cur_row[i - bpp].to_int() } else { 0 }
    let upper_left = if i >= bpp { prev_row[i - bpp].to_int() } else { 0 }
    let v = (cur_row[i].to_int() - paeth(left, prev_row[i].to_int(), upper_left)).to_byte()
    trial[i] = v
    sum += abs8(v)
    if sum >= best_sum {
      break
    }
  }
  if sum < best_sum {
    best_sum = sum
    best_filter = ft_paeth
    @blit.blit_fixed_array(best_row, 0, trial, 0, n)
  }

  sum = 0
  for i in 0..<n {
    let v = cur_row[i]
    trial[i] = v
    sum += abs8(v)
    if sum >= best_sum {
      break
    }
  }
  if sum < best_sum {
    best_sum = sum
    best_filter = ft_none
    @blit.blit_fixed_array(best_row, 0, trial, 0, n)
  }

  sum = 0
  for i in 0..<n {
    let left = if i >= bpp { cur_row[i - bpp].to_int() } else { 0 }
    let v = (cur_row[i].to_int() - left).to_byte()
    trial[i] = v
    sum += abs8(v)
    if sum >= best_sum {
      break
    }
  }
  if sum < best_sum {
    best_sum = sum
    best_filter = ft_sub
    @blit.blit_fixed_array(best_row, 0, trial, 0, n)
  }

  sum = 0
  for i in 0..<n {
    let left = if i >= bpp { cur_row[i - bpp].to_int() } else { 0 }
    let v = (cur_row[i].to_int() - (left + prev_row[i].to_int()) / 2).to_byte()
    trial[i] = v
    sum += abs8(v)
    if sum >= best_sum {
      break
    }
  }
  if sum < best_sum {
    best_filter = ft_average
    @blit.blit_fixed_array(best_row, 0, trial, 0, n)
  }

  best_filter
}

///|
/// CRC32 IEEE polynomial table (standard byte-at-a-time).
let crc32_table : FixedArray[UInt] = {
  let t = FixedArray::make(256, 0U)
  for i in 0..<256 {
    let mut crc : UInt = i.reinterpret_as_uint()
    for _ in 0..<8 {
      if (crc & 1U) == 1U {
        crc = (crc >> 1) ^ 0xEDB88320U
      } else {
        crc = crc >> 1
      }
    }
    t.unsafe_set(i, crc)
  }
  t
}

///|
fn crc32_byte(crc : UInt, b : Byte) -> UInt {
  (crc >> 8) ^
  crc32_table.unsafe_get((crc.lxor(b.to_uint()) & 0xFFU).reinterpret_as_int())
}

///|
fn write_u32_be(buf : @blit.Buffer, v : UInt) -> Unit {
  buf.write_byte((v >> 24).to_byte())
  buf.write_byte((v >> 16).to_byte())
  buf.write_byte((v >> 8).to_byte())
  buf.write_byte(v.to_byte())
}

///|
fn write_chunk(
  buf : @blit.Buffer,
  chunk_type : UInt,
  data : FixedArray[Byte],
) -> Unit {
  // Length (4 bytes BE)
  write_u32_be(buf, data.length().reinterpret_as_uint())
  // Type (4 bytes BE)
  write_u32_be(buf, chunk_type)
  // Data
  for i in 0..<data.length() {
    buf.write_byte(data.unsafe_get(i))
  }
  // CRC over type + data — compute using the lookup table directly
  // to avoid Bytes::from_array copy (which was 5.76% of callgrind)
  let mut crc = 0xFFFFFFFFU
  crc = crc32_byte(crc, (chunk_type >> 24).to_byte())
  crc = crc32_byte(crc, (chunk_type >> 16).to_byte())
  crc = crc32_byte(crc, (chunk_type >> 8).to_byte())
  crc = crc32_byte(crc, chunk_type.to_byte())
  for i in 0..<data.length() {
    crc = crc32_byte(crc, data.unsafe_get(i))
  }
  write_u32_be(buf, crc.lxor(0xFFFFFFFFU))
}
