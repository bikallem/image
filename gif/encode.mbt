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
      color_model: @color.AnyModel::RGBAModel,
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
  // Header
  write_string(buf, gif89a)
  // Logical Screen Descriptor
  write_uint16_le(buf, width.reinterpret_as_uint())
  write_uint16_le(buf, height.reinterpret_as_uint())
  // Use first frame's palette as global color table
  let first_pal = if gif.image.length() > 0 {
    gif.image.unsafe_get(0).palette.colors
  } else {
    []
  }
  let ct_size = color_table_size(first_pal.length())
  let packed : Byte = (0x80 | ((ct_size - 1) << 4) | (ct_size - 1)).to_byte()
  buf.write_byte(packed)
  buf.write_byte(gif.background_index) // bg color index
  buf.write_byte(b'\x00') // pixel aspect ratio
  // Global Color Table
  write_color_table(buf, first_pal, 1 << ct_size)
  // Frames
  for i, img in gif.image {
    // Graphic Control Extension
    if i < gif.delay.length() || i < gif.disposal.length() {
      buf.write_byte(ext_introducer)
      buf.write_byte(ext_graphic_control)
      buf.write_byte(b'\x04') // block size
      let disp = if i < gif.disposal.length() {
        gif.disposal.unsafe_get(i)
      } else {
        b'\x00'
      }
      buf.write_byte(((disp.to_int() & 0x07) << 2).to_byte())
      let d = if i < gif.delay.length() { gif.delay[i] } else { 0 }
      write_uint16_le(buf, d.reinterpret_as_uint())
      buf.write_byte(b'\x00') // transparent color index
      buf.write_byte(b'\x00') // terminator
    }
    // Image Descriptor
    buf.write_byte(image_descriptor)
    write_uint16_le(buf, 0U) // left
    write_uint16_le(buf, 0U) // top
    write_uint16_le(buf, img.rect.dx().reinterpret_as_uint())
    write_uint16_le(buf, img.rect.dy().reinterpret_as_uint())
    buf.write_byte(b'\x00') // packed (no local color table)
    // LZW data
    let lit_width = ct_size
    let lit_width = if lit_width < 2 { 2 } else { lit_width }
    buf.write_byte(lit_width.to_byte()) // LZW minimum code size
    // Get pixel data
    let pixel_count = img.rect.dx() * img.rect.dy()
    let pixel_buf = @blit.Buffer::new(size_hint=pixel_count)
    for j in 0..<pixel_count {
      pixel_buf.write_byte(img.pix.unsafe_get(img.pix_offset + j))
    }
    let pixels = pixel_buf.to_bytes()
    // Compress with LZW
    let compressed = @lzw.compress(pixels, @lzw.BitOrder::LSB, lit_width)
    // Write as sub-blocks
    write_sub_blocks(buf, compressed)
  }
  // Trailer
  buf.write_byte(trailer)
  buf.to_bytes()
}

///|
fn color_table_size(n : Int) -> Int {
  let mut size = 1
  while 1 << size < n {
    size += 1
  }
  if size < 1 { 1 } else if size > 8 { 8 } else { size }
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
  buf.write_byte(b'\x00') // block terminator
}
