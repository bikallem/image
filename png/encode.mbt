///|
/// PNG compression level.
pub(all) enum CompressionLevel {
  DefaultCompression
  NoCompression
  BestSpeed
  BestCompression
} derive(Eq, Show)

///|
/// Encodes an image as PNG.
pub fn encode(
  img : @image.AnyImage,
  compression? : CompressionLevel = DefaultCompression,
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
  if img is @image.AnyImage::Paletted(p) {
    validate_png_palette_length(p.palette.colors.length())
  }
  // Determine color type based on image type
  let (color_type, bit_depth) : (Byte, Byte) = match img {
    @image.AnyImage::Gray(_) => (ct_grayscale, b'\x08')
    @image.AnyImage::Gray16(_) => (ct_grayscale, b'\x10')
    @image.AnyImage::Paletted(p) =>
      (ct_paletted, png_palette_bit_depth(p.palette.colors.length()))
    @image.AnyImage::RGBA(_)
    | @image.AnyImage::NRGBA(_)
    | @image.AnyImage::Alpha(_) =>
      if all_opaque {
        (ct_true_color, b'\x08')
      } else {
        (ct_true_color_alpha, b'\x08')
      }
    @image.AnyImage::RGBA64(_)
    | @image.AnyImage::NRGBA64(_)
    | @image.AnyImage::Alpha16(_)
    | @image.AnyImage::YCbCr(_)
    | @image.AnyImage::NYCbCrA(_)
    | @image.AnyImage::CMYK(_)
    | @image.AnyImage::Uniform(_) =>
      if all_opaque {
        (ct_true_color, b'\x10')
      } else {
        (ct_true_color_alpha, b'\x10')
      }
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
  // Write PLTE if paletted
  if img is @image.AnyImage::Paletted(p) {
    let pal_data = FixedArray::make(p.palette.colors.length() * 3, b'\x00')
    let mut has_alpha = false
    for i, c in p.palette.colors {
      let (r, g, b, a) = c.rgba()
      pal_data.unsafe_set(i * 3, (r >> 8).to_byte())
      pal_data.unsafe_set(i * 3 + 1, (g >> 8).to_byte())
      pal_data.unsafe_set(i * 3 + 2, (b >> 8).to_byte())
      if a != 0xffffU {
        has_alpha = true
      }
    }
    write_chunk(buf, ct_plte, pal_data)
    if has_alpha {
      let trns_data = FixedArray::make(p.palette.colors.length(), b'\xff')
      for i, c in p.palette.colors {
        let (_, _, _, a) = c.rgba()
        trns_data.unsafe_set(i, (a >> 8).to_byte())
      }
      write_chunk(buf, ct_trns, trns_data)
    }
  }
  // Build raw image data (filter byte + row data)
  let raw_buf = @blit.Buffer::new()
  for y = bounds.min_y; y < bounds.max_y; y = y + 1 {
    // Write filter byte (None for simplicity)
    raw_buf.write_byte(ft_none)
    match color_type {
      t if t == ct_grayscale && bit_depth == b'\x08' =>
        match img {
          @image.AnyImage::Gray(g) =>
            for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
              raw_buf.write_byte(g.gray_at(x, y).y)
            }
          _ =>
            for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
              guard @color.AnyModel::GrayModel.convert(img.at(x, y))
                is @color.AnyColor::Gray(c) else {
                continue
              }
              raw_buf.write_byte(c.y)
            }
        }
      t if t == ct_grayscale && bit_depth == b'\x10' =>
        match img {
          @image.AnyImage::Gray16(g) =>
            for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
              let c = g.gray16_at(x, y)
              raw_buf.write_byte((c.y >> 8).to_byte())
              raw_buf.write_byte(c.y.to_byte())
            }
          _ =>
            for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
              guard @color.AnyModel::Gray16Model.convert(img.at(x, y))
                is @color.AnyColor::Gray16(c) else {
                continue
              }
              raw_buf.write_byte((c.y >> 8).to_byte())
              raw_buf.write_byte(c.y.to_byte())
            }
        }
      t if t == ct_paletted =>
        match img {
          @image.AnyImage::Paletted(p) =>
            write_paletted_row(raw_buf, p, bounds, y, bit_depth)
          _ => ()
        }
      t if t == ct_true_color && bit_depth == b'\x08' =>
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
      t if t == ct_true_color && bit_depth == b'\x10' =>
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
          raw_buf.write_byte(rr.to_byte())
          raw_buf.write_byte((gg >> 8).to_byte())
          raw_buf.write_byte(gg.to_byte())
          raw_buf.write_byte((bb >> 8).to_byte())
          raw_buf.write_byte(bb.to_byte())
        }
      t if t == ct_true_color_alpha && bit_depth == b'\x08' =>
        match img {
          @image.AnyImage::NRGBA(n) =>
            for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
              let c = n.nrgba_at(x, y)
              raw_buf.write_byte(c.r)
              raw_buf.write_byte(c.g)
              raw_buf.write_byte(c.b)
              raw_buf.write_byte(c.a)
            }
          @image.AnyImage::RGBA(rgba) => {
            let row_off = rgba.pix_offset +
              (y - rgba.rect.min_y) * rgba.stride +
              (bounds.min_x - rgba.rect.min_x) * 4
            for x in 0..<width {
              let si = row_off + x * 4
              let r = rgba.pix.unsafe_get(si)
              let g = rgba.pix.unsafe_get(si + 1)
              let b = rgba.pix.unsafe_get(si + 2)
              let a = rgba.pix.unsafe_get(si + 3)
              if a == b'\xff' {
                raw_buf.write_byte(r)
                raw_buf.write_byte(g)
                raw_buf.write_byte(b)
                raw_buf.write_byte(b'\xff')
              } else if a == b'\x00' {
                raw_buf.write_byte(b'\x00')
                raw_buf.write_byte(b'\x00')
                raw_buf.write_byte(b'\x00')
                raw_buf.write_byte(b'\x00')
              } else {
                let aa = a.to_uint()
                raw_buf.write_byte((r.to_uint() * 0xffU / aa).to_byte())
                raw_buf.write_byte((g.to_uint() * 0xffU / aa).to_byte())
                raw_buf.write_byte((b.to_uint() * 0xffU / aa).to_byte())
                raw_buf.write_byte(a)
              }
            }
          }
          _ =>
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
      t if t == ct_true_color_alpha && bit_depth == b'\x10' =>
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
          raw_buf.write_byte(rr.to_byte())
          raw_buf.write_byte((gg >> 8).to_byte())
          raw_buf.write_byte(gg.to_byte())
          raw_buf.write_byte((bb >> 8).to_byte())
          raw_buf.write_byte(bb.to_byte())
          raw_buf.write_byte((a >> 8).to_byte())
          raw_buf.write_byte(a.to_byte())
        }
      _ => ()
    }
  }
  // Compress raw image data using deflate directly, streaming into idat_buf.
  // This avoids the zlib::compress wrapper which copies data multiple times.
  let flate_level : @flate.CompressionLevel = match compression {
    DefaultCompression => @flate.DefaultCompression
    NoCompression => @flate.NoCompression
    BestSpeed => @flate.BestSpeed
    BestCompression => @flate.BestCompression
  }
  let raw_bytes = filter_png_rows(
    raw_buf.to_bytes(),
    width,
    height,
    bit_depth,
    color_type,
    compression,
  )
  let idat_buf = @blit.Buffer::new(size_hint=raw_bytes.length())
  // Zlib header (CMF=0x78, FLG depends on level)
  let cmf : Int = 0x78 // deflate, window=32K
  let flevel = match compression {
    NoCompression => 0
    BestSpeed => 1
    DefaultCompression => 2
    BestCompression => 3
  }
  let mut flg = flevel << 6
  let remainder = (cmf * 256 + flg) % 31
  if remainder != 0 {
    flg += 31 - remainder
  }
  idat_buf.write_byte(cmf.to_byte())
  idat_buf.write_byte(flg.to_byte())
  // Deflate the data
  let deflater = @flate.Deflater::new(level=flate_level)
  match deflater.encode(Some(raw_bytes[:])) {
    @flate.Data(chunk) => idat_buf.write_bytesview(chunk)
    @flate.Ok | @flate.End => ()
    @flate.Error(e) => abort("png: deflate error: " + e.to_string())
  }
  match deflater.encode(None) {
    @flate.Data(chunk) => idat_buf.write_bytesview(chunk)
    @flate.Ok | @flate.End => ()
    @flate.Error(e) => abort("png: deflate error: " + e.to_string())
  }
  // Adler-32 checksum of uncompressed data (big-endian)
  let adler = @checksum.adler32(raw_bytes[:])
  idat_buf.write_byte((adler >> 24).to_byte())
  idat_buf.write_byte((adler >> 16).to_byte())
  idat_buf.write_byte((adler >> 8).to_byte())
  idat_buf.write_byte(adler.to_byte())
  // Write IDAT chunk: length + type + data + CRC
  let idat_bytes = idat_buf.to_bytes()
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
fn png_is_opaque(img : @image.AnyImage) -> Bool {
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
fn validate_png_palette_length(n : Int) -> Unit raise PngError {
  if n < 1 || n > 256 {
    raise PngError::FormatError("bad palette length: " + n.to_string())
  }
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
fn png_palette_bit_depth(n : Int) -> Byte {
  if n <= 2 {
    b'\x01'
  } else if n <= 4 {
    b'\x02'
  } else if n <= 16 {
    b'\x04'
  } else {
    b'\x08'
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
fn write_paletted_row(
  raw_buf : @blit.Buffer,
  img : @image.ImagePaletted,
  bounds : @image.Rectangle,
  y : Int,
  bit_depth : Byte,
) -> Unit {
  if bit_depth == b'\x08' {
    for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
      raw_buf.write_byte(img.color_index_at(x, y))
    }
    return
  }
  let bits_per_pixel = bit_depth.to_int()
  let pixels_per_byte = 8 / bits_per_pixel
  let mut packed = 0
  let mut count = 0
  for x = bounds.min_x; x < bounds.max_x; x = x + 1 {
    packed = (packed << bits_per_pixel) | img.color_index_at(x, y).to_int()
    count += 1
    if count == pixels_per_byte {
      raw_buf.write_byte(packed.to_byte())
      packed = 0
      count = 0
    }
  }
  if count != 0 {
    while count < pixels_per_byte {
      packed = packed << bits_per_pixel
      count += 1
    }
    raw_buf.write_byte(packed.to_byte())
  }
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
