///|
/// A Point is an X, Y coordinate pair. The axes increase right and down.
#valtype
pub(all) struct Point {
  x : Int
  y : Int
} derive(Eq, Show)

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
  r.min.x <= self.x && self.x < r.max.x && r.min.y <= self.y && self.y < r.max.y
}

///|
pub fn Point::mod(self : Point, r : Rectangle) -> Point {
  let w = r.dx()
  let h = r.dy()
  let p = self.sub(r.min)
  let mut px = p.x % w
  if px < 0 {
    px = px + w
  }
  let mut py = p.y % h
  if py < 0 {
    py = py + h
  }
  { x: px, y: py }.add(r.min)
}

///|
pub fn pt(x : Int, y : Int) -> Point {
  { x, y }
}

///|
/// A Rectangle contains the points with Min.X <= X < Max.X, Min.Y <= Y < Max.Y.
pub(all) struct Rectangle {
  min : Point
  max : Point
} derive(Eq, Show)

///|
pub fn Rectangle::dx(self : Rectangle) -> Int {
  self.max.x - self.min.x
}

///|
pub fn Rectangle::dy(self : Rectangle) -> Int {
  self.max.y - self.min.y
}

///|
pub fn Rectangle::size(self : Rectangle) -> Point {
  { x: self.max.x - self.min.x, y: self.max.y - self.min.y }
}

///|
pub fn Rectangle::add(self : Rectangle, p : Point) -> Rectangle {
  {
    min: { x: self.min.x + p.x, y: self.min.y + p.y },
    max: { x: self.max.x + p.x, y: self.max.y + p.y },
  }
}

///|
pub fn Rectangle::sub(self : Rectangle, p : Point) -> Rectangle {
  {
    min: { x: self.min.x - p.x, y: self.min.y - p.y },
    max: { x: self.max.x - p.x, y: self.max.y - p.y },
  }
}

///|
pub fn Rectangle::inset(self : Rectangle, n : Int) -> Rectangle {
  let mut min_x = self.min.x
  let mut min_y = self.min.y
  let mut max_x = self.max.x
  let mut max_y = self.max.y
  if self.dx() < 2 * n {
    min_x = (self.min.x + self.max.x) / 2
    max_x = min_x
  } else {
    min_x = min_x + n
    max_x = max_x - n
  }
  if self.dy() < 2 * n {
    min_y = (self.min.y + self.max.y) / 2
    max_y = min_y
  } else {
    min_y = min_y + n
    max_y = max_y - n
  }
  { min: { x: min_x, y: min_y }, max: { x: max_x, y: max_y } }
}

///|
pub fn Rectangle::intersect(self : Rectangle, s : Rectangle) -> Rectangle {
  let mut min_x = self.min.x
  let mut min_y = self.min.y
  let mut max_x = self.max.x
  let mut max_y = self.max.y
  if min_x < s.min.x {
    min_x = s.min.x
  }
  if min_y < s.min.y {
    min_y = s.min.y
  }
  if max_x > s.max.x {
    max_x = s.max.x
  }
  if max_y > s.max.y {
    max_y = s.max.y
  }
  let r : Rectangle = {
    min: { x: min_x, y: min_y },
    max: { x: max_x, y: max_y },
  }
  if r.empty() {
    return { min: { x: 0, y: 0 }, max: { x: 0, y: 0 } }
  }
  r
}

///|
pub fn Rectangle::union(self : Rectangle, s : Rectangle) -> Rectangle {
  if self.empty() {
    return s
  }
  if s.empty() {
    return self
  }
  let mut min_x = self.min.x
  let mut min_y = self.min.y
  let mut max_x = self.max.x
  let mut max_y = self.max.y
  if min_x > s.min.x {
    min_x = s.min.x
  }
  if min_y > s.min.y {
    min_y = s.min.y
  }
  if max_x < s.max.x {
    max_x = s.max.x
  }
  if max_y < s.max.y {
    max_y = s.max.y
  }
  { min: { x: min_x, y: min_y }, max: { x: max_x, y: max_y } }
}

///|
pub fn Rectangle::empty(self : Rectangle) -> Bool {
  self.min.x >= self.max.x || self.min.y >= self.max.y
}

///|
pub fn Rectangle::eq(self : Rectangle, s : Rectangle) -> Bool {
  self == s || (self.empty() && s.empty())
}

///|
pub fn Rectangle::overlaps(self : Rectangle, s : Rectangle) -> Bool {
  !self.empty() &&
  !s.empty() &&
  self.min.x < s.max.x &&
  s.min.x < self.max.x &&
  self.min.y < s.max.y &&
  s.min.y < self.max.y
}

///|
pub fn Rectangle::in_(self : Rectangle, s : Rectangle) -> Bool {
  if self.empty() {
    return true
  }
  s.min.x <= self.min.x &&
  self.max.x <= s.max.x &&
  s.min.y <= self.min.y &&
  self.max.y <= s.max.y
}

///|
pub fn Rectangle::canon(self : Rectangle) -> Rectangle {
  let mut min_x = self.min.x
  let mut min_y = self.min.y
  let mut max_x = self.max.x
  let mut max_y = self.max.y
  if max_x < min_x {
    let tmp = min_x
    min_x = max_x
    max_x = tmp
  }
  if max_y < min_y {
    let tmp = min_y
    min_y = max_y
    max_y = tmp
  }
  { min: { x: min_x, y: min_y }, max: { x: max_x, y: max_y } }
}

///|
pub fn rect(x0 : Int, y0 : Int, x1 : Int, y1 : Int) -> Rectangle {
  let (x0, x1) = if x0 > x1 { (x1, x0) } else { (x0, x1) }
  let (y0, y1) = if y0 > y1 { (y1, y0) } else { (y0, y1) }
  { min: { x: x0, y: y0 }, max: { x: x1, y: y1 } }
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
