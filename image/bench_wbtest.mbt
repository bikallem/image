///|
/// Port of Go's image benchmarks from image_test.go.
test (b : @bench.T) {
  // BenchmarkAt / BenchmarkSet for each image type
  let r = rect(0, 0, 10, 10)
  // RGBA
  let m_rgba = new_image_rgba(r)
  b.bench(name="at/rgba", fn() { b.keep(m_rgba.rgba_at(4, 5)) })
  let c_rgba : @color.RGBA = { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\x13' }
  b.bench(name="set/rgba", fn() { m_rgba.set_rgba(4, 5, c_rgba) })
  // RGBA64
  let m_rgba64 = new_image_rgba64(r)
  b.bench(name="at/rgba64", fn() { b.keep(m_rgba64.rgba64_at(4, 5)) })
  let c_rgba64 : @color.RGBA64 = { r: 0xffff, g: 0xffff, b: 0xffff, a: 0x1357 }
  b.bench(name="set/rgba64", fn() { m_rgba64.set_rgba64(4, 5, c_rgba64) })
  // NRGBA
  let m_nrgba = new_image_nrgba(r)
  b.bench(name="at/nrgba", fn() { b.keep(m_nrgba.nrgba_at(4, 5)) })
  let c_nrgba : @color.NRGBA = {
    r: b'\xff',
    g: b'\xff',
    b: b'\xff',
    a: b'\x13',
  }
  b.bench(name="set/nrgba", fn() { m_nrgba.set_nrgba(4, 5, c_nrgba) })
  // NRGBA64
  let m_nrgba64 = new_image_nrgba64(r)
  b.bench(name="at/nrgba64", fn() { b.keep(m_nrgba64.nrgba64_at(4, 5)) })
  let c_nrgba64 : @color.NRGBA64 = {
    r: 0xffff,
    g: 0xffff,
    b: 0xffff,
    a: 0x1357,
  }
  b.bench(name="set/nrgba64", fn() { m_nrgba64.set_nrgba64(4, 5, c_nrgba64) })
  // Alpha
  let m_alpha = new_image_alpha(r)
  b.bench(name="at/alpha", fn() { b.keep(m_alpha.alpha_at(4, 5)) })
  let c_alpha : @color.Alpha = { a: b'\x13' }
  b.bench(name="set/alpha", fn() { m_alpha.set_alpha(4, 5, c_alpha) })
  // Alpha16
  let m_alpha16 = new_image_alpha16(r)
  b.bench(name="at/alpha16", fn() { b.keep(m_alpha16.alpha16_at(4, 5)) })
  let c_alpha16 : @color.Alpha16 = { a: 0x13 }
  b.bench(name="set/alpha16", fn() { m_alpha16.set_alpha16(4, 5, c_alpha16) })
  // Gray
  let m_gray = new_image_gray(r)
  b.bench(name="at/gray", fn() { b.keep(m_gray.gray_at(4, 5)) })
  let c_gray : @color.Gray = { y: b'\x13' }
  b.bench(name="set/gray", fn() { m_gray.set_gray(4, 5, c_gray) })
  // Gray16
  let m_gray16 = new_image_gray16(r)
  b.bench(name="at/gray16", fn() { b.keep(m_gray16.gray16_at(4, 5)) })
  let c_gray16 : @color.Gray16 = { y: 0x13 }
  b.bench(name="set/gray16", fn() { m_gray16.set_gray16(4, 5, c_gray16) })
}
