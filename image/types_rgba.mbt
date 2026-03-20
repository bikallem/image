///|
/// ImageRGBA is an in-memory image whose At method returns color.RGBA values.
pub(all) struct ImageRGBA {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageRGBA::pix_offset(self : ImageRGBA, x : Int, y : Int) -> Int {
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 4
}

///|
pub fn ImageRGBA::rgba_at(self : ImageRGBA, x : Int, y : Int) -> @color.RGBA {
  if !({ x, y } : Point).in_(self.rect) {
    return { r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }
  }
  let i = self.pix_offset(x, y)
  {
    r: self.pix.unsafe_get(i),
    g: self.pix.unsafe_get(i + 1),
    b: self.pix.unsafe_get(i + 2),
    a: self.pix.unsafe_get(i + 3),
  }
}

///|
pub fn ImageRGBA::set(
  self : ImageRGBA,
  x : Int,
  y : Int,
  c : @color.AnyColor,
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let c1 = @color.AnyModel::RGBAModel.convert(c)
  guard c1 is @color.AnyColor::RGBA(rgba) else { return }
  let i = self.pix_offset(x, y)
  self.pix.unsafe_set(i, rgba.r)
  self.pix.unsafe_set(i + 1, rgba.g)
  self.pix.unsafe_set(i + 2, rgba.b)
  self.pix.unsafe_set(i + 3, rgba.a)
}

///|
pub fn ImageRGBA::set_rgba(
  self : ImageRGBA,
  x : Int,
  y : Int,
  c : @color.RGBA,
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix.unsafe_set(i, c.r)
  self.pix.unsafe_set(i + 1, c.g)
  self.pix.unsafe_set(i + 2, c.b)
  self.pix.unsafe_set(i + 3, c.a)
}

///|
pub fn ImageRGBA::sub_image(self : ImageRGBA, r : Rectangle) -> ImageRGBA {
  let r = r.intersect(self.rect)
  if r.empty() {
    return {
      pix: FixedArray::make(0, b'\x00'),
      pix_offset: 0,
      stride: self.stride,
      rect: r,
    }
  }
  let i = self.pix_offset(r.min_x, r.min_y)
  { pix: self.pix, pix_offset: i, stride: self.stride, rect: r }
}

///|
pub fn ImageRGBA::is_opaque(self : ImageRGBA) -> Bool {
  if self.rect.empty() {
    return true
  }
  for y = self.rect.min_y; y < self.rect.max_y; y = y + 1 {
    let row_start = self.pix_offset + (y - self.rect.min_y) * self.stride
    for x = 0; x < self.rect.dx(); x = x + 1 {
      if self.pix.unsafe_get(row_start + x * 4 + 3) != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn new_image_rgba(r : Rectangle) -> ImageRGBA {
  let len = pixel_buffer_length(4, r, "RGBA")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 4 * r.dx(),
    rect: r,
  }
}

///|
/// ImageRGBA64 is an in-memory image whose At method returns color.RGBA64 values.
pub(all) struct ImageRGBA64 {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageRGBA64::pix_offset(self : ImageRGBA64, x : Int, y : Int) -> Int {
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 8
}

///|
pub fn ImageRGBA64::rgba64_at(
  self : ImageRGBA64,
  x : Int,
  y : Int,
) -> @color.RGBA64 {
  if !({ x, y } : Point).in_(self.rect) {
    return { r: 0U, g: 0U, b: 0U, a: 0U }
  }
  let i = self.pix_offset(x, y)
  {
    r: (self.pix.unsafe_get(i).to_uint() << 8) |
    self.pix.unsafe_get(i + 1).to_uint(),
    g: (self.pix.unsafe_get(i + 2).to_uint() << 8) |
    self.pix.unsafe_get(i + 3).to_uint(),
    b: (self.pix.unsafe_get(i + 4).to_uint() << 8) |
    self.pix.unsafe_get(i + 5).to_uint(),
    a: (self.pix.unsafe_get(i + 6).to_uint() << 8) |
    self.pix.unsafe_get(i + 7).to_uint(),
  }
}

///|
pub fn ImageRGBA64::set(
  self : ImageRGBA64,
  x : Int,
  y : Int,
  c : @color.AnyColor,
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let c1 = @color.AnyModel::RGBA64Model.convert(c)
  guard c1 is @color.AnyColor::RGBA64(rgba64) else { return }
  let i = self.pix_offset(x, y)
  self.pix.unsafe_set(i, (rgba64.r >> 8).to_byte())
  self.pix.unsafe_set(i + 1, rgba64.r.to_byte())
  self.pix.unsafe_set(i + 2, (rgba64.g >> 8).to_byte())
  self.pix.unsafe_set(i + 3, rgba64.g.to_byte())
  self.pix.unsafe_set(i + 4, (rgba64.b >> 8).to_byte())
  self.pix.unsafe_set(i + 5, rgba64.b.to_byte())
  self.pix.unsafe_set(i + 6, (rgba64.a >> 8).to_byte())
  self.pix.unsafe_set(i + 7, rgba64.a.to_byte())
}

///|
pub fn ImageRGBA64::set_rgba64(
  self : ImageRGBA64,
  x : Int,
  y : Int,
  c : @color.RGBA64,
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix.unsafe_set(i, (c.r >> 8).to_byte())
  self.pix.unsafe_set(i + 1, c.r.to_byte())
  self.pix.unsafe_set(i + 2, (c.g >> 8).to_byte())
  self.pix.unsafe_set(i + 3, c.g.to_byte())
  self.pix.unsafe_set(i + 4, (c.b >> 8).to_byte())
  self.pix.unsafe_set(i + 5, c.b.to_byte())
  self.pix.unsafe_set(i + 6, (c.a >> 8).to_byte())
  self.pix.unsafe_set(i + 7, c.a.to_byte())
}

///|
pub fn ImageRGBA64::sub_image(self : ImageRGBA64, r : Rectangle) -> ImageRGBA64 {
  let r = r.intersect(self.rect)
  if r.empty() {
    return {
      pix: FixedArray::make(0, b'\x00'),
      pix_offset: 0,
      stride: self.stride,
      rect: r,
    }
  }
  let i = self.pix_offset(r.min_x, r.min_y)
  { pix: self.pix, pix_offset: i, stride: self.stride, rect: r }
}

///|
pub fn ImageRGBA64::is_opaque(self : ImageRGBA64) -> Bool {
  if self.rect.empty() {
    return true
  }
  for y = self.rect.min_y; y < self.rect.max_y; y = y + 1 {
    let row_start = self.pix_offset + (y - self.rect.min_y) * self.stride
    for x = 0; x < self.rect.dx(); x = x + 1 {
      let i = row_start + x * 8 + 6
      if self.pix.unsafe_get(i) != b'\xff' ||
        self.pix.unsafe_get(i + 1) != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn new_image_rgba64(r : Rectangle) -> ImageRGBA64 {
  let len = pixel_buffer_length(8, r, "RGBA64")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 8 * r.dx(),
    rect: r,
  }
}
