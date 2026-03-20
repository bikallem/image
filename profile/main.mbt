///|
fn main {
  let r = @image.rect(0, 0, 256, 256)
  let dst_rgba = @image.new_image_rgba(r)
  let uniform = @image.AnyImage::Uniform(@image.ImageUniform::{
    c: @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' }),
  })
  for _ in 0..<100 {
    @draw.draw(@image.AnyImage::RGBA(dst_rgba), r, uniform, { x: 0, y: 0 }, @draw.Src)
  }
  let src_rgba = @image.new_image_rgba(r)
  for _ in 0..<100 {
    @draw.draw(@image.AnyImage::RGBA(dst_rgba), r, @image.AnyImage::RGBA(src_rgba), { x: 0, y: 0 }, @draw.Src)
  }
  for _ in 0..<50 {
    @draw.draw(@image.AnyImage::RGBA(dst_rgba), r, @image.AnyImage::RGBA(src_rgba), { x: 0, y: 0 }, @draw.Over)
  }
  let png_data = @fs.read_file_to_bytes("png/testdata/benchRGB.png") catch { _ => Bytes::new(0) }
  if png_data.length() > 0 {
    for _ in 0..<20 { ignore(@png.decode(png_data)) catch { _ => () } }
  }
  let rgba_img = @image.new_image_rgba(r)
  for y in 0..<256 { for x in 0..<256 {
    rgba_img.set_rgba(x, y, { r: x.to_byte(), g: y.to_byte(), b: b'\x00', a: b'\xff' })
  }}
  for _ in 0..<5 { ignore(@png.encode(@image.AnyImage::RGBA(rgba_img))) }
  let jpeg_data = @fs.read_file_to_bytes("testdata/video-001.jpeg") catch { _ => Bytes::new(0) }
  if jpeg_data.length() > 0 {
    for _ in 0..<20 { ignore(@jpeg.decode(jpeg_data)) catch { _ => () } }
  }
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif") catch { _ => Bytes::new(0) }
  if gif_data.length() > 0 {
    for _ in 0..<50 { ignore(@gif.decode(gif_data)) catch { _ => () } }
  }
}
