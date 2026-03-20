///|
pub(all) struct ImageCMYK {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageCMYK::pix_offset(self : ImageCMYK, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride +
  (x - self.rect.min.x) * 4
}

///|
pub fn ImageCMYK::cmyk_at(
  self : ImageCMYK,
  x : Int,
  y : Int
) -> @color.CMYK {
  if !({ x, y } : Point).in_(self.rect) {
    return { c: b'\x00', m: b'\x00', y: b'\x00', k: b'\x00' }
  }
  let i = self.pix_offset(x, y)
  {
    c: self.pix[i],
    m: self.pix[i + 1],
    y: self.pix[i + 2],
    k: self.pix[i + 3],
  }
}

///|
pub fn ImageCMYK::set_cmyk(
  self : ImageCMYK,
  x : Int,
  y : Int,
  c : @color.CMYK
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix[i] = c.c
  self.pix[i + 1] = c.m
  self.pix[i + 2] = c.y
  self.pix[i + 3] = c.k
}

///|
pub fn ImageCMYK::set(
  self : ImageCMYK,
  x : Int,
  y : Int,
  c : @color.AnyColor
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let c1 = @color.AnyModel::CMYKModel.convert(c)
  guard c1 is @color.AnyColor::CMYK(cc) else { return }
  let i = self.pix_offset(x, y)
  self.pix[i] = cc.c
  self.pix[i + 1] = cc.m
  self.pix[i + 2] = cc.y
  self.pix[i + 3] = cc.k
}

///|
pub fn ImageCMYK::sub_image(
  self : ImageCMYK,
  r : Rectangle
) -> ImageCMYK {
  let r = r.intersect(self.rect)
  if r.empty() {
    return {
      pix: FixedArray::make(0, b'\x00'),
      pix_offset: 0,
      stride: self.stride,
      rect: r,
    }
  }
  let i = self.pix_offset(r.min.x, r.min.y)
  { pix: self.pix, pix_offset: i, stride: self.stride, rect: r }
}

///|
pub fn ImageCMYK::is_opaque(_self : ImageCMYK) -> Bool {
  true
}

///|
pub fn new_image_cmyk(r : Rectangle) -> ImageCMYK {
  let len = pixel_buffer_length(4, r, "CMYK")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 4 * r.dx(),
    rect: r,
  }
}
