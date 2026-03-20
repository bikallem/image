///|
/// Port of Go's GIF benchmarks.
test (b : @bench.T) {
  // Decode benchmark
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif")
  b.bench(name="decode", fn() { b.keep(try? decode(gif_data)) })
  // Encode benchmark with paletted image
  let pal : @color.Palette = {
    colors: Array::makei(256, fn(i) {
      @color.AnyColor::RGBA(
        {
          r: i.to_byte(),
          g: (255 - i).to_byte(),
          b: b'\x80',
          a: b'\xff',
        },
      )
    }),
  }
  let m = @image.new_image_paletted(@image.rect(0, 0, 256, 256), pal)
  for y in 0..<256 {
    for x in 0..<256 {
      m.set_color_index(x, y, ((x * 17 + y * 13) % 256).to_byte())
    }
  }
  b.bench(name="encode_paletted", fn() { b.keep(try? encode(m)) })
}
