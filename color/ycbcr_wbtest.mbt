///|
fn byte_delta(x : Byte, y : Byte) -> Int {
  let xi = x.to_int()
  let yi = y.to_int()
  if xi >= yi {
    xi - yi
  } else {
    yi - xi
  }
}

///|
fn color_eq(c0 : AnyColor, c1 : AnyColor) -> Bool {
  let (r0, g0, b0, a0) = c0.rgba()
  let (r1, g1, b1, a1) = c1.rgba()
  r0 == r1 && g0 == g1 && b0 == b1 && a0 == a1
}

///|
/// Port of Go's TestYCbCrRoundtrip.
/// RGB cube (steps 7,5,3) -> YCbCr -> RGB, delta <= 2.
test "ycbcr_roundtrip" {
  let mut r = 0
  while r < 256 {
    let mut g = 0
    while g < 256 {
      let mut b = 0
      while b < 256 {
        let r0 = r.to_byte()
        let g0 = g.to_byte()
        let b0 = b.to_byte()
        let (y, cb, cr) = rgb_to_ycbcr(r0, g0, b0)
        let (r1, g1, b1) = ycbcr_to_rgb(y, cb, cr)
        assert_true(byte_delta(r0, r1) <= 2)
        assert_true(byte_delta(g0, g1) <= 2)
        assert_true(byte_delta(b0, b1) <= 2)
        b += 3
      }
      g += 5
    }
    r += 7
  }
}

///|
/// Port of Go's TestYCbCrToRGBConsistency.
/// YCbCr.rgba() >> 8 == ycbcr_to_rgb() for sampled values.
test "ycbcr_to_rgb_consistency" {
  let mut y = 0
  while y < 256 {
    let mut cb = 0
    while cb < 256 {
      let mut cr = 0
      while cr < 256 {
        let x : YCbCr = { y: y.to_byte(), cb: cb.to_byte(), cr: cr.to_byte() }
        let (r0, g0, b0, _) = x.rgba()
        let r1 = (r0 >> 8).to_byte()
        let g1 = (g0 >> 8).to_byte()
        let b1 = (b0 >> 8).to_byte()
        let (r2, g2, b2) = ycbcr_to_rgb(y.to_byte(), cb.to_byte(), cr.to_byte())
        assert_eq(r1, r2)
        assert_eq(g1, g2)
        assert_eq(b1, b2)
        cr += 3
      }
      cb += 5
    }
    y += 7
  }
}

///|
/// Port of Go's TestYCbCrGray.
/// YCbCr{i, 0x80, 0x80}.rgba() == Gray{i}.rgba() for all i.
test "ycbcr_gray" {
  for i in 0..<256 {
    let c0 : AnyColor = AnyColor::YCbCr({
      y: i.to_byte(),
      cb: b'\x80',
      cr: b'\x80',
    })
    let c1 : AnyColor = AnyColor::Gray({ y: i.to_byte() })
    assert_true(color_eq(c0, c1))
  }
}

///|
/// Port of Go's TestNYCbCrAAlpha.
/// NYCbCrA alpha channel matches Alpha{i}.
test "nycbcra_alpha" {
  for i in 0..<256 {
    let c0 : AnyColor = AnyColor::NYCbCrA({
      ycbcr: { y: b'\xff', cb: b'\x80', cr: b'\x80' },
      a: i.to_byte(),
    })
    let c1 : AnyColor = AnyColor::Alpha({ a: i.to_byte() })
    assert_true(color_eq(c0, c1))
  }
}

///|
/// Port of Go's TestNYCbCrAYCbCr.
/// NYCbCrA{.., 0xFF} matches YCbCr for r,g,b channels.
test "nycbcra_ycbcr" {
  for i in 0..<256 {
    let c0 : AnyColor = AnyColor::NYCbCrA({
      ycbcr: { y: i.to_byte(), cb: b'\x40', cr: b'\xc0' },
      a: b'\xff',
    })
    let c1 : AnyColor = AnyColor::YCbCr({
      y: i.to_byte(),
      cb: b'\x40',
      cr: b'\xc0',
    })
    assert_true(color_eq(c0, c1))
  }
}

///|
/// Port of Go's TestCMYKRoundtrip.
/// RGB -> CMYK -> RGB, delta <= 1.
test "cmyk_roundtrip" {
  let mut r = 0
  while r < 256 {
    let mut g = 0
    while g < 256 {
      let mut b = 0
      while b < 256 {
        let r0 = r.to_byte()
        let g0 = g.to_byte()
        let b0 = b.to_byte()
        let (c, m, y, k) = rgb_to_cmyk(r0, g0, b0)
        let (r1, g1, b1) = cmyk_to_rgb(c, m, y, k)
        assert_true(byte_delta(r0, r1) <= 1)
        assert_true(byte_delta(g0, g1) <= 1)
        assert_true(byte_delta(b0, b1) <= 1)
        b += 3
      }
      g += 5
    }
    r += 7
  }
}

///|
/// Port of Go's TestCMYKToRGBConsistency.
/// CMYK.rgba() >> 8 == cmyk_to_rgb().
test "cmyk_to_rgb_consistency" {
  let mut c = 0
  while c < 256 {
    let mut m = 0
    while m < 256 {
      let mut y = 0
      while y < 256 {
        let mut k = 0
        while k < 256 {
          let x : CMYK = {
            c: c.to_byte(),
            m: m.to_byte(),
            y: y.to_byte(),
            k: k.to_byte(),
          }
          let (r0, g0, b0, _) = x.rgba()
          let r1 = (r0 >> 8).to_byte()
          let g1 = (g0 >> 8).to_byte()
          let b1 = (b0 >> 8).to_byte()
          let (r2, g2, b2) = cmyk_to_rgb(
            c.to_byte(),
            m.to_byte(),
            y.to_byte(),
            k.to_byte(),
          )
          assert_eq(r1, r2)
          assert_eq(g1, g2)
          assert_eq(b1, b2)
          k += 11
        }
        y += 3
      }
      m += 5
    }
    c += 7
  }
}

///|
/// Port of Go's TestCMYKGray.
/// CMYK{0,0,0,255-i}.rgba() == Gray{i}.rgba().
test "cmyk_gray" {
  for i in 0..<256 {
    let c0 : AnyColor = AnyColor::CMYK({
      c: b'\x00',
      m: b'\x00',
      y: b'\x00',
      k: (255 - i).to_byte(),
    })
    let c1 : AnyColor = AnyColor::Gray({ y: i.to_byte() })
    assert_true(color_eq(c0, c1))
  }
}

///|
/// Port of Go's TestPalette.
/// Palette.index() closest color matching.
test "palette" {
  let p : Palette = {
    colors: [
      AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' }),
      AnyColor::RGBA({ r: b'\x80', g: b'\x00', b: b'\x00', a: b'\xff' }),
      AnyColor::RGBA({ r: b'\x7f', g: b'\x00', b: b'\x00', a: b'\x7f' }),
      AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x7f' }),
      AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }),
      AnyColor::RGBA({ r: b'\x40', g: b'\x40', b: b'\x40', a: b'\x40' }),
    ],
  }
  // For a Palette with no repeated colors, the closest to each element is itself
  for i, c in p.colors {
    let j = p.index(c)
    assert_eq(i, j)
  }
  // Finding closest color considers alpha
  let got = p.convert(
    AnyColor::RGBA({ r: b'\x80', g: b'\x00', b: b'\x00', a: b'\x80' }),
  )
  let want = AnyColor::RGBA({ r: b'\x7f', g: b'\x00', b: b'\x00', a: b'\x7f' })
  assert_eq(got, Some(want))
}
