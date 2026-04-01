///|
pub(all) struct ImageCMYK {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageCMYK::pix_offset(self : ImageCMYK, x : Int, y : Int) -> Int {
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 4
}

///|
pub fn ImageCMYK::cmyk_at(self : ImageCMYK, x : Int, y : Int) -> @color.CMYK {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { c: b'\x00', m: b'\x00', y: b'\x00', k: b'\x00' }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 4
  {
    c: self.pix.unsafe_get(i),
    m: self.pix.unsafe_get(i + 1),
    y: self.pix.unsafe_get(i + 2),
    k: self.pix.unsafe_get(i + 3),
  }
}

///|
pub fn ImageCMYK::set_cmyk(
  self : ImageCMYK,
  x : Int,
  y : Int,
  c : @color.CMYK,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 4
  self.pix.unsafe_set(i, c.c)
  self.pix.unsafe_set(i + 1, c.m)
  self.pix.unsafe_set(i + 2, c.y)
  self.pix.unsafe_set(i + 3, c.k)
}

///|
pub fn ImageCMYK::set(
  self : ImageCMYK,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (cr, cg, cb, _) = c.rgba()
  let (cc, mm, yy, kk) = @color.rgb_to_cmyk(
    (cr >> 8).to_byte(),
    (cg >> 8).to_byte(),
    (cb >> 8).to_byte(),
  )
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 4
  self.pix.unsafe_set(i, cc)
  self.pix.unsafe_set(i + 1, mm)
  self.pix.unsafe_set(i + 2, yy)
  self.pix.unsafe_set(i + 3, kk)
}

///|
pub impl Image for ImageCMYK with color_model(_self) -> &@color.Model {
  @color.CMYKModel::{  }
}

///|
pub impl Image for ImageCMYK with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageCMYK with at(self, x, y) -> &@color.Color {
  self.cmyk_at(x, y)
}

///|
pub impl Image for ImageCMYK with set(self, x, y, c) -> Unit {
  ImageCMYK::set(self, x, y, c)
}

///|
pub fn ImageCMYK::sub_image(self : ImageCMYK, r : Rectangle) -> ImageCMYK {
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
