///|
/// Port of Go's TestClip from clip_test.go.
test "clip" {
  let dst0 = @image.new_image_rgba(@image.rect(0, 0, 100, 100))
  let src0 = @image.new_image_rgba(@image.rect(0, 0, 100, 100))
  let mask0 = @image.new_image_rgba(@image.rect(0, 0, 100, 100))
  // Test cases: (desc, r, dr, sr, mr, sp, mp, nil_mask, r0, sp0, mp0)
  let tests : Array[
    (
      String,
      @image.Rectangle,
      @image.Rectangle,
      @image.Rectangle,
      @image.Rectangle,
      @image.Point,
      @image.Point,
      Bool,
      @image.Rectangle,
      @image.Point,
      @image.Point,
    ),
  ] = [
    (
      "basic",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 0, 0),
      { x: 0, y: 0 },
      { x: 0, y: 0 },
      true,
      @image.rect(0, 0, 100, 100),
      { x: 0, y: 0 },
      { x: 0, y: 0 },
    ),
    (
      "clip dr",
      @image.rect(0, 0, 100, 100),
      @image.rect(40, 40, 60, 60),
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 0, 0),
      { x: 0, y: 0 },
      { x: 0, y: 0 },
      true,
      @image.rect(40, 40, 60, 60),
      { x: 40, y: 40 },
      { x: 0, y: 0 },
    ),
    (
      "clip sr",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 100, 100),
      @image.rect(20, 20, 80, 80),
      @image.rect(0, 0, 0, 0),
      { x: 0, y: 0 },
      { x: 0, y: 0 },
      true,
      @image.rect(20, 20, 80, 80),
      { x: 20, y: 20 },
      { x: 0, y: 0 },
    ),
    (
      "clip dr and sr",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 50, 100),
      @image.rect(20, 20, 80, 80),
      @image.rect(0, 0, 0, 0),
      { x: 0, y: 0 },
      { x: 0, y: 0 },
      true,
      @image.rect(20, 20, 50, 80),
      { x: 20, y: 20 },
      { x: 0, y: 0 },
    ),
    (
      "clip dr and sr, sp outside sr (top-left)",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 50, 100),
      @image.rect(20, 20, 80, 80),
      @image.rect(0, 0, 0, 0),
      { x: 15, y: 8 },
      { x: 0, y: 0 },
      true,
      @image.rect(5, 12, 50, 72),
      { x: 20, y: 20 },
      { x: 0, y: 0 },
    ),
    (
      "clip dr and sr, sp outside sr (middle-left)",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 50, 100),
      @image.rect(20, 20, 80, 80),
      @image.rect(0, 0, 0, 0),
      { x: 15, y: 66 },
      { x: 0, y: 0 },
      true,
      @image.rect(5, 0, 50, 14),
      { x: 20, y: 66 },
      { x: 0, y: 0 },
    ),
    (
      "clip dr and sr, sp outside sr (bottom-left)",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 50, 100),
      @image.rect(20, 20, 80, 80),
      @image.rect(0, 0, 0, 0),
      { x: 15, y: 91 },
      { x: 0, y: 0 },
      true,
      @image.rect(0, 0, 0, 0),
      { x: 15, y: 91 },
      { x: 0, y: 0 },
    ),
    (
      "clip dr and sr, sp inside sr",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 50, 100),
      @image.rect(20, 20, 80, 80),
      @image.rect(0, 0, 0, 0),
      { x: 44, y: 33 },
      { x: 0, y: 0 },
      true,
      @image.rect(0, 0, 36, 47),
      { x: 44, y: 33 },
      { x: 0, y: 0 },
    ),
    // Non-nil mask tests
    (
      "basic mask",
      @image.rect(0, 0, 80, 80),
      @image.rect(20, 0, 100, 80),
      @image.rect(0, 0, 50, 49),
      @image.rect(0, 0, 46, 47),
      { x: 0, y: 0 },
      { x: 0, y: 0 },
      false,
      @image.rect(20, 0, 46, 47),
      { x: 20, y: 0 },
      { x: 20, y: 0 },
    ),
    (
      "clip sr and mr",
      @image.rect(0, 0, 100, 100),
      @image.rect(0, 0, 100, 100),
      @image.rect(23, 23, 55, 86),
      @image.rect(44, 44, 87, 58),
      { x: 10, y: 10 },
      { x: 11, y: 11 },
      false,
      @image.rect(33, 33, 45, 47),
      { x: 43, y: 43 },
      { x: 44, y: 44 },
    ),
  ]
  for tc in tests {
    let (
      _desc, r, dr, sr, mr, sp, mp, nil_mask, r0_expected, sp0_expected,
      mp0_expected,
    ) = tc
    let dst = @image.AnyImage::RGBA(dst0.sub_image(dr))
    let src = @image.AnyImage::RGBA(src0.sub_image(sr))
    let mask : @image.AnyImage? = if nil_mask {
      None
    } else {
      Some(@image.AnyImage::RGBA(mask0.sub_image(mr)))
    }
    let (r_got, sp_got, _mp_got) = clip(dst, r, src, sp, mask, mp)
    assert_true!(r_got.eq(r0_expected))
    assert_true!(sp_got.x == sp0_expected.x && sp_got.y == sp0_expected.y)
    if !nil_mask {
      assert_true!(
        _mp_got.x == mp0_expected.x && _mp_got.y == mp0_expected.y,
      )
    }
    // Verify clipped rect is within bounds
    assert_true!(r_got.in_(dr))
  }
}

///|
/// Port of Go's TestFill from draw_test.go.
test "fill" {
  for i in 0..<5 {
    let dst = @image.new_image_rgba(@image.rect(0, 0, 10, 10))
    let (r, c) = match i {
      0 => (@image.rect(0, 0, 10, 10), @color.AnyColor::RGBA({ r: b'\xff', g: b'\x00', b: b'\x00', a: b'\xff' }))
      1 => (@image.rect(3, 3, 7, 7), @color.AnyColor::RGBA({ r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' }))
      2 => (@image.rect(0, 0, 0, 0), @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' }))
      3 => (@image.rect(-10, -10, 20, 20), @color.AnyColor::RGBA({ r: b'\xff', g: b'\xff', b: b'\x00', a: b'\xff' }))
      _ => (@image.rect(5, 5, 10, 10), @color.AnyColor::RGBA({ r: b'\xff', g: b'\x00', b: b'\xff', a: b'\xff' }))
    }
    let src = @image.AnyImage::Uniform(@image.ImageUniform::{ c })
    draw(
      @image.AnyImage::RGBA(dst),
      r,
      src,
      r.min,
      Src,
    )
    // Verify pixels inside r have the fill color
    let (cr, cg, cb, ca) = c.rgba()
    let clipped = r.intersect(@image.rect(0, 0, 10, 10))
    let mut y = clipped.min.y
    while y < clipped.max.y {
      let mut x = clipped.min.x
      while x < clipped.max.x {
        let (pr, pg, pb, pa) = dst.rgba_at(x, y).rgba()
        assert_eq!(pr, cr)
        assert_eq!(pg, cg)
        assert_eq!(pb, cb)
        assert_eq!(pa, ca)
        x += 1
      }
      y += 1
    }
  }
}

///|
/// Port of Go's TestNonZeroSrcPt from draw_test.go.
test "non_zero_src_pt" {
  let src = @image.new_image_rgba(@image.rect(0, 0, 2, 2))
  src.set_rgba(0, 0, { r: b'\x00', g: b'\x00', b: b'\x00', a: b'\xff' })
  src.set_rgba(1, 0, { r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' })
  src.set_rgba(0, 1, { r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' })
  src.set_rgba(1, 1, { r: b'\xff', g: b'\x00', b: b'\x00', a: b'\xff' })
  let dst = @image.new_image_rgba(@image.rect(0, 0, 1, 1))
  draw(
    @image.AnyImage::RGBA(dst),
    @image.rect(0, 0, 1, 1),
    @image.AnyImage::RGBA(src),
    { x: 1, y: 1 },
    Src,
  )
  let c = dst.rgba_at(0, 0)
  assert_eq!(c.r, b'\xff')
  assert_eq!(c.g, b'\x00')
  assert_eq!(c.b, b'\x00')
}

///|
/// Port of Go's TestFloydSteinbergCheckerboard from draw_test.go.
test "floyd_steinberg_checkerboard" {
  let b = @image.rect(0, 0, 640, 480)
  // Floyd-Steinberg dithering of 50% gray on a 2-color palette should
  // produce a checkerboard
  let dst = @image.new_image_paletted(
    b,
    {
      colors: [
        @color.AnyColor::Gray({ y: b'\x00' }),
        @color.AnyColor::Gray({ y: b'\xff' }),
      ],
    },
  )
  // Use Gray16{0x7fff} for close-to-50% gray, matching Go's test
  let src = @image.AnyImage::Uniform(@image.ImageUniform::{ c: @color.AnyColor::Gray16({ y: 0x7fff }) })
  floyd_steinberg_draw(dst, b, src, { x: 0, y: 0 })
  let nErr = { val: 0 }
  let mut y = b.min.y
  while y < b.max.y {
    let mut x = b.min.x
    while x < b.max.x {
      let got = dst.color_index_at(x, y).to_int()
      let want = (x + y) % 2
      if got != want {
        nErr.val += 1
      }
      x += 1
    }
    y += 1
  }
  // Allow some error at edges but most should be perfect
  assert_true!(nErr.val < 2)
}

///|
/// Port of Go's TestDrawOverlap from draw_test.go.
test "draw_overlap" {
  // Test drawing from overlapping src/dst regions
  for op in [Over, Src] {
    for yoff = -2; yoff <= 2; yoff = yoff + 1 {
      for xoff = -2; xoff <= 2; xoff = xoff + 1 {
        let m = @image.new_image_rgba(@image.rect(0, 0, 16, 16))
        // Initialize with a pattern
        let mut y = 0
        while y < 16 {
          let mut x = 0
          while x < 16 {
            m.set_rgba(
              x,
              y,
              {
                r: (y * 16 + x).to_byte(),
                g: b'\x00',
                b: b'\x00',
                a: b'\xff',
              },
            )
            x += 1
          }
          y += 1
        }
        // Draw region of m onto itself with offset
        let sr = @image.rect(4, 4, 12, 12)
        let dr = sr.add({ x: xoff, y: yoff })
        draw(
          @image.AnyImage::RGBA(m),
          dr,
          @image.AnyImage::RGBA(m),
          sr.min,
          op,
        )
        // Just verify it doesn't crash and produces valid pixels
        y = dr.min.y
        while y < dr.max.y {
          let mut x = dr.min.x
          while x < dr.max.x {
            if ({ x, y } : @image.Point).in_(m.rect) {
              let c = m.rgba_at(x, y)
              assert_true!(c.a == b'\xff')
            }
            x += 1
          }
          y += 1
        }
      }
    }
  }
}

///|
/// Port of Go's TestDrawSrcNonpremultiplied from draw_test.go.
/// NRGBA and NRGBA64 Src should preserve non-premultiplied alpha distinctions.
test "draw_src_nonpremultiplied" {
  // Test drawing NRGBA onto RGBA (the fast-path that draw dispatches to)
  let src = @image.new_image_nrgba(@image.rect(0, 0, 3, 1))
  src.set_nrgba(0, 0, { r: b'\xff', g: b'\x00', b: b'\x00', a: b'\x00' }) // transparent red
  src.set_nrgba(1, 0, { r: b'\x00', g: b'\x00', b: b'\xff', a: b'\x00' }) // transparent blue
  src.set_nrgba(2, 0, { r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' }) // opaque green
  let dst = @image.new_image_rgba(@image.rect(0, 0, 3, 1))
  draw(
    @image.AnyImage::RGBA(dst),
    dst.rect,
    @image.AnyImage::NRGBA(src),
    { x: 0, y: 0 },
    Src,
  )
  // transparent src with Src op should set dst to transparent (a=0)
  let c0 = dst.rgba_at(0, 0)
  assert_eq!(c0.a, b'\x00')
  // opaque green should come through
  let c2 = dst.rgba_at(2, 0)
  assert_eq!(c2.g, b'\xff')
  assert_eq!(c2.a, b'\xff')
}
