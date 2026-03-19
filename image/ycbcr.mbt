///|
pub(all) enum YCbCrSubsampleRatio {
  Ratio444
  Ratio422
  Ratio420
  Ratio440
  Ratio411
  Ratio410
} derive(Eq, Show)

///|
pub(all) struct ImageYCbCr {
  y_ : FixedArray[Byte]
  cb : FixedArray[Byte]
  cr : FixedArray[Byte]
  y_stride : Int
  c_stride : Int
  subsample_ratio : YCbCrSubsampleRatio
  rect : Rectangle
}

///|
pub fn ImageYCbCr::y_offset(self : ImageYCbCr, x : Int, y : Int) -> Int {
  (y - self.rect.min.y) * self.y_stride + (x - self.rect.min.x)
}

///|
pub fn ImageYCbCr::c_offset(self : ImageYCbCr, x : Int, y : Int) -> Int {
  match self.subsample_ratio {
    Ratio422 =>
      (y - self.rect.min.y) * self.c_stride +
      (x / 2 - self.rect.min.x / 2)
    Ratio420 =>
      (y / 2 - self.rect.min.y / 2) * self.c_stride +
      (x / 2 - self.rect.min.x / 2)
    Ratio440 =>
      (y / 2 - self.rect.min.y / 2) * self.c_stride + (x - self.rect.min.x)
    Ratio411 =>
      (y - self.rect.min.y) * self.c_stride +
      (x / 4 - self.rect.min.x / 4)
    Ratio410 =>
      (y / 2 - self.rect.min.y / 2) * self.c_stride +
      (x / 4 - self.rect.min.x / 4)
    _ =>
      (y - self.rect.min.y) * self.c_stride + (x - self.rect.min.x)
  }
}

///|
pub fn ImageYCbCr::ycbcr_at(
  self : ImageYCbCr,
  x : Int,
  y : Int
) -> @color.YCbCr {
  if !({ x, y } : Point).in_(self.rect) {
    return { y: b'\x00', cb: b'\x00', cr: b'\x00' }
  }
  let yi = self.y_offset(x, y)
  let ci = self.c_offset(x, y)
  { y: self.y_[yi], cb: self.cb[ci], cr: self.cr[ci] }
}

///|
pub fn ImageYCbCr::is_opaque(_self : ImageYCbCr) -> Bool {
  true
}

///|
fn ycbcr_size(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio
) -> (Int, Int, Int, Int) {
  let w = r.dx()
  let h = r.dy()
  let (cw, ch) = match subsample_ratio {
    Ratio422 => ((r.max.x + 1) / 2 - r.min.x / 2, h)
    Ratio420 => ((r.max.x + 1) / 2 - r.min.x / 2, (r.max.y + 1) / 2 - r.min.y / 2)
    Ratio440 => (w, (r.max.y + 1) / 2 - r.min.y / 2)
    Ratio411 => ((r.max.x + 3) / 4 - r.min.x / 4, h)
    Ratio410 => ((r.max.x + 3) / 4 - r.min.x / 4, (r.max.y + 1) / 2 - r.min.y / 2)
    _ => (w, h)
  }
  (w, h, cw, ch)
}

///|
pub fn new_image_ycbcr(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio
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
  }
}

///|
pub fn new_image_ycbcr_separate(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio
) -> ImageYCbCr {
  let (w, h, cw, ch) = ycbcr_size(r, subsample_ratio)
  {
    y_: FixedArray::make(w * h, b'\x00'),
    cb: FixedArray::make(cw * ch, b'\x00'),
    cr: FixedArray::make(cw * ch, b'\x00'),
    y_stride: w,
    c_stride: cw,
    subsample_ratio,
    rect: r,
  }
}

///|
pub(all) struct ImageNYCbCrA {
  ycbcr : ImageYCbCr
  a : FixedArray[Byte]
  a_stride : Int
}

///|
pub fn ImageNYCbCrA::nycbcra_at(
  self : ImageNYCbCrA,
  x : Int,
  y : Int
) -> @color.NYCbCrA {
  if !({ x, y } : Point).in_(self.ycbcr.rect) {
    return { ycbcr: { y: b'\x00', cb: b'\x00', cr: b'\x00' }, a: b'\x00' }
  }
  let yi = self.ycbcr.y_offset(x, y)
  let ci = self.ycbcr.c_offset(x, y)
  let ai = self.a_offset(x, y)
  {
    ycbcr: { y: self.ycbcr.y_[yi], cb: self.ycbcr.cb[ci], cr: self.ycbcr.cr[ci] },
    a: self.a[ai],
  }
}

///|
pub fn ImageNYCbCrA::a_offset(self : ImageNYCbCrA, x : Int, y : Int) -> Int {
  (y - self.ycbcr.rect.min.y) * self.a_stride + (x - self.ycbcr.rect.min.x)
}

///|
pub fn ImageNYCbCrA::is_opaque(self : ImageNYCbCrA) -> Bool {
  if self.ycbcr.rect.empty() {
    return true
  }
  for y = self.ycbcr.rect.min.y; y < self.ycbcr.rect.max.y; y = y + 1 {
    let row_start = (y - self.ycbcr.rect.min.y) * self.a_stride
    for x = 0; x < self.ycbcr.rect.dx(); x = x + 1 {
      if self.a[row_start + x] != b'\xff' {
        return false
      }
    }
  }
  true
}

///|
pub fn new_image_nycbcra(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio
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
    },
    a: FixedArray::make(w * h, b'\x00'),
    a_stride: w,
  }
}
