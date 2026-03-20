///|
/// Port of Go's color benchmarks from color_test.go and ycbcr_test.go.
test (b : @bench.T) {
  // BenchmarkYCbCrToRGB
  b.bench(name="ycbcr_to_rgb/0", fn() {
    b.keep(ycbcr_to_rgb(b'\x00', b'\x00', b'\x00'))
  })
  b.bench(name="ycbcr_to_rgb/128", fn() {
    b.keep(ycbcr_to_rgb(b'\x80', b'\x80', b'\x80'))
  })
  b.bench(name="ycbcr_to_rgb/255", fn() {
    b.keep(ycbcr_to_rgb(b'\xff', b'\xff', b'\xff'))
  })
  // BenchmarkRGBToYCbCr
  b.bench(name="rgb_to_ycbcr/0", fn() {
    b.keep(rgb_to_ycbcr(b'\x00', b'\x00', b'\x00'))
  })
  b.bench(name="rgb_to_ycbcr/Cb", fn() {
    b.keep(rgb_to_ycbcr(b'\x00', b'\x00', b'\xff'))
  })
  b.bench(name="rgb_to_ycbcr/Cr", fn() {
    b.keep(rgb_to_ycbcr(b'\xff', b'\x00', b'\x00'))
  })
  // BenchmarkYCbCrToRGBA
  let c0 : YCbCr = { y: b'\x00', cb: b'\x00', cr: b'\x00' }
  let c128 : YCbCr = { y: b'\x80', cb: b'\x80', cr: b'\x80' }
  let c255 : YCbCr = { y: b'\xff', cb: b'\xff', cr: b'\xff' }
  b.bench(name="ycbcr_to_rgba/0", fn() { b.keep(c0.rgba()) })
  b.bench(name="ycbcr_to_rgba/128", fn() { b.keep(c128.rgba()) })
  b.bench(name="ycbcr_to_rgba/255", fn() { b.keep(c255.rgba()) })
  // BenchmarkNYCbCrAToRGBA
  let n0 : NYCbCrA = {
    ycbcr: { y: b'\x00', cb: b'\x00', cr: b'\x00' },
    a: b'\xff',
  }
  let n128 : NYCbCrA = {
    ycbcr: { y: b'\x80', cb: b'\x80', cr: b'\x80' },
    a: b'\xff',
  }
  let n255 : NYCbCrA = {
    ycbcr: { y: b'\xff', cb: b'\xff', cr: b'\xff' },
    a: b'\xff',
  }
  b.bench(name="nycbcra_to_rgba/0", fn() { b.keep(n0.rgba()) })
  b.bench(name="nycbcra_to_rgba/128", fn() { b.keep(n128.rgba()) })
  b.bench(name="nycbcra_to_rgba/255", fn() { b.keep(n255.rgba()) })
}
