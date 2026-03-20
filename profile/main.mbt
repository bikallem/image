fn main {
  let r = @image.rect(0, 0, 256, 256)

  // 1. Draw fill_src (Uniform -> RGBA)
  let dst_rgba = @image.new_image_rgba(r)
  let uniform = @image.AnyImage::Uniform(
    @image.ImageUniform::{
      c: @color.AnyColor::RGBA(
        { r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' },
      ),
    },
  )
  for _ in 0..<100 {
    @draw.draw(
      @image.AnyImage::RGBA(dst_rgba), r, uniform, { x: 0, y: 0 }, @draw.Src,
    )
  }

  // 2. Draw copy_src (RGBA -> RGBA)
  let src_rgba = @image.new_image_rgba(r)
  for _ in 0..<100 {
    @draw.draw(
      @image.AnyImage::RGBA(dst_rgba),
      r,
      @image.AnyImage::RGBA(src_rgba),
      { x: 0, y: 0 },
      @draw.Src,
    )
  }

  // 3. Draw copy_over (RGBA -> RGBA)
  for _ in 0..<50 {
    @draw.draw(
      @image.AnyImage::RGBA(dst_rgba),
      r,
      @image.AnyImage::RGBA(src_rgba),
      { x: 0, y: 0 },
      @draw.Over,
    )
  }

  // 4. PNG decode
  let png_data = try {
    @fs.read_file_to_bytes("png/testdata/benchRGB.png")
  } catch {
    _ => Bytes::new(0)
  }
  if png_data.length() > 0 {
    for _ in 0..<20 {
      try { ignore(@png.decode(png_data)) } catch { _ => () }
    }
  }

  // 5. PNG encode
  let rgba_img = @image.new_image_rgba(r)
  for y in 0..<256 {
    for x in 0..<256 {
      rgba_img.set_rgba(
        x, y, { r: x.to_byte(), g: y.to_byte(), b: b'\x00', a: b'\xff' },
      )
    }
  }
  for _ in 0..<5 {
    ignore(@png.encode(@image.AnyImage::RGBA(rgba_img)))
  }

  // 6. JPEG decode
  let jpeg_data = try {
    @fs.read_file_to_bytes("testdata/video-001.jpeg")
  } catch {
    _ => Bytes::new(0)
  }
  if jpeg_data.length() > 0 {
    for _ in 0..<20 {
      try { ignore(@jpeg.decode(jpeg_data)) } catch { _ => () }
    }
  }

  // 7. GIF decode
  let gif_data = try {
    @fs.read_file_to_bytes("testdata/video-001.gif")
  } catch {
    _ => Bytes::new(0)
  }
  if gif_data.length() > 0 {
    for _ in 0..<50 {
      try { ignore(@gif.decode(gif_data)) } catch { _ => () }
    }
  }
}
