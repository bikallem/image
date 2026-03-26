///|
priv struct ParsedPNG {
  width : Int
  height : Int
  bit_depth : Byte
  color_type : Byte
  palette : Array[@color.AnyColor]
  trns : Bytes
  idat : Bytes
  interlace : Byte
}

///|
priv struct ParsedPNGConfig {
  width : Int
  height : Int
  bit_depth : Byte
  color_type : Byte
  palette : Array[@color.AnyColor]
}

///|
let png_stage_start = 0

///|
let png_stage_seen_ihdr = 1

///|
let png_stage_seen_plte = 2

///|
let png_stage_seen_trns = 3

///|
let png_stage_seen_idat = 4

///|
let png_stage_after_idat = 5

///|
let png_stage_seen_iend = 6

///|
/// Decodes a PNG image from raw bytes.
pub fn decode(data : Bytes) -> @image.AnyImage raise Error {
  let parsed = parse_png(data)
  let decompressed = @zlib.decompress(parsed.idat)
  if parsed.interlace == b'\x00' {
    decode_image(
      decompressed[:],
      parsed.width,
      parsed.height,
      parsed.bit_depth,
      parsed.color_type,
      parsed.palette,
      parsed.trns,
    )
  } else {
    decode_interlaced(
      decompressed,
      parsed.width,
      parsed.height,
      parsed.bit_depth,
      parsed.color_type,
      parsed.palette,
      parsed.trns,
    )
  }
}

///|
fn check_png_header(r : ByteReader) -> Unit raise PngError {
  for i in 0..<8 {
    let b = r.read_byte()
    if b != png_header.unsafe_get(i) {
      raise PngError::FormatError("not a PNG file")
    }
  }
}

///|
fn validate_png_dimensions(width : Int, height : Int) -> Unit raise PngError {
  if width <= 0 || height <= 0 {
    raise PngError::FormatError("bad IHDR width or height")
  }
  let n_pixels = width * height
  if n_pixels < 0 || n_pixels / width != height {
    raise PngError::UnsupportedError("dimension overflow")
  }
  let total_bytes = n_pixels * 8
  if total_bytes < 0 || total_bytes / 8 != n_pixels {
    raise PngError::UnsupportedError("dimension overflow")
  }
}

///|
fn opaque_black() -> @color.AnyColor {
  @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' })
}

///|
fn ensure_palette_index(palette : Array[@color.AnyColor], idx : Int) -> Unit {
  while palette.length() <= idx {
    palette.push(opaque_black())
  }
}

///|
fn parse_png(data : Bytes) -> ParsedPNG raise PngError {
  let r = ByteReader::new(data)
  check_png_header(r)
  let mut width = 0
  let mut height = 0
  let mut bit_depth : Byte = b'\x00'
  let mut color_type : Byte = b'\x00'
  let mut palette : Array[@color.AnyColor] = []
  let mut trns : Bytes = Bytes::new(0)
  let idat_buf = @blit.Buffer::new()
  let mut interlace : Byte = b'\x00'
  let mut stage = png_stage_start
  let mut seen_iend = false
  while !seen_iend {
    if r.remaining() == 0 {
      break
    }
    if r.remaining() < 12 {
      raise PngError::UnexpectedEOF
    }
    let chunk_len = r.read_uint32_be()
    if chunk_len > 0x7fffffffU {
      raise PngError::FormatError("bad chunk length")
    }
    let chunk_type = r.read_uint32_be()
    let chunk_len_i = chunk_len.reinterpret_as_int()
    if r.remaining() < chunk_len_i + 4 {
      raise PngError::UnexpectedEOF
    }
    let chunk_data_start = r.pos
    let chunk_crc_pos = chunk_data_start + chunk_len_i
    match chunk_type {
      t if t == ct_ihdr => {
        if stage != png_stage_start {
          raise PngError::FormatError("chunk out of order")
        }
        stage = png_stage_seen_ihdr
        if chunk_len != 13U {
          raise PngError::FormatError("bad IHDR length")
        }
        width = @binary.read_uint32_be_bytes(r.data, chunk_data_start).reinterpret_as_int()
        height = @binary.read_uint32_be_bytes(r.data, chunk_data_start + 4).reinterpret_as_int()
        bit_depth = r.data.unsafe_get(chunk_data_start + 8)
        color_type = r.data.unsafe_get(chunk_data_start + 9)
        let compression = r.data.unsafe_get(chunk_data_start + 10)
        let filter = r.data.unsafe_get(chunk_data_start + 11)
        interlace = r.data.unsafe_get(chunk_data_start + 12)
        validate_png_dimensions(width, height)
        if !valid_color_type_bit_depth(bit_depth, color_type) {
          raise PngError::UnsupportedError(
            "bit depth " +
            bit_depth.to_int().to_string() +
            ", color type " +
            color_type.to_int().to_string(),
          )
        }
        if compression != b'\x00' {
          raise PngError::UnsupportedError("compression method")
        }
        if filter != b'\x00' {
          raise PngError::UnsupportedError("filter method")
        }
        if interlace != b'\x00' && interlace != b'\x01' {
          raise PngError::UnsupportedError("unknown interlace method")
        }
      }
      t if t == ct_plte => {
        if stage != png_stage_seen_ihdr {
          raise PngError::FormatError("chunk out of order")
        }
        let np = chunk_len_i / 3
        if chunk_len % 3U != 0U ||
          np <= 0 ||
          np > 256 ||
          (color_type == ct_paletted && np > 1 << bit_depth.to_int()) {
          raise PngError::FormatError("bad PLTE length")
        }
        match color_type {
          c if c == ct_paletted ||
            c == ct_true_color ||
            c == ct_true_color_alpha => ()
          _ => raise PngError::FormatError("PLTE, color type mismatch")
        }
        stage = png_stage_seen_plte
        palette = Array::new(capacity=np)
        for i in 0..<np {
          let off = chunk_data_start + i * 3
          palette.push(
            @color.AnyColor::RGBA({
              r: r.data.unsafe_get(off),
              g: r.data.unsafe_get(off + 1),
              b: r.data.unsafe_get(off + 2),
              a: b'\xff',
            }),
          )
        }
      }
      t if t == ct_trns => {
        validate_trns_stage(stage, color_type)
        stage = png_stage_seen_trns
        let raw = r.read_bytes(chunk_len_i)
        trns = normalize_trns(raw, bit_depth, color_type, palette.length())
        if color_type == ct_paletted {
          apply_palette_trns(palette, trns)
        }
      }
      t if t == ct_idat => {
        if stage < png_stage_seen_ihdr ||
          stage > png_stage_seen_idat ||
          (stage == png_stage_seen_ihdr && color_type == ct_paletted) {
          raise PngError::FormatError("chunk out of order")
        }
        stage = png_stage_seen_idat
        let chunk_data = r.read_bytes(chunk_len_i)
        idat_buf.write_bytes(chunk_data)
      }
      t if t == ct_iend => {
        if stage != png_stage_seen_idat && stage != png_stage_after_idat {
          raise PngError::FormatError("chunk out of order")
        }
        if chunk_len != 0U {
          raise PngError::FormatError("bad IEND length")
        }
        stage = png_stage_seen_iend
        seen_iend = true
      }
      _ => {
        if stage == png_stage_seen_idat {
          stage = png_stage_after_idat
        }
        r.skip(chunk_len_i)
      }
    }
    verify_chunk_crc(
      r.data,
      chunk_type,
      chunk_data_start,
      chunk_len_i,
      chunk_crc_pos,
    )
    r.pos = chunk_crc_pos + 4
  }
  if stage == png_stage_start {
    raise PngError::FormatError("missing IHDR")
  }
  if stage != png_stage_seen_iend {
    raise PngError::FormatError("missing IEND")
  }
  {
    width,
    height,
    bit_depth,
    color_type,
    palette,
    trns,
    idat: idat_buf.to_bytes(),
    interlace,
  }
}

///|
fn parse_png_config(data : Bytes) -> ParsedPNGConfig raise PngError {
  let r = ByteReader::new(data)
  check_png_header(r)
  let mut width = 0
  let mut height = 0
  let mut bit_depth : Byte = b'\x00'
  let mut color_type : Byte = b'\x00'
  let mut palette : Array[@color.AnyColor] = []
  let mut stage = png_stage_start
  while true {
    if r.remaining() < 12 {
      raise PngError::UnexpectedEOF
    }
    let chunk_len = r.read_uint32_be()
    if chunk_len > 0x7fffffffU {
      raise PngError::FormatError("bad chunk length")
    }
    let chunk_type = r.read_uint32_be()
    let chunk_len_i = chunk_len.reinterpret_as_int()
    if r.remaining() < chunk_len_i + 4 {
      raise PngError::UnexpectedEOF
    }
    let chunk_data_start = r.pos
    let chunk_crc_pos = chunk_data_start + chunk_len_i
    match chunk_type {
      t if t == ct_ihdr => {
        if stage != png_stage_start {
          raise PngError::FormatError("chunk out of order")
        }
        stage = png_stage_seen_ihdr
        if chunk_len != 13U {
          raise PngError::FormatError("bad IHDR length")
        }
        width = @binary.read_uint32_be_bytes(r.data, chunk_data_start).reinterpret_as_int()
        height = @binary.read_uint32_be_bytes(r.data, chunk_data_start + 4).reinterpret_as_int()
        bit_depth = r.data.unsafe_get(chunk_data_start + 8)
        color_type = r.data.unsafe_get(chunk_data_start + 9)
        let compression = r.data.unsafe_get(chunk_data_start + 10)
        let filter = r.data.unsafe_get(chunk_data_start + 11)
        let interlace = r.data.unsafe_get(chunk_data_start + 12)
        validate_png_dimensions(width, height)
        if !valid_color_type_bit_depth(bit_depth, color_type) {
          raise PngError::UnsupportedError(
            "bit depth " +
            bit_depth.to_int().to_string() +
            ", color type " +
            color_type.to_int().to_string(),
          )
        }
        if compression != b'\x00' {
          raise PngError::UnsupportedError("compression method")
        }
        if filter != b'\x00' {
          raise PngError::UnsupportedError("filter method")
        }
        if interlace != b'\x00' && interlace != b'\x01' {
          raise PngError::UnsupportedError("unknown interlace method")
        }
        ()
      }
      t if t == ct_plte => {
        if stage != png_stage_seen_ihdr {
          raise PngError::FormatError("chunk out of order")
        }
        let np = chunk_len_i / 3
        if chunk_len % 3U != 0U ||
          np <= 0 ||
          np > 256 ||
          (color_type == ct_paletted && np > 1 << bit_depth.to_int()) {
          raise PngError::FormatError("bad PLTE length")
        }
        match color_type {
          c if c == ct_paletted ||
            c == ct_true_color ||
            c == ct_true_color_alpha => ()
          _ => raise PngError::FormatError("PLTE, color type mismatch")
        }
        stage = png_stage_seen_plte
        palette = Array::new(capacity=np)
        for i in 0..<np {
          let off = chunk_data_start + i * 3
          palette.push(
            @color.AnyColor::RGBA({
              r: r.data.unsafe_get(off),
              g: r.data.unsafe_get(off + 1),
              b: r.data.unsafe_get(off + 2),
              a: b'\xff',
            }),
          )
        }
      }
      t if t == ct_trns => {
        validate_trns_stage(stage, color_type)
        stage = png_stage_seen_trns
        let raw = r.read_bytes(chunk_len_i)
        let trns = normalize_trns(raw, bit_depth, color_type, palette.length())
        if color_type == ct_paletted {
          apply_palette_trns(palette, trns)
        }
        ()
      }
      t if t == ct_idat => {
        if stage < png_stage_seen_ihdr ||
          stage > png_stage_seen_idat ||
          (stage == png_stage_seen_ihdr && color_type == ct_paletted) {
          raise PngError::FormatError("chunk out of order")
        }
        return { width, height, bit_depth, color_type, palette }
      }
      _ => r.skip(chunk_len_i)
    }
    verify_chunk_crc(
      r.data,
      chunk_type,
      chunk_data_start,
      chunk_len_i,
      chunk_crc_pos,
    )
    r.pos = chunk_crc_pos + 4
    if chunk_type == ct_ihdr && color_type != ct_paletted {
      return { width, height, bit_depth, color_type, palette }
    }
    if chunk_type == ct_trns && color_type == ct_paletted {
      return { width, height, bit_depth, color_type, palette }
    }
  }
  raise PngError::UnexpectedEOF
}

///|
fn valid_color_type_bit_depth(bit_depth : Byte, color_type : Byte) -> Bool {
  match color_type {
    t if t == ct_grayscale =>
      bit_depth == b'\x01' ||
      bit_depth == b'\x02' ||
      bit_depth == b'\x04' ||
      bit_depth == b'\x08' ||
      bit_depth == b'\x10'
    t if t == ct_true_color => bit_depth == b'\x08' || bit_depth == b'\x10'
    t if t == ct_paletted =>
      bit_depth == b'\x01' ||
      bit_depth == b'\x02' ||
      bit_depth == b'\x04' ||
      bit_depth == b'\x08'
    t if t == ct_grayscale_alpha => bit_depth == b'\x08' || bit_depth == b'\x10'
    t if t == ct_true_color_alpha =>
      bit_depth == b'\x08' || bit_depth == b'\x10'
    _ => false
  }
}

///|
fn validate_trns_stage(stage : Int, color_type : Byte) -> Unit raise PngError {
  match color_type {
    t if t == ct_paletted =>
      if stage != png_stage_seen_plte {
        raise PngError::FormatError("chunk out of order")
      }
    t if t == ct_grayscale || t == ct_true_color =>
      if stage != png_stage_seen_ihdr && stage != png_stage_seen_plte {
        raise PngError::FormatError("chunk out of order")
      }
    _ => raise PngError::FormatError("tRNS, color type mismatch")
  }
}

///|
fn normalize_trns(
  trns : Bytes,
  bit_depth : Byte,
  color_type : Byte,
  palette_len : Int,
) -> Bytes raise PngError {
  match color_type {
    t if t == ct_grayscale => {
      if trns.length() != 2 {
        raise PngError::FormatError("bad tRNS length")
      }
      let scaled = FixedArray::make(2, b'\x00')
      scaled.unsafe_set(0, trns.unsafe_get(0))
      let low = trns.unsafe_get(1)
      let low = match bit_depth {
        b'\x01' => (low.to_int() * 0xff).to_byte()
        b'\x02' => (low.to_int() * 0x55).to_byte()
        b'\x04' => (low.to_int() * 0x11).to_byte()
        _ => low
      }
      scaled.unsafe_set(1, low)
      Bytes::from_array(scaled)
    }
    t if t == ct_true_color => {
      if trns.length() != 6 {
        raise PngError::FormatError("bad tRNS length")
      }
      trns
    }
    t if t == ct_paletted => {
      if trns.length() > 256 || trns.length() > palette_len {
        raise PngError::FormatError("bad tRNS length")
      }
      trns
    }
    _ => raise PngError::FormatError("tRNS, color type mismatch")
  }
}

///|
fn apply_palette_trns(palette : Array[@color.AnyColor], trns : Bytes) -> Unit {
  for i in 0..<trns.length() {
    let (r, g, b, _) = palette.unsafe_get(i).rgba()
    palette.unsafe_set(
      i,
      @color.AnyColor::RGBA({
        r: (r >> 8).to_byte(),
        g: (g >> 8).to_byte(),
        b: (b >> 8).to_byte(),
        a: trns.unsafe_get(i),
      }),
    )
  }
}

///|
fn chunk_crc32(data : Bytes, chunk_type : UInt, start : Int, len : Int) -> UInt {
  let mut crc = 0xFFFFFFFFU
  crc = crc32_byte(crc, (chunk_type >> 24).to_byte())
  crc = crc32_byte(crc, (chunk_type >> 16).to_byte())
  crc = crc32_byte(crc, (chunk_type >> 8).to_byte())
  crc = crc32_byte(crc, chunk_type.to_byte())
  for i in 0..<len {
    crc = crc32_byte(crc, data.unsafe_get(start + i))
  }
  crc.lxor(0xFFFFFFFFU)
}

///|
fn verify_chunk_crc(
  data : Bytes,
  chunk_type : UInt,
  chunk_data_start : Int,
  chunk_len : Int,
  chunk_crc_pos : Int,
) -> Unit raise PngError {
  let actual_crc = chunk_crc32(data, chunk_type, chunk_data_start, chunk_len)
  let expected_crc = @binary.read_uint32_be_bytes(data, chunk_crc_pos)
  if actual_crc != expected_crc {
    raise PngError::FormatError("invalid checksum")
  }
}

///|
/// Adam7 interlace pass parameters: (x_offset, y_offset, x_stride, y_stride)
let adam7 : FixedArray[(Int, Int, Int, Int)] = [
  (0, 0, 8, 8),
  (4, 0, 8, 8),
  (0, 4, 4, 8),
  (2, 0, 4, 4),
  (0, 2, 2, 4),
  (1, 0, 2, 2),
  (0, 1, 1, 2),
]

///|
fn decode_interlaced(
  data : Bytes,
  width : Int,
  height : Int,
  bit_depth : Byte,
  color_type : Byte,
  palette : Array[@color.AnyColor],
  trns : Bytes,
) -> @image.AnyImage raise PngError {
  let rect : @image.Rectangle = {
    min_x: 0,
    min_y: 0,
    max_x: width,
    max_y: height,
  }
  let target = new_png_target_image(rect, bit_depth, color_type, palette, trns)
  let mut offset = 0
  for pass in 0..<7 {
    let (x_off, y_off, x_stride, y_stride) = adam7.unsafe_get(pass)
    let pass_w = if width <= x_off {
      0
    } else {
      (width - x_off + x_stride - 1) / x_stride
    }
    let pass_h = if height <= y_off {
      0
    } else {
      (height - y_off + y_stride - 1) / y_stride
    }
    if pass_w == 0 || pass_h == 0 {
      continue
    }
    let pass_stride = bytes_per_row(pass_w, bit_depth, color_type)
    let pass_data_len = pass_h * (pass_stride + 1)
    if offset + pass_data_len > data.length() {
      raise PngError::FormatError("not enough IDAT data for interlaced pass")
    }
    let pass_img = decode_image(
      data[offset:offset + pass_data_len],
      pass_w,
      pass_h,
      bit_depth,
      color_type,
      palette,
      trns,
    )
    offset += pass_data_len
    for py in 0..<pass_h {
      for px in 0..<pass_w {
        let dst_x = x_off + px * x_stride
        let dst_y = y_off + py * y_stride
        if dst_x < width && dst_y < height {
          let palette_index = match pass_img {
            @image.AnyImage::Paletted(img) =>
              img.color_index_at(px, py).to_int()
            _ => -1
          }
          set_interlaced_pixel(
            target,
            dst_x,
            dst_y,
            pass_img.at(px, py),
            palette_index,
          )
        }
      }
    }
  }
  target
}

///|
fn new_png_target_image(
  rect : @image.Rectangle,
  bit_depth : Byte,
  color_type : Byte,
  palette : Array[@color.AnyColor],
  trns : Bytes,
) -> @image.AnyImage raise PngError {
  match color_type {
    t if t == ct_grayscale =>
      if bit_depth == b'\x10' {
        if has_gray_trns(trns) {
          @image.AnyImage::NRGBA64(@image.new_image_nrgba64(rect))
        } else {
          @image.AnyImage::Gray16(@image.new_image_gray16(rect))
        }
      } else if has_gray_trns(trns) {
        @image.AnyImage::NRGBA(@image.new_image_nrgba(rect))
      } else {
        @image.AnyImage::Gray(@image.new_image_gray(rect))
      }
    t if t == ct_true_color =>
      if bit_depth == b'\x10' {
        if has_true_color_trns(trns) {
          @image.AnyImage::NRGBA64(@image.new_image_nrgba64(rect))
        } else {
          @image.AnyImage::RGBA64(@image.new_image_rgba64(rect))
        }
      } else if has_true_color_trns(trns) {
        @image.AnyImage::NRGBA(@image.new_image_nrgba(rect))
      } else {
        @image.AnyImage::RGBA(@image.new_image_rgba(rect))
      }
    t if t == ct_paletted =>
      @image.AnyImage::Paletted(
        @image.new_image_paletted(rect, @color.Palette::{ colors: palette }),
      )
    t if t == ct_grayscale_alpha =>
      if bit_depth == b'\x10' {
        @image.AnyImage::NRGBA64(@image.new_image_nrgba64(rect))
      } else {
        @image.AnyImage::NRGBA(@image.new_image_nrgba(rect))
      }
    t if t == ct_true_color_alpha =>
      if bit_depth == b'\x10' {
        @image.AnyImage::NRGBA64(@image.new_image_nrgba64(rect))
      } else {
        @image.AnyImage::NRGBA(@image.new_image_nrgba(rect))
      }
    _ =>
      raise PngError::UnsupportedError(
        "color type " + color_type.to_int().to_string(),
      )
  }
}

///|
fn set_interlaced_pixel(
  target : @image.AnyImage,
  x : Int,
  y : Int,
  c : @color.AnyColor,
  palette_index : Int,
) -> Unit {
  match target {
    @image.AnyImage::Gray(img) => {
      guard @color.AnyModel::GrayModel.convert(c) is @color.AnyColor::Gray(gc) else {
        return
      }
      img.set_gray(x, y, gc)
    }
    @image.AnyImage::Gray16(img) => {
      guard @color.AnyModel::Gray16Model.convert(c)
        is @color.AnyColor::Gray16(gc) else {
        return
      }
      img.set_gray16(x, y, gc)
    }
    @image.AnyImage::RGBA(img) => {
      guard @color.AnyModel::RGBAModel.convert(c) is @color.AnyColor::RGBA(rc) else {
        return
      }
      img.set_rgba(x, y, rc)
    }
    @image.AnyImage::RGBA64(img) => {
      guard @color.AnyModel::RGBA64Model.convert(c)
        is @color.AnyColor::RGBA64(rc) else {
        return
      }
      img.set_rgba64(x, y, rc)
    }
    @image.AnyImage::NRGBA(img) => {
      guard @color.AnyModel::NRGBAModel.convert(c) is @color.AnyColor::NRGBA(nc) else {
        return
      }
      img.set_nrgba(x, y, nc)
    }
    @image.AnyImage::NRGBA64(img) => {
      guard @color.AnyModel::NRGBA64Model.convert(c)
        is @color.AnyColor::NRGBA64(nc) else {
        return
      }
      img.set_nrgba64(x, y, nc)
    }
    @image.AnyImage::Paletted(img) =>
      if palette_index >= 0 {
        ensure_palette_index(img.palette.colors, palette_index)
        img.set_color_index(x, y, palette_index.to_byte())
      } else {
        img.set(x, y, c)
      }
    _ => ()
  }
}

///|
fn has_gray_trns(trns : Bytes) -> Bool {
  trns.length() == 2
}

///|
fn has_true_color_trns(trns : Bytes) -> Bool {
  trns.length() == 6
}

///|
fn decode_image(
  data : BytesView,
  width : Int,
  height : Int,
  bit_depth : Byte,
  color_type : Byte,
  palette : Array[@color.AnyColor],
  trns : Bytes,
) -> @image.AnyImage raise PngError {
  let bpp = bytes_per_pixel(bit_depth, color_type)
  let stride = bytes_per_row(width, bit_depth, color_type)
  if data.length() < height * (stride + 1) {
    raise PngError::FormatError(
      "not enough IDAT data: expected " +
      (height * (stride + 1)).to_string() +
      ", got " +
      data.length().to_string(),
    )
  }
  let rect : @image.Rectangle = {
    min_x: 0,
    min_y: 0,
    max_x: width,
    max_y: height,
  }
  let prev_row = FixedArray::make(stride, b'\x00')
  let cur_row = @blit.make_uninit(stride)
  match color_type {
    t if t == ct_grayscale &&
      (bit_depth == b'\x01' || bit_depth == b'\x02' || bit_depth == b'\x04') => {
      let bd = bit_depth.to_int()
      let max_val = (1 << bd) - 1
      if has_gray_trns(trns) {
        let img = @image.new_image_nrgba(rect)
        let transparent_y = trns.unsafe_get(1)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let byte_idx = x * bd / 8
            let bit_off = 8 - bd - x * bd % 8
            let val = (cur_row.unsafe_get(byte_idx).to_int() >> bit_off) &
              max_val
            let gray = (val * 255 / max_val).to_byte()
            let alpha = if gray == transparent_y { b'\x00' } else { b'\xff' }
            img.set_nrgba(x, y, { r: gray, g: gray, b: gray, a: alpha })
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::NRGBA(img)
      } else {
        let img = @image.new_image_gray(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let byte_idx = x * bd / 8
            let bit_off = 8 - bd - x * bd % 8
            let val = (cur_row.unsafe_get(byte_idx).to_int() >> bit_off) &
              max_val
            img.pix.unsafe_set(
              y * img.stride + x,
              (val * 255 / max_val).to_byte(),
            )
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::Gray(img)
      }
    }
    t if t == ct_grayscale && bit_depth == b'\x08' =>
      if has_gray_trns(trns) {
        let img = @image.new_image_nrgba(rect)
        let transparent_y = trns.unsafe_get(1)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let gray = cur_row.unsafe_get(x)
            let alpha = if gray == transparent_y { b'\x00' } else { b'\xff' }
            img.set_nrgba(x, y, { r: gray, g: gray, b: gray, a: alpha })
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::NRGBA(img)
      } else {
        let img = @image.new_image_gray(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            img.pix.unsafe_set(y * img.stride + x, cur_row.unsafe_get(x))
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::Gray(img)
      }
    t if t == ct_grayscale && bit_depth == b'\x10' =>
      if has_gray_trns(trns) {
        let transparent_y = (trns.unsafe_get(0).to_uint() << 8) |
          trns.unsafe_get(1).to_uint()
        let img = @image.new_image_nrgba64(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let gray = (cur_row.unsafe_get(x * 2).to_uint() << 8) |
              cur_row.unsafe_get(x * 2 + 1).to_uint()
            let alpha = if gray == transparent_y { 0U } else { 0xffffU }
            img.set_nrgba64(x, y, { r: gray, g: gray, b: gray, a: alpha })
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::NRGBA64(img)
      } else {
        let img = @image.new_image_gray16(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            img.pix.unsafe_set(
              y * img.stride + x * 2,
              cur_row.unsafe_get(x * 2),
            )
            img.pix.unsafe_set(
              y * img.stride + x * 2 + 1,
              cur_row.unsafe_get(x * 2 + 1),
            )
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::Gray16(img)
      }
    t if t == ct_true_color && bit_depth == b'\x08' =>
      if has_true_color_trns(trns) {
        let tr = trns.unsafe_get(1)
        let tg = trns.unsafe_get(3)
        let tb = trns.unsafe_get(5)
        let img = @image.new_image_nrgba(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let r = cur_row.unsafe_get(x * 3)
            let g = cur_row.unsafe_get(x * 3 + 1)
            let b = cur_row.unsafe_get(x * 3 + 2)
            let a = if r == tr && g == tg && b == tb {
              b'\x00'
            } else {
              b'\xff'
            }
            img.set_nrgba(x, y, { r, g, b, a })
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::NRGBA(img)
      } else {
        let img = @image.new_image_rgba(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let di = y * img.stride + x * 4
            img.pix.unsafe_set(di, cur_row.unsafe_get(x * 3))
            img.pix.unsafe_set(di + 1, cur_row.unsafe_get(x * 3 + 1))
            img.pix.unsafe_set(di + 2, cur_row.unsafe_get(x * 3 + 2))
            img.pix.unsafe_set(di + 3, b'\xff')
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::RGBA(img)
      }
    t if t == ct_true_color && bit_depth == b'\x10' =>
      if has_true_color_trns(trns) {
        let tr = (trns.unsafe_get(0).to_uint() << 8) |
          trns.unsafe_get(1).to_uint()
        let tg = (trns.unsafe_get(2).to_uint() << 8) |
          trns.unsafe_get(3).to_uint()
        let tb = (trns.unsafe_get(4).to_uint() << 8) |
          trns.unsafe_get(5).to_uint()
        let img = @image.new_image_nrgba64(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            let r = (cur_row.unsafe_get(x * 6).to_uint() << 8) |
              cur_row.unsafe_get(x * 6 + 1).to_uint()
            let g = (cur_row.unsafe_get(x * 6 + 2).to_uint() << 8) |
              cur_row.unsafe_get(x * 6 + 3).to_uint()
            let b = (cur_row.unsafe_get(x * 6 + 4).to_uint() << 8) |
              cur_row.unsafe_get(x * 6 + 5).to_uint()
            let a = if r == tr && g == tg && b == tb { 0U } else { 0xffffU }
            img.set_nrgba64(x, y, { r, g, b, a })
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::NRGBA64(img)
      } else {
        let img = @image.new_image_rgba64(rect)
        for y in 0..<height {
          let row_start = y * (stride + 1)
          let filter = data.unsafe_get(row_start)
          for i in 0..<stride {
            cur_row[i] = data.unsafe_get(row_start + 1 + i)
          }
          unfilter(filter, cur_row, prev_row, bpp)
          for x in 0..<width {
            img.set_rgba64(x, y, {
              r: (cur_row.unsafe_get(x * 6).to_uint() << 8) |
              cur_row.unsafe_get(x * 6 + 1).to_uint(),
              g: (cur_row.unsafe_get(x * 6 + 2).to_uint() << 8) |
              cur_row.unsafe_get(x * 6 + 3).to_uint(),
              b: (cur_row.unsafe_get(x * 6 + 4).to_uint() << 8) |
              cur_row.unsafe_get(x * 6 + 5).to_uint(),
              a: 0xffffU,
            })
          }
          @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
        }
        @image.AnyImage::RGBA64(img)
      }
    t if t == ct_paletted => {
      let pal = @color.Palette::{ colors: palette }
      let img = @image.new_image_paletted(rect, pal)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data.unsafe_get(row_start)
        for i in 0..<stride {
          cur_row[i] = data.unsafe_get(row_start + 1 + i)
        }
        unfilter(filter, cur_row, prev_row, bpp)
        match bit_depth {
          b'\x08' =>
            for x in 0..<width {
              let idx = cur_row.unsafe_get(x)
              ensure_palette_index(img.palette.colors, idx.to_int())
              img.pix.unsafe_set(y * img.stride + x, idx)
            }
          b'\x04' =>
            for x in 0..<width {
              let shift = if x % 2 == 0 { 4 } else { 0 }
              let idx = ((cur_row.unsafe_get(x / 2).to_int() >> shift) & 0x0f).to_byte()
              ensure_palette_index(img.palette.colors, idx.to_int())
              img.pix.unsafe_set(y * img.stride + x, idx)
            }
          b'\x02' =>
            for x in 0..<width {
              let idx = ((
                cur_row.unsafe_get(x / 4).to_int() >> ((3 - x % 4) * 2)
              ) &
              0x03).to_byte()
              ensure_palette_index(img.palette.colors, idx.to_int())
              img.pix.unsafe_set(y * img.stride + x, idx)
            }
          b'\x01' =>
            for x in 0..<width {
              let idx = ((cur_row.unsafe_get(x / 8).to_int() >> (7 - x % 8)) &
              0x01).to_byte()
              ensure_palette_index(img.palette.colors, idx.to_int())
              img.pix.unsafe_set(y * img.stride + x, idx)
            }
          _ => ()
        }
        @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::Paletted(img)
    }
    t if t == ct_grayscale_alpha && bit_depth == b'\x08' => {
      let img = @image.new_image_nrgba(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data.unsafe_get(row_start)
        for i in 0..<stride {
          cur_row[i] = data.unsafe_get(row_start + 1 + i)
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          let gray = cur_row.unsafe_get(x * 2)
          let alpha = cur_row.unsafe_get(x * 2 + 1)
          img.set_nrgba(x, y, { r: gray, g: gray, b: gray, a: alpha })
        }
        @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA(img)
    }
    t if t == ct_grayscale_alpha && bit_depth == b'\x10' => {
      let img = @image.new_image_nrgba64(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data.unsafe_get(row_start)
        for i in 0..<stride {
          cur_row[i] = data.unsafe_get(row_start + 1 + i)
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          let gray = (cur_row.unsafe_get(x * 4).to_uint() << 8) |
            cur_row.unsafe_get(x * 4 + 1).to_uint()
          let alpha = (cur_row.unsafe_get(x * 4 + 2).to_uint() << 8) |
            cur_row.unsafe_get(x * 4 + 3).to_uint()
          img.set_nrgba64(x, y, { r: gray, g: gray, b: gray, a: alpha })
        }
        @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA64(img)
    }
    t if t == ct_true_color_alpha && bit_depth == b'\x08' => {
      let img = @image.new_image_nrgba(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data.unsafe_get(row_start)
        for i in 0..<stride {
          cur_row[i] = data.unsafe_get(row_start + 1 + i)
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          img.set_nrgba(x, y, {
            r: cur_row.unsafe_get(x * 4),
            g: cur_row.unsafe_get(x * 4 + 1),
            b: cur_row.unsafe_get(x * 4 + 2),
            a: cur_row.unsafe_get(x * 4 + 3),
          })
        }
        @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA(img)
    }
    t if t == ct_true_color_alpha && bit_depth == b'\x10' => {
      let img = @image.new_image_nrgba64(rect)
      for y in 0..<height {
        let row_start = y * (stride + 1)
        let filter = data.unsafe_get(row_start)
        for i in 0..<stride {
          cur_row[i] = data.unsafe_get(row_start + 1 + i)
        }
        unfilter(filter, cur_row, prev_row, bpp)
        for x in 0..<width {
          img.set_nrgba64(x, y, {
            r: (cur_row.unsafe_get(x * 8).to_uint() << 8) |
            cur_row.unsafe_get(x * 8 + 1).to_uint(),
            g: (cur_row.unsafe_get(x * 8 + 2).to_uint() << 8) |
            cur_row.unsafe_get(x * 8 + 3).to_uint(),
            b: (cur_row.unsafe_get(x * 8 + 4).to_uint() << 8) |
            cur_row.unsafe_get(x * 8 + 5).to_uint(),
            a: (cur_row.unsafe_get(x * 8 + 6).to_uint() << 8) |
            cur_row.unsafe_get(x * 8 + 7).to_uint(),
          })
        }
        @blit.blit_fixed_array(prev_row, 0, cur_row, 0, stride)
      }
      @image.AnyImage::NRGBA64(img)
    }
    _ =>
      raise PngError::UnsupportedError(
        "color type " + color_type.to_int().to_string(),
      )
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
    _ => abort("png: unknown color type " + color_type.to_int().to_string())
  }
}

///|
fn bytes_per_row(width : Int, bit_depth : Byte, color_type : Byte) -> Int {
  let bd = bit_depth.to_int()
  match color_type {
    t if t == ct_grayscale =>
      if bd < 8 {
        (width * bd + 7) / 8
      } else {
        width * (bd / 8)
      }
    t if t == ct_true_color => width * bd / 8 * 3
    t if t == ct_paletted => (width * bd + 7) / 8
    t if t == ct_grayscale_alpha => width * bd / 8 * 2
    t if t == ct_true_color_alpha => width * bd / 8 * 4
    _ => abort("png: unknown color type " + color_type.to_int().to_string())
  }
}

///|
fn unfilter(
  filter : Byte,
  cur : FixedArray[Byte],
  prev : FixedArray[Byte],
  bpp : Int,
) -> Unit raise PngError {
  let n = cur.length()
  match filter {
    f if f == ft_none => ()
    f if f == ft_sub =>
      for i = bpp; i < n; i = i + 1 {
        cur.unsafe_set(
          i,
          (cur.unsafe_get(i).to_int() + cur.unsafe_get(i - bpp).to_int()).to_byte(),
        )
      }
    f if f == ft_up =>
      for i in 0..<n {
        cur.unsafe_set(
          i,
          (cur.unsafe_get(i).to_int() + prev.unsafe_get(i).to_int()).to_byte(),
        )
      }
    f if f == ft_average =>
      for i in 0..<n {
        let a = if i >= bpp { cur.unsafe_get(i - bpp).to_int() } else { 0 }
        cur.unsafe_set(
          i,
          (cur.unsafe_get(i).to_int() + (a + prev.unsafe_get(i).to_int()) / 2).to_byte(),
        )
      }
    f if f == ft_paeth =>
      for i in 0..<n {
        let a = if i >= bpp { cur.unsafe_get(i - bpp).to_int() } else { 0 }
        let b = prev.unsafe_get(i).to_int()
        let c = if i >= bpp { prev.unsafe_get(i - bpp).to_int() } else { 0 }
        let p = a + b - c
        let pa = if p >= a { p - a } else { a - p }
        let pb = if p >= b { p - b } else { b - p }
        let pc = if p >= c { p - c } else { c - p }
        let pr = if pa <= pb && pa <= pc { a } else if pb <= pc { b } else { c }
        cur.unsafe_set(i, (cur.unsafe_get(i).to_int() + pr).to_byte())
      }
    _ => raise PngError::FormatError("unknown filter type")
  }
}

///|
/// Decodes just the configuration (color model and dimensions) of a PNG.
pub fn decode_config(data : Bytes) -> @image.Config raise Error {
  let parsed = parse_png_config(data)
  let cm = png_color_model(parsed.bit_depth, parsed.color_type, parsed.palette)
  { color_model: cm, width: parsed.width, height: parsed.height }
}

///|
fn png_color_model(
  bit_depth : Byte,
  color_type : Byte,
  palette : Array[@color.AnyColor],
) -> @color.AnyModel raise PngError {
  match color_type {
    t if t == ct_grayscale =>
      if bit_depth == b'\x10' {
        @color.AnyModel::Gray16Model
      } else {
        @color.AnyModel::GrayModel
      }
    t if t == ct_true_color =>
      if bit_depth == b'\x10' {
        @color.AnyModel::RGBA64Model
      } else {
        @color.AnyModel::RGBAModel
      }
    t if t == ct_paletted =>
      @color.AnyModel::PaletteModel(@color.Palette::{ colors: palette })
    t if t == ct_grayscale_alpha || t == ct_true_color_alpha =>
      if bit_depth == b'\x10' {
        @color.AnyModel::NRGBA64Model
      } else {
        @color.AnyModel::NRGBAModel
      }
    _ =>
      raise PngError::UnsupportedError(
        "color type " + color_type.to_int().to_string(),
      )
  }
}
