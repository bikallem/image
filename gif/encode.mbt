///|
/// Encodes any image as a GIF by auto-quantizing to n_colors.
/// Default: 256 colors using median-cut quantization.
pub fn encode_image(
  img : @image.AnyImage,
  n_colors? : Int = 256,
) -> Bytes raise Error {
  let paletted = match img {
    @image.AnyImage::Paletted(p) => p
    _ => quantize_image(img, n_colors)
  }
  encode(paletted)
}

///|
/// Encodes a single paletted image as a GIF.
pub fn encode(img : @image.ImagePaletted) -> Bytes raise Error {
  let gif : GIF = {
    image: [img],
    delay: [0],
    loop_count: 0,
    disposal: [b'\x00'],
    background_index: b'\x00',
    config: {
      color_model: @color.AnyModel::PaletteModel(img.palette),
      width: img.rect.dx(),
      height: img.rect.dy(),
    },
  }
  encode_all(gif)
}

///|
/// Encodes multiple frames as an animated GIF.
pub fn encode_all(gif : GIF) -> Bytes raise Error {
  let buf = @blit.Buffer::new()
  let width = gif.config.width
  let height = gif.config.height
  if width < 0 || width >= 1 << 16 || height < 0 || height >= 1 << 16 {
    raise GifError::FormatError("image is too large to encode")
  }
  write_string(buf, gif89a)
  write_uint16_le(buf, width.reinterpret_as_uint())
  write_uint16_le(buf, height.reinterpret_as_uint())

  let global_palette = gif_global_palette(gif)
  let has_global = !global_palette.is_empty()
  if has_global {
    let ct_size = color_table_size(global_palette.length())
    let packed : Byte = (0x80 | ((ct_size - 1) << 4) | (ct_size - 1)).to_byte()
    buf.write_byte(packed)
    buf.write_byte(gif.background_index)
    buf.write_byte(b'\x00')
    write_color_table(buf, global_palette, 1 << ct_size)
  } else {
    buf.write_byte(b'\x00')
    buf.write_byte(b'\x00')
    buf.write_byte(b'\x00')
  }

  if gif.image.length() > 1 && gif.loop_count >= 0 {
    buf.write_byte(ext_introducer)
    buf.write_byte(ext_application)
    buf.write_byte(b'\x0b')
    write_string(buf, "NETSCAPE2.0")
    buf.write_byte(b'\x03')
    buf.write_byte(b'\x01')
    write_uint16_le(buf, gif.loop_count.reinterpret_as_uint())
    buf.write_byte(b'\x00')
  }

  for i, img in gif.image {
    let delay = if i < gif.delay.length() { gif.delay[i] } else { 0 }
    let disposal = if i < gif.disposal.length() {
      gif.disposal.unsafe_get(i)
    } else {
      b'\x00'
    }
    let transparent_index = find_transparent_index(img.palette.colors)
    if delay > 0 || disposal != b'\x00' || transparent_index >= 0 {
      buf.write_byte(ext_introducer)
      buf.write_byte(ext_graphic_control)
      buf.write_byte(b'\x04')
      let flags = if transparent_index >= 0 {
        (0x01 | ((disposal.to_int() & 0x07) << 2)).to_byte()
      } else {
        ((disposal.to_int() & 0x07) << 2).to_byte()
      }
      buf.write_byte(flags)
      write_uint16_le(buf, delay.reinterpret_as_uint())
      buf.write_byte(
        if transparent_index >= 0 {
          transparent_index.to_byte()
        } else {
          b'\x00'
        },
      )
      buf.write_byte(b'\x00')
    }

    let rect = img.rect
    if rect.min_x < 0 ||
      rect.min_y < 0 ||
      rect.max_x >= 1 << 16 ||
      rect.max_y >= 1 << 16 {
      raise GifError::FormatError("image block is too large to encode")
    }
    if rect.max_x > width || rect.max_y > height {
      raise GifError::FormatError("image block is out of bounds")
    }
    buf.write_byte(image_descriptor)
    write_uint16_le(buf, rect.min_x.reinterpret_as_uint())
    write_uint16_le(buf, rect.min_y.reinterpret_as_uint())
    write_uint16_le(buf, rect.dx().reinterpret_as_uint())
    write_uint16_le(buf, rect.dy().reinterpret_as_uint())

    let use_local = !has_global ||
      !palette_equals(global_palette, img.palette.colors, transparent_index)
    let ct_size = color_table_size(img.palette.colors.length())
    if use_local {
      buf.write_byte((0x80 | (ct_size - 1)).to_byte())
      write_color_table(buf, img.palette.colors, 1 << ct_size)
    } else {
      buf.write_byte(b'\x00')
    }

    let mut lit_width = ct_size
    if lit_width < 2 {
      lit_width = 2
    }
    buf.write_byte(lit_width.to_byte())

    let pixel_buf = @blit.Buffer::new(size_hint=rect.dx() * rect.dy())
    for y = rect.min_y; y < rect.max_y; y = y + 1 {
      for x = rect.min_x; x < rect.max_x; x = x + 1 {
        pixel_buf.write_byte(img.color_index_at(x, y))
      }
    }
    let compressed = @lzw.compress(
      pixel_buf.to_bytes(),
      @lzw.BitOrder::LSB,
      lit_width,
    )
    write_sub_blocks(buf, compressed)
  }

  buf.write_byte(trailer)
  buf.to_bytes()
}

///|
fn gif_global_palette(gif : GIF) -> Array[@color.AnyColor] {
  match gif.config.color_model {
    @color.AnyModel::PaletteModel(p) => p.colors
    _ => []
  }
}

///|
fn find_transparent_index(palette : Array[@color.AnyColor]) -> Int {
  for i, c in palette {
    let (_, _, _, a) = c.rgba()
    if a == 0U {
      return i
    }
  }
  -1
}

///|
fn palette_equals(
  left : Array[@color.AnyColor],
  right : Array[@color.AnyColor],
  transparent_index : Int,
) -> Bool {
  if left.length() < right.length() {
    return false
  }
  for i in 0..<right.length() {
    if i == transparent_index {
      continue
    }
    let (lr, lg, lb, la) = left.unsafe_get(i).rgba()
    let (rr, rg, rb, ra) = right.unsafe_get(i).rgba()
    if lr != rr || lg != rg || lb != rb || la != ra {
      return false
    }
  }
  true
}

///|
fn color_table_size(n : Int) -> Int {
  let mut size = 1
  while 1 << size < n {
    size += 1
  }
  if size < 1 {
    1
  } else if size > 8 {
    8
  } else {
    size
  }
}

///|
fn write_color_table(
  buf : @blit.Buffer,
  palette : Array[@color.AnyColor],
  size : Int,
) -> Unit {
  for i in 0..<size {
    if i < palette.length() {
      let (r, g, b, _) = palette.unsafe_get(i).rgba()
      buf.write_byte((r >> 8).to_byte())
      buf.write_byte((g >> 8).to_byte())
      buf.write_byte((b >> 8).to_byte())
    } else {
      buf.write_byte(b'\x00')
      buf.write_byte(b'\x00')
      buf.write_byte(b'\x00')
    }
  }
}

///|
fn write_string(buf : @blit.Buffer, s : String) -> Unit {
  for c in s {
    buf.write_byte(c.to_int().to_byte())
  }
}

///|
fn write_uint16_le(buf : @blit.Buffer, v : UInt) -> Unit {
  buf.write_byte(v.to_byte())
  buf.write_byte((v >> 8).to_byte())
}

///|
fn write_sub_blocks(buf : @blit.Buffer, data : Bytes) -> Unit {
  let mut pos = 0
  while pos < data.length() {
    let remaining = data.length() - pos
    let block_size = if remaining > 255 { 255 } else { remaining }
    buf.write_byte(block_size.to_byte())
    for i in 0..<block_size {
      buf.write_byte(data.unsafe_get(pos + i))
    }
    pos = pos + block_size
  }
  buf.write_byte(b'\x00')
}
