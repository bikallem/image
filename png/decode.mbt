///|
/// Decodes a PNG image from raw bytes.
pub fn decode(data : Bytes) -> @image.AnyImage raise Error {
  let r = ByteReader::new(data)
  // Verify PNG header
  for i in 0..<8 {
    let b = r.read_byte()
    if b != png_header[i] {
      raise PngError::FormatError("not a PNG file")
    }
  }
  // Parse chunks
  let mut width = 0
  let mut height = 0
  let mut bit_depth : Byte = b'\x00'
  let mut color_type : Byte = b'\x00'
  let mut palette : Array[@color.AnyColor] = []
  let mut trns : Bytes = Bytes::new(0)
  let idat_buf = @buffer.new()
  let mut seen_ihdr = false
  let mut seen_iend = false
  while r.remaining() >= 8 && !seen_iend {
    let chunk_len = r.read_uint32_be()
    let chunk_type = r.read_uint32_be()
    if r.remaining() < chunk_len.reinterpret_as_int() + 4 {
      raise PngError::UnexpectedEOF
    }
    let chunk_data_start = r.pos
    match chunk_type {
      t if t == ct_ihdr => {
        if seen_ihdr {
          raise PngError::FormatError("duplicate IHDR")
        }
        seen_ihdr = true
        if chunk_len != 13U {
          raise PngError::FormatError("bad IHDR length")
        }
        width = r.read_uint32_be().reinterpret_as_int()
        height = r.read_uint32_be().reinterpret_as_int()
        bit_depth = r.read_byte()
        color_type = r.read_byte()
        let compression = r.read_byte()
        let filter = r.read_byte()
        let interlace = r.read_byte()
        if compression != b'\x00' {
          raise PngError::UnsupportedError("compression method")
        }
        if filter != b'\x00' {
          raise PngError::UnsupportedError("filter method")
        }
        if interlace != b'\x00' {
          raise PngError::UnsupportedError("interlaced PNG not supported")
        }
      }
      t if t == ct_plte => {
        if chunk_len % 3U != 0U {
          raise PngError::FormatError("bad PLTE length")
        }
        let n = chunk_len.reinterpret_as_int() / 3
        palette = Array::new(capacity=n)
        for _i in 0..<n {
          let pr = r.read_byte()
          let pg = r.read_byte()
          let pb = r.read_byte()
          palette.push(
            @color.AnyColor::RGBA({ r: pr, g: pg, b: pb, a: b'\xff' }),
          )
        }
      }
      t if t == ct_trns => {
        trns = r.read_bytes(chunk_len.reinterpret_as_int())
      }
      t if t == ct_idat => {
        let chunk_data = r.read_bytes(chunk_len.reinterpret_as_int())
        idat_buf.write_bytes(chunk_data)
      }
      t if t == ct_iend => {
        seen_iend = true
      }
      _ => {
        // Skip unknown chunks
        r.skip(chunk_len.reinterpret_as_int())
      }
    }
    // Ensure we're at the right position after chunk data
    r.pos = chunk_data_start + chunk_len.reinterpret_as_int()
    // Skip CRC
    r.skip(4)
  }
  if !seen_ihdr {
    raise PngError::FormatError("missing IHDR")
  }
  // Apply transparency to palette
  if trns.length() > 0 && color_type == ct_paletted {
    for i in 0..<trns.length() {
      if i < palette.length() {
        guard palette[i] is @color.AnyColor::RGBA(c) else { continue }
        palette[i] = @color.AnyColor::NRGBA(
          { r: c.r, g: c.g, b: c.b, a: trns[i] },
        )
      }
    }
  }
  // Decompress IDAT
  let compressed = idat_buf.to_bytes()
  let decompressed = @zlib.decompress(compressed) |> or_png_error()
  // Unfilter and build image
  decode_image(
    decompressed,
    width,
    height,
    bit_depth,
    color_type,
    palette,
    trns,
  )
}

///|
fn or_png_error[T](result : T) -> T raise PngError {
  result
}

///|
fn decode_image(
  data : Bytes,
  width : Int,
  height : Int,
  bit_depth : Byte,
  color_type : Byte,
  palette : Array[@color.AnyColor],
  trns : Bytes
) -> @image.AnyImage raise PngError {
  let bpp = bytes_per_pixel(bit_depth, color_type)
  let stride = bytes_per_row(width, bit_depth, color_type)
  // Each row has a filter byte prefix
  if data.length() < height * (stride + 1) {
    raise PngError::FormatError(
      "not enough IDAT data: expected " + (height * (stride + 1)).to_string() +
      ", got " + data.length().to_string(),
    )
  }
  let rect : @image.Rectangle = {
    min: { x: 0, y: 0 },
    max: { x: width, y: height },
  }
  // Unfilter rows
  let prev_row = FixedArray::make(stride, b'\x00')
  let cur_row = FixedArray::make(stride, b'\x00')
  match color_type {
    t if t == ct_grayscale && bit_depth == b'\x08' => {
      let img = @image.new_image_gray(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data[row_start]
        for i in 0..<stride {
          cur_row[i] = data[row_start + 1 + i]
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          img.pix[y * img.stride + x] = cur_row[x]
        }
        FixedArray::unsafe_blit(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::Gray(img)
    }
    t if t == ct_grayscale && bit_depth == b'\x10' => {
      let img = @image.new_image_gray16(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data[row_start]
        for i in 0..<stride {
          cur_row[i] = data[row_start + 1 + i]
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          img.pix[y * img.stride + x * 2] = cur_row[x * 2]
          img.pix[y * img.stride + x * 2 + 1] = cur_row[x * 2 + 1]
        }
        FixedArray::unsafe_blit(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::Gray16(img)
    }
    t if t == ct_true_color => {
      let img = @image.new_image_nrgba(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data[row_start]
        for i in 0..<stride {
          cur_row[i] = data[row_start + 1 + i]
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          let di = y * img.stride + x * 4
          img.pix[di] = cur_row[x * 3]
          img.pix[di + 1] = cur_row[x * 3 + 1]
          img.pix[di + 2] = cur_row[x * 3 + 2]
          img.pix[di + 3] = b'\xff'
        }
        FixedArray::unsafe_blit(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA(img)
    }
    t if t == ct_paletted => {
      let pal = @color.Palette::{ colors: palette }
      let img = @image.new_image_paletted(rect, pal)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data[row_start]
        for i in 0..<stride {
          cur_row[i] = data[row_start + 1 + i]
        }
        unfilter(filter, cur_row, prev_row, bpp)
        if bit_depth == b'\x08' {
          for x in 0..<width {
            img.pix[y * img.stride + x] = cur_row[x]
          }
        } else if bit_depth == b'\x04' {
          for x in 0..<width {
            let byte_idx = x / 2
            let shift = if x % 2 == 0 { 4 } else { 0 }
            img.pix[y * img.stride + x] = ((cur_row[byte_idx].to_int() >> shift) & 0x0f).to_byte()
          }
        } else if bit_depth == b'\x02' {
          for x in 0..<width {
            let byte_idx = x / 4
            let shift = (3 - x % 4) * 2
            img.pix[y * img.stride + x] = ((cur_row[byte_idx].to_int() >> shift) & 0x03).to_byte()
          }
        } else if bit_depth == b'\x01' {
          for x in 0..<width {
            let byte_idx = x / 8
            let shift = 7 - x % 8
            img.pix[y * img.stride + x] = ((cur_row[byte_idx].to_int() >> shift) & 0x01).to_byte()
          }
        }
        FixedArray::unsafe_blit(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::Paletted(img)
    }
    t if t == ct_grayscale_alpha => {
      let img = if bit_depth == b'\x08' {
        @image.new_image_nrgba(rect)
      } else {
        @image.new_image_nrgba(rect)
      }
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data[row_start]
        for i in 0..<stride {
          cur_row[i] = data[row_start + 1 + i]
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          let di = y * img.stride + x * 4
          let gray = cur_row[x * 2]
          let alpha = cur_row[x * 2 + 1]
          img.pix[di] = gray
          img.pix[di + 1] = gray
          img.pix[di + 2] = gray
          img.pix[di + 3] = alpha
        }
        FixedArray::unsafe_blit(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA(img)
    }
    t if t == ct_true_color_alpha => {
      let img = @image.new_image_nrgba(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data[row_start]
        for i in 0..<stride {
          cur_row[i] = data[row_start + 1 + i]
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          let di = y * img.stride + x * 4
          img.pix[di] = cur_row[x * 4]
          img.pix[di + 1] = cur_row[x * 4 + 1]
          img.pix[di + 2] = cur_row[x * 4 + 2]
          img.pix[di + 3] = cur_row[x * 4 + 3]
        }
        FixedArray::unsafe_blit(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA(img)
    }
    _ => {
      ignore(trns)
      raise PngError::UnsupportedError(
        "color type " + color_type.to_int().to_string(),
      )
    }
  }
}

///|
fn bytes_per_pixel(bit_depth : Byte, color_type : Byte) -> Int {
  let bd = bit_depth.to_int()
  match color_type {
    t if t == ct_grayscale => if bd < 8 { 1 } else { bd / 8 }
    t if t == ct_true_color => bd / 8 * 3
    t if t == ct_paletted => 1
    t if t == ct_grayscale_alpha => bd / 8 * 2
    t if t == ct_true_color_alpha => bd / 8 * 4
    _ => 1
  }
}

///|
fn bytes_per_row(width : Int, bit_depth : Byte, color_type : Byte) -> Int {
  let bd = bit_depth.to_int()
  match color_type {
    t if t == ct_grayscale =>
      if bd < 8 { (width * bd + 7) / 8 } else { width * (bd / 8) }
    t if t == ct_true_color => width * bd / 8 * 3
    t if t == ct_paletted => (width * bd + 7) / 8
    t if t == ct_grayscale_alpha => width * bd / 8 * 2
    t if t == ct_true_color_alpha => width * bd / 8 * 4
    _ => width
  }
}

///|
fn unfilter(
  filter : Byte,
  cur : FixedArray[Byte],
  prev : FixedArray[Byte],
  bpp : Int
) -> Unit raise PngError {
  let n = cur.length()
  match filter {
    f if f == ft_none => ()
    f if f == ft_sub =>
      for i = bpp; i < n; i = i + 1 {
        cur[i] = (cur[i].to_int() + cur[i - bpp].to_int()).to_byte()
      }
    f if f == ft_up =>
      for i = 0; i < n; i = i + 1 {
        cur[i] = (cur[i].to_int() + prev[i].to_int()).to_byte()
      }
    f if f == ft_average =>
      for i = 0; i < n; i = i + 1 {
        let a = if i >= bpp { cur[i - bpp].to_int() } else { 0 }
        cur[i] = (cur[i].to_int() + (a + prev[i].to_int()) / 2).to_byte()
      }
    f if f == ft_paeth =>
      for i = 0; i < n; i = i + 1 {
        let a = if i >= bpp { cur[i - bpp].to_int() } else { 0 }
        let b = prev[i].to_int()
        let c = if i >= bpp { prev[i - bpp].to_int() } else { 0 }
        cur[i] = (cur[i].to_int() + paeth(a, b, c)).to_byte()
      }
    _ => raise PngError::FormatError("unknown filter type")
  }
}

///|
/// Decodes just the configuration (color model and dimensions) of a PNG.
pub fn decode_config(data : Bytes) -> @image.Config raise Error {
  let r = ByteReader::new(data)
  for i in 0..<8 {
    let b = r.read_byte()
    if b != png_header[i] {
      raise PngError::FormatError("not a PNG file")
    }
  }
  let chunk_len = r.read_uint32_be()
  let chunk_type = r.read_uint32_be()
  if chunk_type != ct_ihdr || chunk_len != 13U {
    raise PngError::FormatError("missing IHDR")
  }
  let width = r.read_uint32_be().reinterpret_as_int()
  let height = r.read_uint32_be().reinterpret_as_int()
  let _bit_depth = r.read_byte()
  let color_type = r.read_byte()
  let cm : @color.AnyModel = match color_type {
    t if t == ct_grayscale => @color.AnyModel::GrayModel
    t if t == ct_true_color => @color.AnyModel::NRGBAModel
    t if t == ct_paletted => @color.AnyModel::NRGBAModel
    t if t == ct_grayscale_alpha => @color.AnyModel::NRGBAModel
    t if t == ct_true_color_alpha => @color.AnyModel::NRGBAModel
    _ => @color.AnyModel::NRGBAModel
  }
  { color_model: cm, width, height }
}
