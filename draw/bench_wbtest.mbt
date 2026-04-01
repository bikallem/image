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
  let mut y = r.min_y
  while y < r.max_y {
    let mut x = r.min_x
    while x < r.max_x {
      src_rgba.set_rgba(x, y, {
        r: (x * y).to_byte(),
        g: b'\x00',
        b: b'\x00',
        a: b'\xff',
      })
      src_nrgba.set_nrgba(x, y, {
        r: (x * y).to_byte(),
        g: b'\x00',
        b: b'\x00',
        a: b'\x80',
      })
      src_gray.set_gray(x, y, { y: (x * y).to_byte() })
      mask_alpha.set_alpha(x, y, { a: b'\x80' })
      x += 1
    }
    y += 1
  }
  let uniform_blue : @image.ImageUniform = {
    c: @color.RGBA::{ r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' },
    model: @color.RGBAModel::{  },
  }
  // Fill benchmarks
  b.bench(name="fill_over", fn() {
    draw(dst_rgba, r, uniform_blue, { x: 0, y: 0 }, Over)
  })
  b.bench(name="fill_src", fn() {
    draw(dst_rgba, r, uniform_blue, { x: 0, y: 0 }, Src)
  })
  // Copy benchmarks
  b.bench(name="copy_over", fn() {
    draw(dst_rgba, r, src_rgba, { x: 0, y: 0 }, Over)
  })
  b.bench(name="copy_src", fn() {
    draw(dst_rgba, r, src_rgba, { x: 0, y: 0 }, Src)
  })
  // NRGBA benchmarks
  b.bench(name="nrgba_over", fn() {
    draw(dst_rgba, r, src_nrgba, { x: 0, y: 0 }, Over)
  })
  b.bench(name="nrgba_src", fn() {
    draw(dst_rgba, r, src_nrgba, { x: 0, y: 0 }, Src)
  })
  // YCbCr
  b.bench(name="ycbcr", fn() {
    draw(dst_rgba, r, src_ycbcr, { x: 0, y: 0 }, Over)
  })
  // Gray
  b.bench(name="gray", fn() {
    draw(dst_rgba, r, src_gray, { x: 0, y: 0 }, Over)
  })
  // Glyph (uniform src + alpha mask)
  b.bench(name="glyph_over", fn() {
    draw_mask(
      dst_rgba,
      r,
      uniform_blue,
      { x: 0, y: 0 },
      Some(mask_alpha),
      { x: 0, y: 0 },
      Over,
    )
  })
  // Generic paths
  b.bench(name="generic_over", fn() {
    draw(src_rgba64, r, src_rgba64, { x: 0, y: 0 }, Over)
  })
  b.bench(name="generic_src", fn() {
    draw(src_rgba64, r, src_rgba64, { x: 0, y: 0 }, Src)
  })
  // Paletted
  let pal_dst = @image.new_image_paletted(r, {
    colors: Array::makei(256, fn(i) {
      @color.RGBA::{
        r: i.to_byte(),
        g: i.to_byte(),
        b: i.to_byte(),
        a: b'\xff',
      }
    }),
  })
  b.bench(name="paletted_fill", fn() {
    draw(pal_dst, r, uniform_blue, { x: 0, y: 0 }, Src)
  })
  b.bench(name="paletted_rgba", fn() {
    draw(pal_dst, r, src_rgba, { x: 0, y: 0 }, Src)
  })
}
