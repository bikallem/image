///|
/// Paeth filter predictor: returns the value nearest to p = a + b - c.
pub fn paeth(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = if p >= a { p - a } else { a - p }
  let pb = if p >= b { p - b } else { b - p }
  let pc = if p >= c { p - c } else { c - p }
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}
