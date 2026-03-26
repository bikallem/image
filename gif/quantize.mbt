///|
/// Quantize reduces an image to at most n_colors using Go-like defaults.
fn quantize_image(
  img : @image.AnyImage,
  n_colors : Int,
) -> @image.ImagePaletted {
  let bounds = img.bounds()
  let pal = @color.Palette::{
    colors: plan9_palette(normalize_num_colors(n_colors)),
  }
  let result = @image.new_image_paletted(bounds, pal)
  @draw.floyd_steinberg_draw(result, bounds, img, bounds.min())
  result
}

///|
fn plan9_palette(n_colors : Int) -> Array[@color.AnyColor] {
  let n = normalize_num_colors(n_colors)
  Array::makei(n, fn(i) { @palette.plan9[i] })
}
