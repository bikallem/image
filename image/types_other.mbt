///|
pub(all) struct ImageNRGBA {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageNRGBA::pix_offset(self : ImageNRGBA, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride +
  (x - self.rect.min.x) * 4
}

///|
pub fn ImageNRGBA::nrgba_at(self : ImageNRGBA, x : Int, y : Int) -> @color.NRGBA {
  if !({ x, y } : Point).in_(self.rect) {
    return { r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }
  }
  let i = self.pix_offset(x, y)
  { r: self.pix[i], g: self.pix[i + 1], b: self.pix[i + 2], a: self.pix[i + 3] }
}

///|
pub fn ImageNRGBA::set_nrgba(
  self : ImageNRGBA,
  x : Int,
  y : Int,
  c : @color.NRGBA
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix[i] = c.r
  self.pix[i + 1] = c.g
  self.pix[i + 2] = c.b
  self.pix[i + 3] = c.a
}

///|
pub fn ImageNRGBA::is_opaque(self : ImageNRGBA) -> Bool {
  if self.rect.empty() {
    return true
  }
  for y = self.rect.min.y; y < self.rect.max.y; y = y + 1 {
    let row_start = self.pix_offset + (y - self.rect.min.y) * self.stride
    for x = 0; x < self.rect.dx(); x = x + 1 {
      if self.pix[row_start + x * 4 + 3] != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn new_image_nrgba(r : Rectangle) -> ImageNRGBA {
  let len = pixel_buffer_length(4, r, "NRGBA")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 4 * r.dx(),
    rect: r,
  }
}

///|
pub(all) struct ImageNRGBA64 {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageNRGBA64::pix_offset(self : ImageNRGBA64, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride +
  (x - self.rect.min.x) * 8
}

///|
pub fn ImageNRGBA64::nrgba64_at(
  self : ImageNRGBA64,
  x : Int,
  y : Int
) -> @color.NRGBA64 {
  if !({ x, y } : Point).in_(self.rect) {
    return { r: 0U, g: 0U, b: 0U, a: 0U }
  }
  let i = self.pix_offset(x, y)
  {
    r: (self.pix[i].to_uint() << 8) | self.pix[i + 1].to_uint(),
    g: (self.pix[i + 2].to_uint() << 8) | self.pix[i + 3].to_uint(),
    b: (self.pix[i + 4].to_uint() << 8) | self.pix[i + 5].to_uint(),
    a: (self.pix[i + 6].to_uint() << 8) | self.pix[i + 7].to_uint(),
  }
}

///|
pub fn ImageNRGBA64::set_nrgba64(
  self : ImageNRGBA64,
  x : Int,
  y : Int,
  c : @color.NRGBA64
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix[i] = (c.r >> 8).to_byte()
  self.pix[i + 1] = c.r.to_byte()
  self.pix[i + 2] = (c.g >> 8).to_byte()
  self.pix[i + 3] = c.g.to_byte()
  self.pix[i + 4] = (c.b >> 8).to_byte()
  self.pix[i + 5] = c.b.to_byte()
  self.pix[i + 6] = (c.a >> 8).to_byte()
  self.pix[i + 7] = c.a.to_byte()
}

///|
pub fn new_image_nrgba64(r : Rectangle) -> ImageNRGBA64 {
  let len = pixel_buffer_length(8, r, "NRGBA64")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 8 * r.dx(),
    rect: r,
  }
}

///|
pub(all) struct ImageAlpha {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageAlpha::pix_offset(self : ImageAlpha, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride + (x - self.rect.min.x)
}

///|
pub fn ImageAlpha::alpha_at(self : ImageAlpha, x : Int, y : Int) -> @color.Alpha {
  if !({ x, y } : Point).in_(self.rect) {
    return { a: b'\x00' }
  }
  let i = self.pix_offset(x, y)
  { a: self.pix[i] }
}

///|
pub fn ImageAlpha::set_alpha(
  self : ImageAlpha,
  x : Int,
  y : Int,
  c : @color.Alpha
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  self.pix[self.pix_offset(x, y)] = c.a
}

///|
pub fn ImageAlpha::is_opaque(self : ImageAlpha) -> Bool {
  if self.rect.empty() {
    return true
  }
  for y = self.rect.min.y; y < self.rect.max.y; y = y + 1 {
    let row_start = self.pix_offset + (y - self.rect.min.y) * self.stride
    for x = 0; x < self.rect.dx(); x = x + 1 {
      if self.pix[row_start + x] != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn new_image_alpha(r : Rectangle) -> ImageAlpha {
  let len = pixel_buffer_length(1, r, "Alpha")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: r.dx(),
    rect: r,
  }
}

///|
pub(all) struct ImageAlpha16 {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageAlpha16::pix_offset(self : ImageAlpha16, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride +
  (x - self.rect.min.x) * 2
}

///|
pub fn ImageAlpha16::alpha16_at(
  self : ImageAlpha16,
  x : Int,
  y : Int
) -> @color.Alpha16 {
  if !({ x, y } : Point).in_(self.rect) {
    return { a: 0U }
  }
  let i = self.pix_offset(x, y)
  { a: (self.pix[i].to_uint() << 8) | self.pix[i + 1].to_uint() }
}

///|
pub fn ImageAlpha16::set_alpha16(
  self : ImageAlpha16,
  x : Int,
  y : Int,
  c : @color.Alpha16
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix[i] = (c.a >> 8).to_byte()
  self.pix[i + 1] = c.a.to_byte()
}

///|
pub fn new_image_alpha16(r : Rectangle) -> ImageAlpha16 {
  let len = pixel_buffer_length(2, r, "Alpha16")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 2 * r.dx(),
    rect: r,
  }
}

///|
pub(all) struct ImageGray {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageGray::pix_offset(self : ImageGray, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride + (x - self.rect.min.x)
}

///|
pub fn ImageGray::gray_at(self : ImageGray, x : Int, y : Int) -> @color.Gray {
  if !({ x, y } : Point).in_(self.rect) {
    return { y: b'\x00' }
  }
  let i = self.pix_offset(x, y)
  { y: self.pix[i] }
}

///|
pub fn ImageGray::set_gray(
  self : ImageGray,
  x : Int,
  y : Int,
  c : @color.Gray
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  self.pix[self.pix_offset(x, y)] = c.y
}

///|
pub fn new_image_gray(r : Rectangle) -> ImageGray {
  let len = pixel_buffer_length(1, r, "Gray")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: r.dx(),
    rect: r,
  }
}

///|
pub(all) struct ImageGray16 {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageGray16::pix_offset(self : ImageGray16, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride +
  (x - self.rect.min.x) * 2
}

///|
pub fn ImageGray16::gray16_at(
  self : ImageGray16,
  x : Int,
  y : Int
) -> @color.Gray16 {
  if !({ x, y } : Point).in_(self.rect) {
    return { y: 0U }
  }
  let i = self.pix_offset(x, y)
  { y: (self.pix[i].to_uint() << 8) | self.pix[i + 1].to_uint() }
}

///|
pub fn ImageGray16::set_gray16(
  self : ImageGray16,
  x : Int,
  y : Int,
  c : @color.Gray16
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  let i = self.pix_offset(x, y)
  self.pix[i] = (c.y >> 8).to_byte()
  self.pix[i + 1] = c.y.to_byte()
}

///|
pub fn new_image_gray16(r : Rectangle) -> ImageGray16 {
  let len = pixel_buffer_length(2, r, "Gray16")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: 2 * r.dx(),
    rect: r,
  }
}

///|
pub(all) struct ImagePaletted {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
  palette : @color.Palette
}

///|
pub fn ImagePaletted::pix_offset(self : ImagePaletted, x : Int, y : Int) -> Int {
  self.pix_offset + (y - self.rect.min.y) * self.stride + (x - self.rect.min.x)
}

///|
pub fn ImagePaletted::at(self : ImagePaletted, x : Int, y : Int) -> @color.AnyColor {
  if self.palette.colors.is_empty() {
    return @color.AnyColor::RGBA({ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' })
  }
  if !({ x, y } : Point).in_(self.rect) {
    return self.palette.colors[0]
  }
  let idx = self.pix[self.pix_offset(x, y)].to_int()
  self.palette.colors[idx]
}

///|
pub fn ImagePaletted::color_index_at(
  self : ImagePaletted,
  x : Int,
  y : Int
) -> Byte {
  if !({ x, y } : Point).in_(self.rect) {
    return b'\x00'
  }
  self.pix[self.pix_offset(x, y)]
}

///|
pub fn ImagePaletted::set_color_index(
  self : ImagePaletted,
  x : Int,
  y : Int,
  index : Byte
) -> Unit {
  if !({ x, y } : Point).in_(self.rect) {
    return
  }
  self.pix[self.pix_offset(x, y)] = index
}

///|
pub fn new_image_paletted(r : Rectangle, p : @color.Palette) -> ImagePaletted {
  let len = pixel_buffer_length(1, r, "Paletted")
  {
    pix: FixedArray::make(len, b'\x00'),
    pix_offset: 0,
    stride: r.dx(),
    rect: r,
    palette: p,
  }
}
