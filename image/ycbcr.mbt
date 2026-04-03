///|
pub(all) enum YCbCrSubsampleRatio {
  Ratio444
  Ratio422
  Ratio420
  Ratio440
  Ratio411
  Ratio410
} derive(Eq, Debug)

///|
pub(all) struct ImageYCbCr {
  y_ : FixedArray[Byte]
  cb : FixedArray[Byte]
  cr : FixedArray[Byte]
  y_stride : Int
  c_stride : Int
  subsample_ratio : YCbCrSubsampleRatio
  rect : Rectangle
  y_offset_base : Int
  c_offset_base : Int
}

///|
pub fn ImageYCbCr::y_offset(self : ImageYCbCr, x : Int, y : Int) -> Int {
  self.y_offset_base +
  (y - self.rect.min_y) * self.y_stride +
  (x - self.rect.min_x)
}

///|
pub fn ImageYCbCr::c_offset(self : ImageYCbCr, x : Int, y : Int) -> Int {
  self.c_offset_base +
  (match self.subsample_ratio {
    Ratio422 =>
      (y - self.rect.min_y) * self.c_stride + (x / 2 - self.rect.min_x / 2)
    Ratio420 =>
      (y / 2 - self.rect.min_y / 2) * self.c_stride +
      (x / 2 - self.rect.min_x / 2)
    Ratio440 =>
      (y / 2 - self.rect.min_y / 2) * self.c_stride + (x - self.rect.min_x)
    Ratio411 =>
      (y - self.rect.min_y) * self.c_stride + (x / 4 - self.rect.min_x / 4)
    Ratio410 =>
      (y / 2 - self.rect.min_y / 2) * self.c_stride +
      (x / 4 - self.rect.min_x / 4)
    Ratio444 => (y - self.rect.min_y) * self.c_stride + (x - self.rect.min_x)
  })
}

///|
pub fn ImageYCbCr::ycbcr_at(
  self : ImageYCbCr,
  x : Int,
  y : Int,
) -> @color.YCbCr {
  let r = self.rect
  if x < r.min_x || x >= r.max_x || y < r.min_y || y >= r.max_y {
    return { y: b'\x00', cb: b'\x00', cr: b'\x00' }
  }
  let yi = self.y_offset(x, y)
  let ci = self.c_offset(x, y)
  { y: self.y_.unsafe_get(yi), cb: self.cb[ci], cr: self.cr[ci] }
}

///|
pub fn ImageYCbCr::is_opaque(_self : ImageYCbCr) -> Bool {
  true
}

///|
pub fn ImageYCbCr::sub_image(self : ImageYCbCr, r : Rectangle) -> ImageYCbCr {
  let r = r.intersect(self.rect)
  if r.empty() {
    return {
      y_: FixedArray::make(0, b'\x00'),
      cb: FixedArray::make(0, b'\x00'),
      cr: FixedArray::make(0, b'\x00'),
      y_stride: self.y_stride,
      c_stride: self.c_stride,
      subsample_ratio: self.subsample_ratio,
      rect: r,
      y_offset_base: 0,
      c_offset_base: 0,
    }
  }
  // YCbCr sub-images share the same underlying buffers with adjusted bases.
  {
    y_: self.y_,
    cb: self.cb,
    cr: self.cr,
    y_stride: self.y_stride,
    c_stride: self.c_stride,
    subsample_ratio: self.subsample_ratio,
    rect: r,
    y_offset_base: self.y_offset(r.min_x, r.min_y),
    c_offset_base: self.c_offset(r.min_x, r.min_y),
  }
}

///|
fn ycbcr_size(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio,
) -> (Int, Int, Int, Int) {
  let w = r.dx()
  let h = r.dy()
  let (cw, ch) = match subsample_ratio {
    Ratio422 => ((r.max_x + 1) / 2 - r.min_x / 2, h)
    Ratio420 =>
      ((r.max_x + 1) / 2 - r.min_x / 2, (r.max_y + 1) / 2 - r.min_y / 2)
    Ratio440 => (w, (r.max_y + 1) / 2 - r.min_y / 2)
    Ratio411 => ((r.max_x + 3) / 4 - r.min_x / 4, h)
    Ratio410 =>
      ((r.max_x + 3) / 4 - r.min_x / 4, (r.max_y + 1) / 2 - r.min_y / 2)
    Ratio444 => (w, h)
  }
  (w, h, cw, ch)
}

///|
pub fn new_image_ycbcr(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio,
) -> ImageYCbCr {
  let (w, h, cw, ch) = ycbcr_size(r, subsample_ratio)
  let total = add2_non_neg(mul3_non_neg(1, w, h), mul3_non_neg(2, cw, ch))
  if total < 0 {
    abort("image: NewYCbCr Rectangle has huge or negative dimensions")
  }
  {
    y_: FixedArray::make(w * h, b'\x00'),
    cb: FixedArray::make(cw * ch, b'\x00'),
    cr: FixedArray::make(cw * ch, b'\x00'),
    y_stride: w,
    c_stride: cw,
    subsample_ratio,
    rect: r,
    y_offset_base: 0,
    c_offset_base: 0,
  }
}

///|
pub(all) struct ImageNYCbCrA {
  ycbcr : ImageYCbCr
  a : FixedArray[Byte]
  a_stride : Int
  a_offset_base : Int
}

///|
pub fn ImageNYCbCrA::nycbcra_at(
  self : ImageNYCbCrA,
  x : Int,
  y : Int,
) -> @color.NYCbCrA {
  if !({ x, y } : Point).in_(self.ycbcr.rect) {
    return { y: b'\x00', cb: b'\x00', cr: b'\x00', a: b'\x00' }
  }
  let yi = self.ycbcr.y_offset(x, y)
  let ci = self.ycbcr.c_offset(x, y)
  let ai = self.a_offset(x, y)
  {
    y: self.ycbcr.y_.unsafe_get(yi),
    cb: self.ycbcr.cb.unsafe_get(ci),
    cr: self.ycbcr.cr.unsafe_get(ci),
    a: self.a.unsafe_get(ai),
  }
}

///|
pub fn ImageNYCbCrA::a_offset(self : ImageNYCbCrA, x : Int, y : Int) -> Int {
  self.a_offset_base +
  (y - self.ycbcr.rect.min_y) * self.a_stride +
  (x - self.ycbcr.rect.min_x)
}

///|
pub fn ImageNYCbCrA::sub_image(
  self : ImageNYCbCrA,
  r : Rectangle,
) -> ImageNYCbCrA {
  let r = r.intersect(self.ycbcr.rect)
  let ycbcr = self.ycbcr.sub_image(r)
  if r.empty() {
    return {
      ycbcr,
      a: FixedArray::make(0, b'\x00'),
      a_stride: self.a_stride,
      a_offset_base: 0,
    }
  }
  {
    ycbcr,
    a: self.a,
    a_stride: self.a_stride,
    a_offset_base: self.a_offset(r.min_x, r.min_y),
  }
}

///|
pub fn ImageNYCbCrA::is_opaque(self : ImageNYCbCrA) -> Bool {
  if self.ycbcr.rect.empty() {
    return true
  }
  for y = self.ycbcr.rect.min_y; y < self.ycbcr.rect.max_y; y = y + 1 {
    let row_start = self.a_offset_base +
      (y - self.ycbcr.rect.min_y) * self.a_stride
    for x in 0..<self.ycbcr.rect.dx() {
      if self.a.unsafe_get(row_start + x) != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub impl Image for ImageYCbCr with color_model(_self) -> &@color.Model {
  @color.YCbCrModel::{  }
}

///|
pub impl Image for ImageYCbCr with bounds(self) -> Rectangle {
  self.rect
}

///|
pub impl Image for ImageYCbCr with at(self, x, y) -> &@color.Color {
  self.ycbcr_at(x, y)
}

///|
pub impl Image for ImageYCbCr with set(self, _x, _y, _c) -> Unit {
  ignore(self)
}

///|
pub impl Image for ImageNYCbCrA with color_model(_self) -> &@color.Model {
  @color.NYCbCrAModel::{  }
}

///|
pub impl Image for ImageNYCbCrA with bounds(self) -> Rectangle {
  self.ycbcr.rect
}

///|
pub impl Image for ImageNYCbCrA with at(self, x, y) -> &@color.Color {
  self.nycbcra_at(x, y)
}

///|
pub impl Image for ImageNYCbCrA with set(self, _x, _y, _c) -> Unit {
  ignore(self)
}

///|
pub fn new_image_nycbcra(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio,
) -> ImageNYCbCrA {
  let (w, h, cw, ch) = ycbcr_size(r, subsample_ratio)
  ignore(add2_non_neg(mul3_non_neg(2, w, h), mul3_non_neg(2, cw, ch)))
  {
    ycbcr: {
      y_: FixedArray::make(w * h, b'\x00'),
      cb: FixedArray::make(cw * ch, b'\x00'),
      cr: FixedArray::make(cw * ch, b'\x00'),
      y_stride: w,
      c_stride: cw,
      subsample_ratio,
      rect: r,
      y_offset_base: 0,
      c_offset_base: 0,
    },
    a: FixedArray::make(w * h, b'\x00'),
    a_stride: w,
    a_offset_base: 0,
  }
}
