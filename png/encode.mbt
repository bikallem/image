///|
/// Encodes an image as PNG.
pub fn encode(img : @image.AnyImage) -> Bytes raise Error {
  let buf = @buffer.new()
  // Write PNG signature
  for i in 0..<8 {
    buf.write_byte(png_header[i])
  }
  let bounds = img.bounds()
  let width = bounds.dx()
  let height = bounds.dy()
  // Determine color type based on image type
  let (color_type, bit_depth) : (Byte, Byte) = match img {
    @image.AnyImage::Gray(_) => (ct_grayscale, b'\x08')
    @image.AnyImage::Gray16(_) => (ct_grayscale, b'\x10')
    @image.AnyImage::Paletted(_) => (ct_paletted, b'\x08')
    _ => (ct_true_color_alpha, b'\x08')
  }
  // Write IHDR
  let ihdr = FixedArray::make(13, b'\x00')
  @binary.write_uint32_be(ihdr, 0, width.reinterpret_as_uint())
  @binary.write_uint32_be(ihdr, 4, height.reinterpret_as_uint())
  ihdr[8] = bit_depth
  ihdr[9] = color_type
  ihdr[10] = b'\x00' // compression
  ihdr[11] = b'\x00' // filter
  ihdr[12] = b'\x00' // interlace
  write_chunk(buf, ct_ihdr, ihdr)
  // Write PLTE if paletted
  match img {
    @image.AnyImage::Paletted(p) => {
      let pal_data = FixedArray::make(p.palette.colors.length() * 3, b'\x00')
      let mut has_alpha = false
      for i, c in p.palette.colors {
        let (r, g, b, a) = c.rgba()
        pal_data[i * 3] = (r >> 8).to_byte()
        pal_data[i * 3 + 1] = (g >> 8).to_byte()
        pal_data[i * 3 + 2] = (b >> 8).to_byte()
        if a != 0xffffU {
          has_alpha = true
        }
      }
      write_chunk(buf, ct_plte, pal_data)
      if has_alpha {
        let trns_data = FixedArray::make(p.palette.colors.length(), b'\xff')
        for i, c in p.palette.colors {
          let (_, _, _, a) = c.rgba()
          trns_data[i] = (a >> 8).to_byte()
        }
        write_chunk(buf, ct_trns, trns_data)
      }
    }
    _ => ()
  }
  // Build raw image data (filter byte + row data)
  let raw_buf = @buffer.new()
  for y = bounds.min.y; y < bounds.max.y; y = y + 1 {
    // Write filter byte (None for simplicity)
    raw_buf.write_byte(ft_none)
    match img {
      @image.AnyImage::Gray(g) =>
        for x = bounds.min.x; x < bounds.max.x; x = x + 1 {
          let c = g.gray_at(x, y)
          raw_buf.write_byte(c.y)
        }
      @image.AnyImage::Gray16(g) =>
        for x = bounds.min.x; x < bounds.max.x; x = x + 1 {
          let c = g.gray16_at(x, y)
          raw_buf.write_byte((c.y >> 8).to_byte())
          raw_buf.write_byte(c.y.to_byte())
        }
      @image.AnyImage::Paletted(p) =>
        for x = bounds.min.x; x < bounds.max.x; x = x + 1 {
          raw_buf.write_byte(p.color_index_at(x, y))
        }
      @image.AnyImage::NRGBA(n) =>
        for x = bounds.min.x; x < bounds.max.x; x = x + 1 {
          let c = n.nrgba_at(x, y)
          raw_buf.write_byte(c.r)
          raw_buf.write_byte(c.g)
          raw_buf.write_byte(c.b)
          raw_buf.write_byte(c.a)
        }
      _ =>
        for x = bounds.min.x; x < bounds.max.x; x = x + 1 {
          let (r, g, b, a) = img.at(x, y).rgba()
          // Convert premultiplied to non-premultiplied for RGBA output
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
            let nr = r * 0xffffU / a
            let ng = g * 0xffffU / a
            let nb = b * 0xffffU / a
            raw_buf.write_byte((nr >> 8).to_byte())
            raw_buf.write_byte((ng >> 8).to_byte())
            raw_buf.write_byte((nb >> 8).to_byte())
            raw_buf.write_byte((a >> 8).to_byte())
          }
        }
    }
  }
  // Compress and write IDAT
  let compressed = @zlib.compress(raw_buf.to_bytes()) |> or_png_error()
  let idat_data = FixedArray::make(compressed.length(), b'\x00')
  for i in 0..<compressed.length() {
    idat_data[i] = compressed[i]
  }
  write_chunk(buf, ct_idat, idat_data)
  // Write IEND
  write_chunk(buf, ct_iend, FixedArray::make(0, b'\x00'))
  buf.to_bytes()
}

///|
fn write_chunk(
  buf : @buffer.Buffer,
  chunk_type : UInt,
  data : FixedArray[Byte]
) -> Unit {
  // Length
  let len_bytes = FixedArray::make(4, b'\x00')
  @binary.write_uint32_be(len_bytes, 0, data.length().reinterpret_as_uint())
  for i in 0..<4 {
    buf.write_byte(len_bytes[i])
  }
  // Type
  let type_bytes = FixedArray::make(4, b'\x00')
  @binary.write_uint32_be(type_bytes, 0, chunk_type)
  for i in 0..<4 {
    buf.write_byte(type_bytes[i])
  }
  // Data
  for i in 0..<data.length() {
    buf.write_byte(data[i])
  }
  // CRC (over type + data)
  let crc_buf = @buffer.new(size_hint=4 + data.length())
  for i in 0..<4 {
    crc_buf.write_byte(type_bytes[i])
  }
  for i in 0..<data.length() {
    crc_buf.write_byte(data[i])
  }
  let crc_bytes = crc_buf.to_bytes()
  let crc = @checksum.crc32(crc_bytes[:])
  let crc_out = FixedArray::make(4, b'\x00')
  @binary.write_uint32_be(crc_out, 0, crc)
  for i in 0..<4 {
    buf.write_byte(crc_out[i])
  }
}
