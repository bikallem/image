///|
fn cmp_color(
  cm : @color.AnyModel,
  c0 : @color.AnyColor,
  c1 : @color.AnyColor
) -> Bool {
  let (r0, g0, b0, a0) = cm.convert(c0).rgba()
  let (r1, g1, b1, a1) = cm.convert(c1).rgba()
  r0 == r1 && g0 == g1 && b0 == b1 && a0 == a1
}

///|
let transparent_color : @color.AnyColor = @color.AnyColor::Alpha(
  { a: b'\x00' },
)

///|
let opaque_color : @color.AnyColor = @color.AnyColor::Alpha(
  { a: b'\xff' },
)

///|
/// Port of Go's TestImage from image_test.go.
/// Tests RGBA image: create, set pixels, read back, verify, SubImage.
test "image_types_rgba" {
  let m = new_image_rgba(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  assert_true(
    cmp_color(
      @color.AnyModel::RGBAModel,
      transparent_color,
      @color.AnyColor::RGBA(m.rgba_at(6, 3)),
    ),
  )
  m.set_rgba(6, 3, { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' })
  assert_true(
    cmp_color(
      @color.AnyModel::RGBAModel,
      opaque_color,
      @color.AnyColor::RGBA(m.rgba_at(6, 3)),
    ),
  )
  let sub = m.sub_image(rect(6, 3, 7, 4))
  assert_true(sub.is_opaque())
  let m2 = m.sub_image(rect(3, 2, 9, 8))
  assert_true(rect(3, 2, 9, 8).eq(m2.rect))
  assert_true(
    cmp_color(
      @color.AnyModel::RGBAModel,
      opaque_color,
      @color.AnyColor::RGBA(m2.rgba_at(6, 3)),
    ),
  )
  assert_true(
    cmp_color(
      @color.AnyModel::RGBAModel,
      transparent_color,
      @color.AnyColor::RGBA(m2.rgba_at(3, 3)),
    ),
  )
  m2.set_rgba(3, 3, { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' })
  assert_true(
    cmp_color(
      @color.AnyModel::RGBAModel,
      opaque_color,
      @color.AnyColor::RGBA(m2.rgba_at(3, 3)),
    ),
  )
  // Test empty sub-images at corners
  ignore(m2.sub_image(rect(0, 0, 0, 0)))
  ignore(m2.sub_image(rect(10, 0, 10, 0)))
  ignore(m2.sub_image(rect(0, 10, 0, 10)))
  ignore(m2.sub_image(rect(10, 10, 10, 10)))
}

///|
test "image_types_rgba64" {
  let m = new_image_rgba64(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_rgba64(6, 3, { r: 0xffff, g: 0xffff, b: 0xffff, a: 0xffff })
  let c = m.rgba64_at(6, 3)
  assert_eq(c.r, 0xffffU)
  let sub = m.sub_image(rect(6, 3, 7, 4))
  assert_true(sub.is_opaque())
}

///|
test "image_types_nrgba" {
  let m = new_image_nrgba(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_nrgba(6, 3, { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' })
  let c = m.nrgba_at(6, 3)
  assert_eq(c.a, b'\xff')
}

///|
test "image_types_nrgba64" {
  let m = new_image_nrgba64(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_nrgba64(6, 3, { r: 0xffff, g: 0xffff, b: 0xffff, a: 0xffff })
  let c = m.nrgba64_at(6, 3)
  assert_eq(c.r, 0xffffU)
}

///|
test "image_types_alpha" {
  let m = new_image_alpha(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_alpha(6, 3, { a: b'\xff' })
  let c = m.alpha_at(6, 3)
  assert_eq(c.a, b'\xff')
  assert_false(m.is_opaque())
}

///|
test "image_types_alpha16" {
  let m = new_image_alpha16(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_alpha16(6, 3, { a: 0xffff })
  let c = m.alpha16_at(6, 3)
  assert_eq(c.a, 0xffffU)
}

///|
test "image_types_gray" {
  let m = new_image_gray(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_gray(6, 3, { y: b'\xff' })
  let c = m.gray_at(6, 3)
  assert_eq(c.y, b'\xff')
}

///|
test "image_types_gray16" {
  let m = new_image_gray16(rect(0, 0, 10, 10))
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_gray16(6, 3, { y: 0xffff })
  let c = m.gray16_at(6, 3)
  assert_eq(c.y, 0xffffU)
}

///|
test "image_types_paletted" {
  let m = new_image_paletted(
    rect(0, 0, 10, 10),
    {
      colors: [
        @color.AnyColor::Alpha({ a: b'\x00' }),
        @color.AnyColor::Alpha({ a: b'\xff' }),
      ],
    },
  )
  assert_true(rect(0, 0, 10, 10).eq(m.rect))
  m.set_color_index(6, 3, b'\x01')
  let ci = m.color_index_at(6, 3)
  assert_eq(ci, b'\x01')
}

///|
/// Port of Go's Test16BitsPerColorChannel.
/// RGBA64, NRGBA64, Alpha16, Gray16 preserve 16-bit values.
test "16bit_color" {
  // Test color models preserve 16-bit precision
  let test_c = @color.AnyColor::RGBA64(
    { r: 0x1234, g: 0x1234, b: 0x1234, a: 0x1234 },
  )
  let models : Array[@color.AnyModel] = [
    @color.AnyModel::RGBA64Model,
    @color.AnyModel::NRGBA64Model,
    @color.AnyModel::Alpha16Model,
    @color.AnyModel::Gray16Model,
  ]
  for cm in models {
    let c = cm.convert(test_c)
    let (r, _, _, _) = c.rgba()
    assert_eq(r, 0x1234U)
  }
  // Test images preserve 16-bit precision via set+get
  let test_nrgba : @color.NRGBA64 = {
    r: 0xffff,
    g: 0xffff,
    b: 0xffff,
    a: 0x1357,
  }
  let m_rgba64 = new_image_rgba64(rect(0, 0, 10, 10))
  let converted = @color.AnyModel::RGBA64Model.convert(
    @color.AnyColor::NRGBA64(test_nrgba),
  )
  let rgba64_c = match converted {
    @color.AnyColor::RGBA64(c) => c
    _ => abort("expected RGBA64")
  }
  m_rgba64.set_rgba64(1, 2, rgba64_c)
  let (r, _, _, _) = m_rgba64.rgba64_at(1, 2).rgba()
  assert_eq(r, 0x1357U)
  let m_nrgba64 = new_image_nrgba64(rect(0, 0, 10, 10))
  m_nrgba64.set_nrgba64(1, 2, test_nrgba)
  let (r2, _, _, _) = m_nrgba64.nrgba64_at(1, 2).rgba()
  assert_eq(r2, 0x1357U)
  let m_alpha16 = new_image_alpha16(rect(0, 0, 10, 10))
  m_alpha16.set_alpha16(1, 2, { a: 0x1357 })
  let (r3, _, _, _) = m_alpha16.alpha16_at(1, 2).rgba()
  assert_eq(r3, 0x1357U)
  let m_gray16 = new_image_gray16(rect(0, 0, 10, 10))
  m_gray16.set_gray16(1, 2, { y: 0x1357 })
  let (r4, _, _, _) = m_gray16.gray16_at(1, 2).rgba()
  assert_eq(r4, 0x1357U)
}
