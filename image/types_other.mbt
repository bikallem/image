///|
pub(all) struct ImageNRGBA {
  pix : FixedArray[Byte]
  pix_offset : Int
  stride : Int
  rect : Rectangle
}

///|
pub fn ImageNRGBA::pix_offset(self : ImageNRGBA, x : Int, y : Int) -> Int {
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 4
}

///|
#borrow(self)
pub fn ImageNRGBA::nrgba_at(
  self : ImageNRGBA,
  x : Int,
  y : Int,
) -> @color.NRGBA {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 4
  {
    r: self.pix.unsafe_get(i),
    g: self.pix.unsafe_get(i + 1),
    b: self.pix.unsafe_get(i + 2),
    a: self.pix.unsafe_get(i + 3),
  }
}

///|
pub fn ImageNRGBA::set_nrgba(
  self : ImageNRGBA,
  x : Int,
  y : Int,
  c : @color.NRGBA,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 4
  self.pix.unsafe_set(i, c.r)
  self.pix.unsafe_set(i + 1, c.g)
  self.pix.unsafe_set(i + 2, c.b)
  self.pix.unsafe_set(i + 3, c.a)
}

///|
pub fn ImageNRGBA::is_opaque(self : ImageNRGBA) -> Bool {
  if self.rect.empty() {
    return true
  }
  for y = self.rect.min_y; y < self.rect.max_y; y = y + 1 {
    let row_start = self.pix_offset + (y - self.rect.min_y) * self.stride
    for x in 0..<self.rect.dx() {
      if self.pix.unsafe_get(row_start + x * 4 + 3) != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn ImageNRGBA::set(
  self : ImageNRGBA,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (cr, cg, cb, ca) = c.rgba()
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 4
  if ca == 0xffffU {
    self.pix.unsafe_set(i, (cr >> 8).to_byte())
    self.pix.unsafe_set(i + 1, (cg >> 8).to_byte())
    self.pix.unsafe_set(i + 2, (cb >> 8).to_byte())
    self.pix.unsafe_set(i + 3, b'\xff')
  } else if ca == 0U {
    self.pix.unsafe_set(i, b'\x00')
    self.pix.unsafe_set(i + 1, b'\x00')
    self.pix.unsafe_set(i + 2, b'\x00')
    self.pix.unsafe_set(i + 3, b'\x00')
  } else {
    let nr = cr * 0xffffU / ca
    let ng = cg * 0xffffU / ca
    let nb = cb * 0xffffU / ca
    self.pix.unsafe_set(i, (nr >> 8).to_byte())
    self.pix.unsafe_set(i + 1, (ng >> 8).to_byte())
    self.pix.unsafe_set(i + 2, (nb >> 8).to_byte())
    self.pix.unsafe_set(i + 3, (ca >> 8).to_byte())
  }
}

///|
pub impl Image for ImageNRGBA with color_model(_self) -> &@color.Model {
  @color.NRGBAModel::{  }
}

///|
pub impl Image for ImageNRGBA with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageNRGBA with at(self, x, y) -> &@color.Color {
  self.nrgba_at(x, y)
}

///|
pub impl Image for ImageNRGBA with set(self, x, y, c) -> Unit {
  ImageNRGBA::set(self, x, y, c)
}

///|
pub fn ImageNRGBA::sub_image(self : ImageNRGBA, r : Rectangle) -> ImageNRGBA {
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
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 8
}

///|
#borrow(self)
pub fn ImageNRGBA64::nrgba64_at(
  self : ImageNRGBA64,
  x : Int,
  y : Int,
) -> @color.NRGBA64 {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { r: 0U, g: 0U, b: 0U, a: 0U }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 8
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
pub fn ImageNRGBA64::set_nrgba64(
  self : ImageNRGBA64,
  x : Int,
  y : Int,
  c : @color.NRGBA64,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 8
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
pub fn ImageNRGBA64::set(
  self : ImageNRGBA64,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (cr, cg, cb, ca) = c.rgba()
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 8
  if ca == 0xffffU {
    self.pix.unsafe_set(i, (cr >> 8).to_byte())
    self.pix.unsafe_set(i + 1, cr.to_byte())
    self.pix.unsafe_set(i + 2, (cg >> 8).to_byte())
    self.pix.unsafe_set(i + 3, cg.to_byte())
    self.pix.unsafe_set(i + 4, (cb >> 8).to_byte())
    self.pix.unsafe_set(i + 5, cb.to_byte())
    self.pix.unsafe_set(i + 6, b'\xff')
    self.pix.unsafe_set(i + 7, b'\xff')
  } else if ca == 0U {
    for j in 0..<8 {
      self.pix.unsafe_set(i + j, b'\x00')
    }
  } else {
    let nr = cr * 0xffffU / ca
    let ng = cg * 0xffffU / ca
    let nb = cb * 0xffffU / ca
    self.pix.unsafe_set(i, (nr >> 8).to_byte())
    self.pix.unsafe_set(i + 1, nr.to_byte())
    self.pix.unsafe_set(i + 2, (ng >> 8).to_byte())
    self.pix.unsafe_set(i + 3, ng.to_byte())
    self.pix.unsafe_set(i + 4, (nb >> 8).to_byte())
    self.pix.unsafe_set(i + 5, nb.to_byte())
    self.pix.unsafe_set(i + 6, (ca >> 8).to_byte())
    self.pix.unsafe_set(i + 7, ca.to_byte())
  }
}

///|
pub impl Image for ImageNRGBA64 with color_model(_self) -> &@color.Model {
  @color.NRGBA64Model::{  }
}

///|
pub impl Image for ImageNRGBA64 with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageNRGBA64 with at(self, x, y) -> &@color.Color {
  self.nrgba64_at(x, y)
}

///|
pub impl Image for ImageNRGBA64 with set(self, x, y, c) -> Unit {
  ImageNRGBA64::set(self, x, y, c)
}

///|
pub fn ImageNRGBA64::sub_image(
  self : ImageNRGBA64,
  r : Rectangle,
) -> ImageNRGBA64 {
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
  self.pix_offset + (y - self.rect.min_y) * self.stride + (x - self.rect.min_x)
}

///|
#borrow(self)
pub fn ImageAlpha::alpha_at(
  self : ImageAlpha,
  x : Int,
  y : Int,
) -> @color.Alpha {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { a: b'\x00' }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x)
  { a: self.pix.unsafe_get(i) }
}

///|
pub fn ImageAlpha::set_alpha(
  self : ImageAlpha,
  x : Int,
  y : Int,
  c : @color.Alpha,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  self.pix.unsafe_set(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
    c.a,
  )
}

///|
pub fn ImageAlpha::is_opaque(self : ImageAlpha) -> Bool {
  if self.rect.empty() {
    return true
  }
  for y = self.rect.min_y; y < self.rect.max_y; y = y + 1 {
    let row_start = self.pix_offset + (y - self.rect.min_y) * self.stride
    for x in 0..<self.rect.dx() {
      if self.pix.unsafe_get(row_start + x) != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn ImageAlpha::set(
  self : ImageAlpha,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (_, _, _, a) = c.rgba()
  self.pix.unsafe_set(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
    (a >> 8).to_byte(),
  )
}

///|
pub impl Image for ImageAlpha with color_model(_self) -> &@color.Model {
  @color.AlphaModel::{  }
}

///|
pub impl Image for ImageAlpha with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageAlpha with at(self, x, y) -> &@color.Color {
  self.alpha_at(x, y)
}

///|
pub impl Image for ImageAlpha with set(self, x, y, c) -> Unit {
  ImageAlpha::set(self, x, y, c)
}

///|
pub fn ImageAlpha::sub_image(self : ImageAlpha, r : Rectangle) -> ImageAlpha {
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
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 2
}

///|
#borrow(self)
pub fn ImageAlpha16::alpha16_at(
  self : ImageAlpha16,
  x : Int,
  y : Int,
) -> @color.Alpha16 {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { a: 0U }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 2
  {
    a: (self.pix.unsafe_get(i).to_uint() << 8) |
    self.pix.unsafe_get(i + 1).to_uint(),
  }
}

///|
pub fn ImageAlpha16::set_alpha16(
  self : ImageAlpha16,
  x : Int,
  y : Int,
  c : @color.Alpha16,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 2
  self.pix.unsafe_set(i, (c.a >> 8).to_byte())
  self.pix.unsafe_set(i + 1, c.a.to_byte())
}

///|
pub fn ImageAlpha16::set(
  self : ImageAlpha16,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (_, _, _, a) = c.rgba()
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 2
  self.pix.unsafe_set(i, (a >> 8).to_byte())
  self.pix.unsafe_set(i + 1, a.to_byte())
}

///|
pub impl Image for ImageAlpha16 with color_model(_self) -> &@color.Model {
  @color.Alpha16Model::{  }
}

///|
pub impl Image for ImageAlpha16 with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageAlpha16 with at(self, x, y) -> &@color.Color {
  self.alpha16_at(x, y)
}

///|
pub impl Image for ImageAlpha16 with set(self, x, y, c) -> Unit {
  ImageAlpha16::set(self, x, y, c)
}

///|
pub fn ImageAlpha16::sub_image(
  self : ImageAlpha16,
  r : Rectangle,
) -> ImageAlpha16 {
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
  self.pix_offset + (y - self.rect.min_y) * self.stride + (x - self.rect.min_x)
}

///|
#borrow(self)
pub fn ImageGray::gray_at(self : ImageGray, x : Int, y : Int) -> @color.Gray {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { y: b'\x00' }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x)
  { y: self.pix.unsafe_get(i) }
}

///|
pub fn ImageGray::set_gray(
  self : ImageGray,
  x : Int,
  y : Int,
  c : @color.Gray,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  self.pix.unsafe_set(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
    c.y,
  )
}

///|
pub fn ImageGray::set(
  self : ImageGray,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (cr, cg, cb, _) = c.rgba()
  let yy = (19595U * cr + 38470U * cg + 7471U * cb + (1U << 15)) >> 24
  self.pix.unsafe_set(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
    yy.to_byte(),
  )
}

///|
pub impl Image for ImageGray with color_model(_self) -> &@color.Model {
  @color.GrayModel::{  }
}

///|
pub impl Image for ImageGray with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageGray with at(self, x, y) -> &@color.Color {
  self.gray_at(x, y)
}

///|
pub impl Image for ImageGray with set(self, x, y, c) -> Unit {
  ImageGray::set(self, x, y, c)
}

///|
pub fn ImageGray::sub_image(self : ImageGray, r : Rectangle) -> ImageGray {
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
  self.pix_offset +
  (y - self.rect.min_y) * self.stride +
  (x - self.rect.min_x) * 2
}

///|
#borrow(self)
pub fn ImageGray16::gray16_at(
  self : ImageGray16,
  x : Int,
  y : Int,
) -> @color.Gray16 {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { y: 0U }
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 2
  {
    y: (self.pix.unsafe_get(i).to_uint() << 8) |
    self.pix.unsafe_get(i + 1).to_uint(),
  }
}

///|
pub fn ImageGray16::set_gray16(
  self : ImageGray16,
  x : Int,
  y : Int,
  c : @color.Gray16,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 2
  self.pix.unsafe_set(i, (c.y >> 8).to_byte())
  self.pix.unsafe_set(i + 1, c.y.to_byte())
}

///|
pub fn ImageGray16::set(
  self : ImageGray16,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let (cr, cg, cb, _) = c.rgba()
  let yy = (19595U * cr + 38470U * cg + 7471U * cb + (1U << 15)) >> 16
  let i = self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x) * 2
  self.pix.unsafe_set(i, (yy >> 8).to_byte())
  self.pix.unsafe_set(i + 1, yy.to_byte())
}

///|
pub impl Image for ImageGray16 with color_model(_self) -> &@color.Model {
  @color.Gray16Model::{  }
}

///|
pub impl Image for ImageGray16 with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageGray16 with at(self, x, y) -> &@color.Color {
  self.gray16_at(x, y)
}

///|
pub impl Image for ImageGray16 with set(self, x, y, c) -> Unit {
  ImageGray16::set(self, x, y, c)
}

///|
pub fn ImageGray16::sub_image(self : ImageGray16, r : Rectangle) -> ImageGray16 {
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
  self.pix_offset + (y - self.rect.min_y) * self.stride + (x - self.rect.min_x)
}

///|
pub fn ImagePaletted::at(
  self : ImagePaletted,
  x : Int,
  y : Int,
) -> &@color.Color {
  if self.palette.colors.is_empty() {
    return @color.RGBA::{ r: b'\x00', g: b'\x00', b: b'\x00', a: b'\x00' }
  }
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return self.palette.colors.unsafe_get(0)
  }
  let idx = self.pix
    .unsafe_get(self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x))
    .to_int()
  self.palette.colors.unsafe_get(idx)
}

///|
pub fn ImagePaletted::color_index_at(
  self : ImagePaletted,
  x : Int,
  y : Int,
) -> Byte {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return b'\x00'
  }
  self.pix.unsafe_get(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
  )
}

///|
pub fn ImagePaletted::set_color_index(
  self : ImagePaletted,
  x : Int,
  y : Int,
  index : Byte,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  self.pix.unsafe_set(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
    index,
  )
}

///|
pub fn ImagePaletted::set(
  self : ImagePaletted,
  x : Int,
  y : Int,
  c : &@color.Color,
) -> Unit {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return
  }
  let idx = self.palette.index(c)
  self.pix.unsafe_set(
    self.pix_offset + (y - r.min_y) * self.stride + (x - r.min_x),
    idx.to_byte(),
  )
}

///|
pub impl Image for ImagePaletted with color_model(self) -> &@color.Model {
  @color.PaletteModel::{ palette: self.palette }
}

///|
pub impl Image for ImagePaletted with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImagePaletted with at(self, x, y) -> &@color.Color {
  ImagePaletted::at(self, x, y)
}

///|
pub impl Image for ImagePaletted with set(self, x, y, c) -> Unit {
  ImagePaletted::set(self, x, y, c)
}

///|
pub fn ImagePaletted::sub_image(
  self : ImagePaletted,
  r : Rectangle,
) -> ImagePaletted {
  let r = r.intersect(self.rect)
  if r.empty() {
    return {
      pix: FixedArray::make(0, b'\x00'),
      pix_offset: 0,
      stride: self.stride,
      rect: r,
      palette: self.palette,
    }
  }
  let i = self.pix_offset(r.min_x, r.min_y)
  {
    pix: self.pix,
    pix_offset: i,
    stride: self.stride,
    rect: r,
    palette: self.palette,
  }
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
