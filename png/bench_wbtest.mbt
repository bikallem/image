///|
/// Port of Go's PNG benchmarks from reader_test.go and writer_test.go.
test (b : @bench.T) {
  // Paeth benchmark
  b.bench(name="paeth", fn() {
    for a in 0..<256 {
      for b_val in 0..<256 {
        b.keep(paeth(a, b_val, 128))
      }
    }
  })
  // Decode benchmarks - load testdata images
  let gray_data = @fs.read_file_to_bytes("png/testdata/benchGray.png")
  b.bench(name="decode_gray", fn() { b.keep(try? decode(gray_data)) })
  let nrgba_grad = @fs.read_file_to_bytes(
    "png/testdata/benchNRGBA-gradient.png",
  )
  b.bench(name="decode_nrgba_gradient", fn() { b.keep(try? decode(nrgba_grad)) })
  let nrgba_opaque = @fs.read_file_to_bytes(
    "png/testdata/benchNRGBA-opaque.png",
  )
  b.bench(name="decode_nrgba_opaque", fn() { b.keep(try? decode(nrgba_opaque)) })
  let paletted_data = @fs.read_file_to_bytes("png/testdata/benchPaletted.png")
  b.bench(name="decode_paletted", fn() { b.keep(try? decode(paletted_data)) })
  let rgb_data = @fs.read_file_to_bytes("png/testdata/benchRGB.png")
  b.bench(name="decode_rgb", fn() { b.keep(try? decode(rgb_data)) })
  let interlaced_data = @fs.read_file_to_bytes(
    "png/testdata/benchRGB-interlace.png",
  )
  b.bench(name="decode_interlaced", fn() {
    b.keep(try? decode(interlaced_data))
  })
  // Encode benchmarks - create synthetic images
  let r = @image.rect(0, 0, 640, 480)
  let gray_img = @image.new_image_gray(r)
  for y in 0..<480 {
    for x in 0..<640 {
      gray_img.set_gray(x, y, { y: (x + y).to_byte() })
    }
  }
  b.bench(name="encode_gray", fn() { b.keep(try? encode(gray_img)) })
  let rgba_img = @image.new_image_rgba(r)
  for y in 0..<480 {
    for x in 0..<640 {
      rgba_img.set_rgba(x, y, {
        r: x.to_byte(),
        g: y.to_byte(),
        b: (x + y).to_byte(),
        a: b'\xff',
      })
    }
  }
  b.bench(name="encode_rgb_opaque", fn() { b.keep(try? encode(rgba_img)) })
  let nrgba_img = @image.new_image_nrgba(r)
  for y in 0..<480 {
    for x in 0..<640 {
      nrgba_img.set_nrgba(x, y, {
        r: x.to_byte(),
        g: y.to_byte(),
        b: (x + y).to_byte(),
        a: if (x + y) % 10 == 0 {
          b'\x80'
        } else {
          b'\xff'
        },
      })
    }
  }
  b.bench(name="encode_nrgba", fn() { b.keep(try? encode(nrgba_img)) })
  let pal_img = @image.new_image_paletted(r, {
    colors: Array::makei(256, fn(i) {
      @color.RGBA::{
        r: i.to_byte(),
        g: (255 - i).to_byte(),
        b: b'\x80',
        a: b'\xff',
      }
    }),
  })
  for y in 0..<480 {
    for x in 0..<640 {
      pal_img.set_color_index(x, y, ((x + y) % 256).to_byte())
    }
  }
  b.bench(name="encode_paletted", fn() { b.keep(try? encode(pal_img)) })
}
