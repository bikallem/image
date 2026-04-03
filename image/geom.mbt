///|
/// A Point is an X, Y coordinate pair. The axes increase right and down.
#valtype
pub(all) struct Point {
  x : Int
  y : Int
} derive(Eq, Debug)

///|
pub fn Point::add(self : Point, q : Point) -> Point {
  { x: self.x + q.x, y: self.y + q.y }
}

///|
pub fn Point::sub(self : Point, q : Point) -> Point {
  { x: self.x - q.x, y: self.y - q.y }
}

///|
pub fn Point::mul(self : Point, k : Int) -> Point {
  { x: self.x * k, y: self.y * k }
}

///|
pub fn Point::div(self : Point, k : Int) -> Point {
  { x: self.x / k, y: self.y / k }
}

///|
pub fn Point::in_(self : Point, r : Rectangle) -> Bool {
  r.min_x <= self.x && self.x < r.max_x && r.min_y <= self.y && self.y < r.max_y
}

///|
pub fn Point::mod(self : Point, r : Rectangle) -> Point {
  let w = r.dx()
  let h = r.dy()
  let p = self.sub(r.min())
  let px = if p.x % w < 0 { p.x % w + w } else { p.x % w }
  let py = if p.y % h < 0 { p.y % h + h } else { p.y % h }
  { x: px + r.min_x, y: py + r.min_y }
}

///|
pub fn pt(x : Int, y : Int) -> Point {
  { x, y }
}

///|
/// A Rectangle contains the points with Min.X <= X < Max.X, Min.Y <= Y < Max.Y.
#valtype
pub(all) struct Rectangle {
  min_x : Int
  min_y : Int
  max_x : Int
  max_y : Int
} derive(Eq, Debug)

///|
pub impl Show for Rectangle with output(self, logger) {
  logger.write_string(
    "(\{self.min_x},\{self.min_y})-(\{self.max_x},\{self.max_y})",
  )
}

///|
pub fn Rectangle::min(self : Rectangle) -> Point {
  { x: self.min_x, y: self.min_y }
}

///|
pub fn Rectangle::max(self : Rectangle) -> Point {
  { x: self.max_x, y: self.max_y }
}

///|
pub fn Rectangle::dx(self : Rectangle) -> Int {
  self.max_x - self.min_x
}

///|
pub fn Rectangle::dy(self : Rectangle) -> Int {
  self.max_y - self.min_y
}

///|
pub fn Rectangle::size(self : Rectangle) -> Point {
  { x: self.max_x - self.min_x, y: self.max_y - self.min_y }
}

///|
pub fn Rectangle::add(self : Rectangle, p : Point) -> Rectangle {
  {
    min_x: self.min_x + p.x,
    min_y: self.min_y + p.y,
    max_x: self.max_x + p.x,
    max_y: self.max_y + p.y,
  }
}

///|
pub fn Rectangle::sub(self : Rectangle, p : Point) -> Rectangle {
  {
    min_x: self.min_x - p.x,
    min_y: self.min_y - p.y,
    max_x: self.max_x - p.x,
    max_y: self.max_y - p.y,
  }
}

///|
pub fn Rectangle::inset(self : Rectangle, n : Int) -> Rectangle {
  let (min_x, max_x) = if self.dx() < 2 * n {
    let mid = (self.min_x + self.max_x) / 2
    (mid, mid)
  } else {
    (self.min_x + n, self.max_x - n)
  }
  let (min_y, max_y) = if self.dy() < 2 * n {
    let mid = (self.min_y + self.max_y) / 2
    (mid, mid)
  } else {
    (self.min_y + n, self.max_y - n)
  }
  { min_x, min_y, max_x, max_y }
}

///|
pub fn Rectangle::intersect(self : Rectangle, s : Rectangle) -> Rectangle {
  let r : Rectangle = {
    min_x: if self.min_x > s.min_x {
      self.min_x
    } else {
      s.min_x
    },
    min_y: if self.min_y > s.min_y {
      self.min_y
    } else {
      s.min_y
    },
    max_x: if self.max_x < s.max_x {
      self.max_x
    } else {
      s.max_x
    },
    max_y: if self.max_y < s.max_y {
      self.max_y
    } else {
      s.max_y
    },
  }
  if r.empty() {
    { min_x: 0, min_y: 0, max_x: 0, max_y: 0 }
  } else {
    r
  }
}

///|
pub fn Rectangle::union(self : Rectangle, s : Rectangle) -> Rectangle {
  if self.empty() {
    return s
  }
  if s.empty() {
    return self
  }
  {
    min_x: if self.min_x < s.min_x {
      self.min_x
    } else {
      s.min_x
    },
    min_y: if self.min_y < s.min_y {
      self.min_y
    } else {
      s.min_y
    },
    max_x: if self.max_x > s.max_x {
      self.max_x
    } else {
      s.max_x
    },
    max_y: if self.max_y > s.max_y {
      self.max_y
    } else {
      s.max_y
    },
  }
}

///|
pub fn Rectangle::empty(self : Rectangle) -> Bool {
  self.min_x >= self.max_x || self.min_y >= self.max_y
}

///|
pub fn Rectangle::eq(self : Rectangle, s : Rectangle) -> Bool {
  self == s || (self.empty() && s.empty())
}

///|
pub fn Rectangle::overlaps(self : Rectangle, s : Rectangle) -> Bool {
  !self.empty() &&
  !s.empty() &&
  self.min_x < s.max_x &&
  s.min_x < self.max_x &&
  self.min_y < s.max_y &&
  s.min_y < self.max_y
}

///|
pub fn Rectangle::in_(self : Rectangle, s : Rectangle) -> Bool {
  if self.empty() {
    return true
  }
  s.min_x <= self.min_x &&
  self.max_x <= s.max_x &&
  s.min_y <= self.min_y &&
  self.max_y <= s.max_y
}

///|
pub fn Rectangle::canon(self : Rectangle) -> Rectangle {
  let (min_x, max_x) = if self.max_x < self.min_x {
    (self.max_x, self.min_x)
  } else {
    (self.min_x, self.max_x)
  }
  let (min_y, max_y) = if self.max_y < self.min_y {
    (self.max_y, self.min_y)
  } else {
    (self.min_y, self.max_y)
  }
  { min_x, min_y, max_x, max_y }
}

///|
pub fn rect(x0 : Int, y0 : Int, x1 : Int, y1 : Int) -> Rectangle {
  let (x0, x1) = if x0 > x1 { (x1, x0) } else { (x0, x1) }
  let (y0, y1) = if y0 > y1 { (y1, y0) } else { (y0, y1) }
  { min_x: x0, min_y: y0, max_x: x1, max_y: y1 }
}

///|
fn mul3_non_neg(x : Int, y : Int, z : Int) -> Int {
  if x < 0 || y < 0 || z < 0 {
    return -1
  }
  // Simple overflow check for 32-bit
  let xy = x * y
  if x != 0 && xy / x != y {
    return -1
  }
  let xyz = xy * z
  if xy != 0 && xyz / xy != z {
    return -1
  }
  if xyz < 0 {
    return -1
  }
  xyz
}

///|
fn add2_non_neg(x : Int, y : Int) -> Int {
  if x < 0 || y < 0 {
    return -1
  }
  let a = x + y
  if a < 0 {
    return -1
  }
  a
}

///|
pub fn pixel_buffer_length(
  bytes_per_pixel : Int,
  r : Rectangle,
  image_type_name : String,
) -> Int {
  let total_length = mul3_non_neg(bytes_per_pixel, r.dx(), r.dy())
  if total_length < 0 {
    abort(
      "image: New" +
      image_type_name +
      " Rectangle has huge or negative dimensions",
    )
  }
  total_length
}
