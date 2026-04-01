///|
/// Quantize reduces an image to at most n_colors using Go-like defaults.
fn quantize_image(
  img : &@image.Image,
  options : Options,
  max_colors : Int,
) -> @image.ImagePaletted {
  let bounds = img.bounds()
  let n_colors = normalize_num_colors(max_colors)
  // If the image already has a palette with few enough colors, reuse it.
  let pal = match img.color_model().palette() {
    Some(p) if p.colors.length() <= n_colors => p
    _ =>
      match options.quantizer {
        Some(quantizer) => quantizer(img, n_colors)
        None => @color.Palette::{ colors: plan9_palette(n_colors) }
      }
  }
  let result = @image.new_image_paletted(bounds, pal)
  match options.drawer {
    Some(drawer) => drawer(result, bounds, img, bounds.min())
    None => @draw.floyd_steinberg_draw(result, bounds, img, bounds.min())
  }
  result
}

///|
fn plan9_palette(n_colors : Int) -> Array[&@color.Color] {
  let n = normalize_num_colors(n_colors)
  Array::makei(n, fn(i) { @palette.plan9[i] })
}
