///|
/// Port of Go's JPEG benchmarks.
test (b : @bench.T) {
  // DCT benchmarks
  let pixels = FixedArray::make(64, b'\x00')
  let block = FixedArray::make(64, 0)
  let dst = FixedArray::make(64, b'\x00')
  for i in 0..<64 {
    pixels[i] = (i * 7 + 13).to_byte()
  }
  fdct(pixels, block)
  b.bench(name="fdct", fn() { fdct(pixels, block) })
  b.bench(name="idct", fn() { idct(block, dst) })
  // Decode benchmarks
  let baseline = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  b.bench(name="decode_baseline", fn() { b.keep(try? decode(baseline)) })
  // Encode benchmarks
  let r = @image.rect(0, 0, 640, 480)
  let rgba_img = @image.new_image_rgba(r)
  for y in 0..<480 {
    for x in 0..<640 {
      rgba_img.set_rgba(
        x,
        y,
        {
          r: (x % 256).to_byte(),
          g: (y % 256).to_byte(),
          b: ((x + y) % 256).to_byte(),
          a: b'\xff',
        },
      )
    }
  }
  b.bench(
    name="encode_rgba",
    fn() { b.keep(encode(@image.AnyImage::RGBA(rgba_img))) },
  )
}
