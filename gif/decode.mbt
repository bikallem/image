///|
/// Decodes a GIF image from bytes.
pub fn decode(data : Bytes) -> @image.AnyImage raise Error {
  let gif = decode_all(data)
  if gif.image.is_empty() {
    raise GifError::FormatError("no image data")
  }
  @image.AnyImage::Paletted(gif.image.unsafe_get(0))
}

///|
fn empty_palette_model() -> @color.AnyModel {
  @color.AnyModel::PaletteModel(@color.Palette::{ colors: [] })
}

///|
/// Decodes the configuration of a GIF image.
pub fn decode_config(data : Bytes) -> @image.Config raise Error {
  let r = GifByteReader::new(data)
  validate_gif_header(r)
  let width = r.read_uint16_le().reinterpret_as_int()
  let height = r.read_uint16_le().reinterpret_as_int()
  let packed = r.read_byte()
  ignore(r.read_byte())
  r.skip(1)
  let has_gct = (packed.to_int() & 0x80) != 0
  let gct_size = 1 << ((packed.to_int() & 0x07) + 1)
  let color_model = if has_gct {
    let palette = read_color_table(r, gct_size)
    @color.AnyModel::PaletteModel(@color.Palette::{ colors: palette })
  } else {
    empty_palette_model()
  }
  { color_model, width, height }
}

///|
fn validate_gif_header(r : GifByteReader) -> Unit raise GifError {
  let sig = r.read_bytes(6)
  if sig.length() != 6 ||
    sig.unsafe_get(0) != b'\x47' ||
    sig.unsafe_get(1) != b'\x49' ||
    sig.unsafe_get(2) != b'\x46' ||
    sig.unsafe_get(3) != b'\x38' ||
    (sig.unsafe_get(4) != b'\x37' && sig.unsafe_get(4) != b'\x39') ||
    sig.unsafe_get(5) != b'\x61' {
    raise GifError::FormatError("not a GIF file")
  }
}

///|
/// Decodes all frames of a GIF image.
pub fn decode_all(data : Bytes) -> GIF raise Error {
  let r = GifByteReader::new(data)
  validate_gif_header(r)
  let width = r.read_uint16_le().reinterpret_as_int()
  let height = r.read_uint16_le().reinterpret_as_int()
  let packed = r.read_byte()
  let bg_index = r.read_byte()
  r.skip(1)
  let has_gct = (packed.to_int() & 0x80) != 0
  let gct_size = 1 << ((packed.to_int() & 0x07) + 1)
  let global_palette = if has_gct { read_color_table(r, gct_size) } else { [] }
  let images : Array[@image.ImagePaletted] = []
  let delays : Array[Int] = []
  let disposals : Array[Byte] = []
  let mut delay = 0
  let mut disposal : Byte = b'\x00'
  let mut transparent_index : Int = -1
  let mut loop_count = -1
  let mut done = false
  while !done && r.remaining() > 0 {
    let block_type = r.read_byte()
    match block_type {
      b if b == ext_introducer => {
        let label = r.read_byte()
        match label {
          l if l == ext_graphic_control => {
            let block_size = r.read_byte()
            if block_size != b'\x04' {
              raise GifError::FormatError("bad graphic control block size")
            }
            let gce_packed = r.read_byte()
            delay = r.read_uint16_le().reinterpret_as_int()
            let ti = r.read_byte().to_int()
            let terminator = r.read_byte()
            if terminator != b'\x00' {
              raise GifError::FormatError("bad graphic control terminator")
            }
            disposal = ((gce_packed.to_int() >> 2) & 0x07).to_byte()
            if (gce_packed.to_int() & 0x01) != 0 {
              transparent_index = ti
            } else {
              transparent_index = -1
            }
          }
          l if l == ext_application =>
            loop_count = read_application_extension(r, loop_count)
          _ => skip_sub_blocks(r)
        }
      }
      b if b == image_descriptor => {
        let left = r.read_uint16_le().reinterpret_as_int()
        let top = r.read_uint16_le().reinterpret_as_int()
        let img_width = r.read_uint16_le().reinterpret_as_int()
        let img_height = r.read_uint16_le().reinterpret_as_int()
        if left + img_width > width || top + img_height > height {
          raise GifError::FormatError("frame bounds larger than image bounds")
        }
        let img_packed = r.read_byte()
        let has_lct = (img_packed.to_int() & 0x80) != 0
        let interlaced = (img_packed.to_int() & 0x40) != 0
        let lct_size = 1 << ((img_packed.to_int() & 0x07) + 1)
        let mut palette = if has_lct {
          read_color_table(r, lct_size)
        } else if !global_palette.is_empty() {
          global_palette.copy()
        } else {
          raise GifError::FormatError("no color table")
        }
        if transparent_index >= 0 {
          palette = apply_transparent_index(palette, transparent_index)
        }
        let lzw_min = r.read_byte()
        if lzw_min.to_int() < 2 || lzw_min.to_int() > 8 {
          raise GifError::FormatError(
            "pixel size in decode out of range: " + lzw_min.to_int().to_string(),
          )
        }
        let lzw_data = read_sub_blocks(r)
        let decompressed = @lzw.decompress(
          lzw_data,
          @lzw.BitOrder::LSB,
          lzw_min.to_int(),
        )
        let rect : @image.Rectangle = {
          min_x: left,
          min_y: top,
          max_x: left + img_width,
          max_y: top + img_height,
        }
        let pal = @color.Palette::{ colors: palette }
        let img = @image.new_image_paletted(rect, pal)
        let pixel_count = img_width * img_height
        if decompressed.length() != pixel_count {
          raise GifError::FormatError("invalid pixel data length")
        }
        if interlaced {
          write_interlaced_pixels(img, decompressed, pixel_count)
        } else {
          for i in 0..<pixel_count {
            img.pix.unsafe_set(i, decompressed[i])
          }
        }
        validate_palette_indices(img, palette.length())
        images.push(img)
        delays.push(delay)
        disposals.push(disposal)
        delay = 0
        disposal = b'\x00'
        transparent_index = -1
      }
      b if b == trailer => done = true
      _ => raise GifError::FormatError("unknown block type")
    }
  }
  if images.is_empty() {
    raise GifError::FormatError("no image data")
  }
  let color_model = if !global_palette.is_empty() {
    @color.AnyModel::PaletteModel(@color.Palette::{ colors: global_palette })
  } else {
    empty_palette_model()
  }
  {
    image: images,
    delay: delays,
    loop_count,
    disposal: disposals,
    background_index: bg_index,
    config: { color_model, width, height },
  }
}

///|
fn read_application_extension(
  r : GifByteReader,
  current_loop_count : Int,
) -> Int raise GifError {
  let app_size = r.read_byte().to_int()
  let ident = r.read_bytes(app_size)
  let data = read_sub_blocks(r)
  if ident.length() == 11 &&
    ident.unsafe_get(0) == b'N' &&
    ident.unsafe_get(1) == b'E' &&
    ident.unsafe_get(2) == b'T' &&
    ident.unsafe_get(3) == b'S' &&
    ident.unsafe_get(4) == b'C' &&
    ident.unsafe_get(5) == b'A' &&
    ident.unsafe_get(6) == b'P' &&
    ident.unsafe_get(7) == b'E' &&
    ident.unsafe_get(8) == b'2' &&
    ident.unsafe_get(9) == b'.' &&
    ident.unsafe_get(10) == b'0' &&
    data.length() >= 3 &&
    data.unsafe_get(0) == b'\x01' {
    data.unsafe_get(1).to_int() | (data.unsafe_get(2).to_int() << 8)
  } else {
    current_loop_count
  }
}

///|
fn apply_transparent_index(
  palette : Array[@color.AnyColor],
  transparent_index : Int,
) -> Array[@color.AnyColor] {
  let out = palette.copy()
  while out.length() <= transparent_index {
    out.push(
      @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }),
    )
  }
  out[transparent_index] = @color.AnyColor::RGBA({
    r: b'\x00',
    g: b'\x00',
    b: b'\x00',
    a: b'\x00',
  })
  out
}

///|
fn write_interlaced_pixels(
  img : @image.ImagePaletted,
  decompressed : Bytes,
  pixel_count : Int,
) -> Unit {
  let width = img.rect.dx()
  let height = img.rect.dy()
  let mut src = 0
  let passes = [(0, 8), (4, 8), (2, 4), (1, 2)]
  for pass in passes {
    let (start_y, step_y) = pass
    let mut y = start_y
    while y < height && src < decompressed.length() && src < pixel_count {
      for x in 0..<width {
        if src >= decompressed.length() || src >= pixel_count {
          return
        }
        img.pix.unsafe_set(y * img.stride + x, decompressed[src])
        src += 1
      }
      y += step_y
    }
  }
}

///|
fn validate_palette_indices(
  img : @image.ImagePaletted,
  palette_len : Int,
) -> Unit raise GifError {
  if palette_len >= 256 {
    return
  }
  for pixel in img.pix {
    if pixel.to_int() >= palette_len {
      raise GifError::FormatError("bad pixel")
    }
  }
}

///|
fn read_color_table(
  r : GifByteReader,
  size : Int,
) -> Array[@color.AnyColor] raise GifError {
  let palette : Array[@color.AnyColor] = Array::new(capacity=size)
  for count in 0..<size {
    ignore(count)
    let cr = r.read_byte()
    let cg = r.read_byte()
    let cb = r.read_byte()
    palette.push(@color.AnyColor::RGBA({ r: cr, g: cg, b: cb, a: b'\xff' }))
  }
  palette
}

///|
fn skip_sub_blocks(r : GifByteReader) -> Unit raise GifError {
  while true {
    let size = r.read_byte()
    if size == b'\x00' {
      break
    }
    r.skip(size.to_int())
  }
}

///|
fn read_sub_blocks(r : GifByteReader) -> Bytes raise GifError {
  let buf = @blit.Buffer::new()
  while true {
    let size = r.read_byte()
    if size == b'\x00' {
      break
    }
    let block = r.read_bytes(size.to_int())
    buf.write_bytes(block)
  }
  buf.to_bytes()
}
