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
  (y - self.rect.min_y) * self.y_stride + (x - self.rect.min_x)
}

///|
pub fn ImageYCbCr::c_offset(self : ImageYCbCr, x : Int, y : Int) -> Int {
  match self.subsample_ratio {
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
    _ => (y - self.rect.min_y) * self.c_stride + (x - self.rect.min_x)
  }
}

///|
pub fn ImageYCbCr::ycbcr_at(
  self : ImageYCbCr,
  x : Int,
  y : Int,
) -> @color.YCbCr {
  if x < self.rect.min_x || x >= self.rect.max_x || y < self.rect.min_y || y >= self.rect.max_y {
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
    }
  }
  // YCbCr sub-images share the same underlying buffers
  // with adjusted rect (offsets computed on access via y_offset/c_offset)
  {
    y_: self.y_,
    cb: self.cb,
    cr: self.cr,
    y_stride: self.y_stride,
    c_stride: self.c_stride,
    subsample_ratio: self.subsample_ratio,
    rect: r,
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
    _ => (w, h)
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
  }
}

///|
pub fn new_image_ycbcr_separate(
  r : Rectangle,
  subsample_ratio : YCbCrSubsampleRatio,
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
  (y - self.ycbcr.rect.min_y) * self.a_stride + (x - self.ycbcr.rect.min_x)
}

///|
pub fn ImageNYCbCrA::sub_image(
  self : ImageNYCbCrA,
  r : Rectangle,
) -> ImageNYCbCrA {
  let r = r.intersect(self.ycbcr.rect)
  if r.empty() {
    return {
      ycbcr: {
        y_: FixedArray::make(0, b'\x00'),
        cb: FixedArray::make(0, b'\x00'),
        cr: FixedArray::make(0, b'\x00'),
        y_stride: self.ycbcr.y_stride,
        c_stride: self.ycbcr.c_stride,
        subsample_ratio: self.ycbcr.subsample_ratio,
        rect: r,
      },
      a: FixedArray::make(0, b'\x00'),
      a_stride: self.a_stride,
    }
  }
  {
    ycbcr: {
      y_: self.ycbcr.y_,
      cb: self.ycbcr.cb,
      cr: self.ycbcr.cr,
      y_stride: self.ycbcr.y_stride,
      c_stride: self.ycbcr.c_stride,
      subsample_ratio: self.ycbcr.subsample_ratio,
      rect: r,
    },
    a: self.a,
    a_stride: self.a_stride,
  }
}

///|
pub fn ImageNYCbCrA::is_opaque(self : ImageNYCbCrA) -> Bool {
  if self.ycbcr.rect.empty() {
    return true
  }
  for y = self.ycbcr.rect.min_y; y < self.ycbcr.rect.max_y; y = y + 1 {
    let row_start = (y - self.ycbcr.rect.min_y) * self.a_stride
    for x = 0; x < self.ycbcr.rect.dx(); x = x + 1 {
      if self.a.unsafe_get(row_start + x) != b'\xff' {
        return false
      }
    }
  }
  true
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
    },
    a: FixedArray::make(w * h, b'\x00'),
    a_stride: w,
  }
}
