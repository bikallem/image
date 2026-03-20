///|
/// Port of Go's draw benchmarks from bench_test.go.
test (b : @bench.T) {
  let r = @image.rect(0, 0, 256, 256)
  let dst_rgba = @image.new_image_rgba(r)
  let src_rgba = @image.new_image_rgba(r)
  let src_nrgba = @image.new_image_nrgba(r)
  let src_ycbcr = @image.new_image_ycbcr(r, @image.Ratio444)
  let src_gray = @image.new_image_gray(r)
  let mask_alpha = @image.new_image_alpha(r)
  let src_rgba64 = @image.new_image_rgba64(r)
  // Initialize pixels with non-zero values
  let mut y = r.min.y
  while y < r.max.y {
    let mut x = r.min.x
    while x < r.max.x {
      src_rgba.set_rgba(
        x,
        y,
        { r: (x * y).to_byte(), g: b'\x00', b: b'\x00', a: b'\xff' },
      )
      src_nrgba.set_nrgba(
        x,
        y,
        { r: (x * y).to_byte(), g: b'\x00', b: b'\x00', a: b'\x80' },
      )
      src_gray.set_gray(x, y, { y: (x * y).to_byte() })
      mask_alpha.set_alpha(x, y, { a: b'\x80' })
      x += 1
    }
    y += 1
  }
  let uniform_blue = @image.AnyImage::Uniform(
    @image.ImageUniform::{
      c: @color.AnyColor::RGBA({
        r: b'\x00',
        g: b'\x00',
        b: b'\xff',
        a: b'\xff',
      }),
    },
  )
  // Fill benchmarks
  b.bench(
    name="fill_over",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        uniform_blue,
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  b.bench(
    name="fill_src",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        uniform_blue,
        { x: 0, y: 0 },
        Src,
      )
    },
  )
  // Copy benchmarks
  b.bench(
    name="copy_over",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        @image.AnyImage::RGBA(src_rgba),
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  b.bench(
    name="copy_src",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        @image.AnyImage::RGBA(src_rgba),
        { x: 0, y: 0 },
        Src,
      )
    },
  )
  // NRGBA benchmarks
  b.bench(
    name="nrgba_over",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        @image.AnyImage::NRGBA(src_nrgba),
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  b.bench(
    name="nrgba_src",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        @image.AnyImage::NRGBA(src_nrgba),
        { x: 0, y: 0 },
        Src,
      )
    },
  )
  // YCbCr
  b.bench(
    name="ycbcr",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        @image.AnyImage::YCbCr(src_ycbcr),
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  // Gray
  b.bench(
    name="gray",
    fn() {
      draw(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        @image.AnyImage::Gray(src_gray),
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  // Glyph (uniform src + alpha mask)
  b.bench(
    name="glyph_over",
    fn() {
      draw_mask(
        @image.AnyImage::RGBA(dst_rgba),
        r,
        uniform_blue,
        { x: 0, y: 0 },
        Some(@image.AnyImage::Alpha(mask_alpha)),
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  // Generic paths
  b.bench(
    name="generic_over",
    fn() {
      draw(
        @image.AnyImage::RGBA64(src_rgba64),
        r,
        @image.AnyImage::RGBA64(src_rgba64),
        { x: 0, y: 0 },
        Over,
      )
    },
  )
  b.bench(
    name="generic_src",
    fn() {
      draw(
        @image.AnyImage::RGBA64(src_rgba64),
        r,
        @image.AnyImage::RGBA64(src_rgba64),
        { x: 0, y: 0 },
        Src,
      )
    },
  )
  // Paletted
  let pal_dst = @image.new_image_paletted(
    r,
    {
      colors: Array::makei(256, fn(i) {
        @color.AnyColor::RGBA(
          { r: i.to_byte(), g: i.to_byte(), b: i.to_byte(), a: b'\xff' },
        )
      }),
    },
  )
  b.bench(
    name="paletted_fill",
    fn() {
      draw(
        @image.AnyImage::Paletted(pal_dst),
        r,
        uniform_blue,
        { x: 0, y: 0 },
        Src,
      )
    },
  )
  b.bench(
    name="paletted_rgba",
    fn() {
      draw(
        @image.AnyImage::Paletted(pal_dst),
        r,
        @image.AnyImage::RGBA(src_rgba),
        { x: 0, y: 0 },
        Src,
      )
    },
  )
}
