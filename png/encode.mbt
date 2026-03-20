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
  compression~ : CompressionLevel = DefaultCompression
) -> Bytes {
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
  // Compress raw image data using deflate directly, streaming into idat_buf.
  // This avoids the zlib::compress wrapper which copies data multiple times.
  let flate_level : @flate.CompressionLevel = match compression {
    DefaultCompression => @flate.DefaultCompression
    NoCompression => @flate.NoCompression
    BestSpeed => @flate.BestSpeed
    BestCompression => @flate.BestCompression
  }
  let raw_bytes = raw_buf.to_bytes()
  let idat_buf = @buffer.new(size_hint=raw_bytes.length())
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
    @flate.Data(chunk) => idat_buf.write_bytes(chunk)
    _ => ()
  }
  match deflater.encode(None) {
    @flate.Data(chunk) => idat_buf.write_bytes(chunk)
    _ => ()
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
  // CRC over "IDAT" type + data
  let crc_buf = @buffer.new(size_hint=4 + idat_bytes.length())
  crc_buf.write_byte((ct_idat >> 24).to_byte())
  crc_buf.write_byte((ct_idat >> 16).to_byte())
  crc_buf.write_byte((ct_idat >> 8).to_byte())
  crc_buf.write_byte(ct_idat.to_byte())
  crc_buf.write_bytes(idat_bytes)
  write_u32_be(buf, @checksum.crc32(crc_buf.to_bytes()[:]))
  // Write IEND
  write_chunk(buf, ct_iend, FixedArray::make(0, b'\x00'))
  buf.to_bytes()
}

///|
fn write_u32_be(buf : @buffer.Buffer, v : UInt) -> Unit {
  buf.write_byte((v >> 24).to_byte())
  buf.write_byte((v >> 16).to_byte())
  buf.write_byte((v >> 8).to_byte())
  buf.write_byte(v.to_byte())
}

///|
fn write_chunk(
  buf : @buffer.Buffer,
  chunk_type : UInt,
  data : FixedArray[Byte]
) -> Unit {
  // Length (4 bytes BE)
  write_u32_be(buf, data.length().reinterpret_as_uint())
  // Type (4 bytes BE)
  write_u32_be(buf, chunk_type)
  // Data
  for i in 0..<data.length() {
    buf.write_byte(data[i])
  }
  // CRC over type + data
  let crc_data = @blit.make_uninit(4 + data.length())
  crc_data[0] = (chunk_type >> 24).to_byte()
  crc_data[1] = (chunk_type >> 16).to_byte()
  crc_data[2] = (chunk_type >> 8).to_byte()
  crc_data[3] = chunk_type.to_byte()
  @blit.blit_fixed_array(crc_data, 4, data, 0, data.length())
  let crc = @checksum.crc32(Bytes::from_array(crc_data)[:])
  write_u32_be(buf, crc)
}
