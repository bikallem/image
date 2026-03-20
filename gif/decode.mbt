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
/// Decodes the configuration of a GIF image.
pub fn decode_config(data : Bytes) -> @image.Config raise Error {
  let r = GifByteReader::new(data)
  // Read header
  let sig = r.read_bytes(6)
  let sig_str = bytes_to_string(sig)
  if sig_str != gif87a && sig_str != gif89a {
    raise GifError::FormatError("not a GIF file")
  }
  let width = r.read_uint16_le().reinterpret_as_int()
  let height = r.read_uint16_le().reinterpret_as_int()
  { color_model: @color.AnyModel::RGBAModel, width, height }
}

///|
fn bytes_to_string(b : Bytes) -> String {
  let buf = StringBuilder::new()
  for i in 0..<b.length() {
    buf.write_char(b.unsafe_get(i).to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Decodes all frames of a GIF image.
pub fn decode_all(data : Bytes) -> GIF raise Error {
  let r = GifByteReader::new(data)
  // Read header
  let sig = r.read_bytes(6)
  let sig_str = bytes_to_string(sig)
  if sig_str != gif87a && sig_str != gif89a {
    raise GifError::FormatError("not a GIF file")
  }
  // Logical screen descriptor
  let width = r.read_uint16_le().reinterpret_as_int()
  let height = r.read_uint16_le().reinterpret_as_int()
  let packed = r.read_byte()
  let bg_index = r.read_byte()
  let _aspect_ratio = r.read_byte()
  // Global color table
  let has_gct = (packed.to_int() & 0x80) != 0
  let gct_size = 1 << ((packed.to_int() & 0x07) + 1)
  let global_palette = if has_gct { read_color_table(r, gct_size) } else { [] }
  let images : Array[@image.ImagePaletted] = []
  let delays : Array[Int] = []
  let disposals : Array[Byte] = []
  let mut delay = 0
  let mut disposal : Byte = b'\x00'
  let mut transparent_index : Int = -1
  let mut done = false
  while !done && r.remaining() > 0 {
    let block_type = r.read_byte()
    match block_type {
      b if b == ext_introducer => {
        let label = r.read_byte()
        match label {
          l if l == ext_graphic_control => {
            let _block_size = r.read_byte()
            let gce_packed = r.read_byte()
            delay = r.read_uint16_le().reinterpret_as_int()
            let ti = r.read_byte()
            let _terminator = r.read_byte()
            disposal = ((gce_packed.to_int() >> 2) & 0x07).to_byte()
            if (gce_packed.to_int() & 0x01) != 0 {
              transparent_index = ti.to_int()
            } else {
              transparent_index = -1
            }
          }
          l if l == ext_application =>
            // Skip application extension
            skip_sub_blocks(r)
          _ =>
            // Skip other extensions
            skip_sub_blocks(r)
        }
      }
      b if b == image_descriptor => {
        let _left = r.read_uint16_le().reinterpret_as_int()
        let _top = r.read_uint16_le().reinterpret_as_int()
        let img_width = r.read_uint16_le().reinterpret_as_int()
        let img_height = r.read_uint16_le().reinterpret_as_int()
        let img_packed = r.read_byte()
        let has_lct = (img_packed.to_int() & 0x80) != 0
        let lct_size = 1 << ((img_packed.to_int() & 0x07) + 1)
        let palette = if has_lct {
          read_color_table(r, lct_size)
        } else {
          global_palette.copy()
        }
        // Apply transparency
        if transparent_index >= 0 && transparent_index < palette.length() {
          palette[transparent_index] = @color.AnyColor::RGBA({
            r: b'\x00',
            g: b'\x00',
            b: b'\x00',
            a: b'\x00',
          })
        }
        // Read LZW minimum code size
        let lzw_min = r.read_byte()
        // Read sub-blocks into contiguous buffer
        let lzw_data = read_sub_blocks(r)
        // Decompress LZW
        let decompressed = @lzw.decompress(
            lzw_data,
            @lzw.BitOrder::LSB,
            lzw_min.to_int(),
          )
          |> or_gif_error()
        // Build paletted image
        let rect : @image.Rectangle = {
          min_x: 0,
          min_y: 0,
          max_x: img_width,
          max_y: img_height,
        }
        let pal = @color.Palette::{ colors: palette }
        let img = @image.new_image_paletted(rect, pal)
        let pixel_count = img_width * img_height
        let copy_count = if decompressed.length() < pixel_count {
          decompressed.length()
        } else {
          pixel_count
        }
        for i in 0..<copy_count {
          img.pix.unsafe_set(i, decompressed[i])
        }
        images.push(img)
        delays.push(delay)
        disposals.push(disposal)
        delay = 0
        disposal = b'\x00'
        transparent_index = -1
      }
      b if b == trailer => done = true
      _ => ()
    }
  }
  {
    image: images,
    delay: delays,
    loop_count: 0,
    disposal: disposals,
    background_index: bg_index,
    config: { color_model: @color.AnyModel::RGBAModel, width, height },
  }
}

///|
fn[T] or_gif_error(result : T) -> T {
  result
}

///|
fn read_color_table(
  r : GifByteReader,
  size : Int,
) -> Array[@color.AnyColor] raise GifError {
  let palette : Array[@color.AnyColor] = Array::new(capacity=size)
  for _i in 0..<size {
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
  let buf = @buffer.new()
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
