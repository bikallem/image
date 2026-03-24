///|
/// Loeffler IDCT — direct port of Go's image/jpeg/dct.go (2025).
/// Input: block[64] of dequantized coefficients in natural order.
/// Output: dst[64] of pixel bytes [0,255] after +128 level shift.

// dctBox: 3-multiply rotation+scaling.
fn dct_box(x0 : Int, x1 : Int, kcos : Int, ksin : Int) -> (Int, Int) {
  let ksum = kcos * (x0 + x1)
  (ksum + (ksin - kcos) * x1, ksum - (kcos + ksin) * x0)
}

///|
fn idct_clamp_byte(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
/// Inverse DCT. Input block in natural (row-major) order.
/// Output dst as 64 clamped bytes [0,255].
pub fn idct(block : FixedArray[Int], dst : FixedArray[Byte]) -> Unit {
  // idctRows: input UQ8.0, output Q9.20 (in-place on block).
  for i in 0..<8 {
    let base = 8 * i
    // Note: input is in permuted order from FDCT output.
    let mut x0 = block.unsafe_get(base)
    let mut x7 = block.unsafe_get(base + 1)
    let mut x2 = block.unsafe_get(base + 2)
    let mut x5 = block.unsafe_get(base + 3)
    let mut x1 = block.unsafe_get(base + 4)
    let mut x6 = block.unsafe_get(base + 5)
    let mut x3 = block.unsafe_get(base + 6)
    let mut x4 = block.unsafe_get(base + 7)
    // Stages 4, 3, 2: x0..x3
    x0 = x0 << 17
    x1 = x1 << 17
    let (a, b) = (x0 + x1, x0 - x1)
    x0 = a; x1 = b
    let (a, b) = dct_box(x2, x3, 70936, -171254) // sqrt2inv_cos6, -sqrt2inv_sin6 @18bit
    x2 = a; x3 = b
    let (a, b) = (x1 + x2, x1 - x2)
    x1 = a; x2 = b
    let (a, b) = (x0 + x3, x0 - x3)
    x0 = a; x3 = b
    // Stages 4, 3, 2: x4..x7
    x4 = x4 << 7
    x7 = x7 << 7
    let (a, b) = (x7 + x4, x7 - x4)
    x7 = a; x4 = b
    x6 = x6 * 181  // sqrt2inv @8bit
    x5 = x5 * 181
    let (a, b) = (x7 + x5, x7 - x5)
    x7 = a; x5 = b
    let (a, b) = (x4 + x6, x4 - x6)
    x4 = a; x6 = b
    let (a, b) = dct_box(x4 >> 2, x7 >> 2, 3406, -2276) // cos3, -sin3 @12bit
    x4 = a; x7 = b
    let (a, b) = dct_box(x5 >> 2, x6 >> 2, 4017, -799) // cos1, -sin1 @12bit
    x5 = a; x6 = b
    // Stage 1
    let (a, b) = (x0 + x7, x0 - x7)
    x0 = a; x7 = b
    let (a, b) = (x1 + x6, x1 - x6)
    x1 = a; x6 = b
    let (a, b) = (x2 + x5, x2 - x5)
    x2 = a; x5 = b
    let (a, b) = (x3 + x4, x3 - x4)
    x3 = a; x4 = b
    // Store
    block.unsafe_set(base, x0)
    block.unsafe_set(base + 1, x1)
    block.unsafe_set(base + 2, x2)
    block.unsafe_set(base + 3, x3)
    block.unsafe_set(base + 4, x4)
    block.unsafe_set(base + 5, x5)
    block.unsafe_set(base + 6, x6)
    block.unsafe_set(base + 7, x7)
  }
  // idctCols: input Q9.20, output Q10.3. Then +128 level shift and clamp.
  for i in 0..<8 {
    let mut x0 = block.unsafe_get(0 * 8 + i)
    let mut x7 = block.unsafe_get(1 * 8 + i)
    let mut x2 = block.unsafe_get(2 * 8 + i)
    let mut x5 = block.unsafe_get(3 * 8 + i)
    let mut x1 = block.unsafe_get(4 * 8 + i)
    let mut x6 = block.unsafe_get(5 * 8 + i)
    let mut x3 = block.unsafe_get(6 * 8 + i)
    let mut x4 = block.unsafe_get(7 * 8 + i)
    // Add 0.5 for rounding (in Q9.20, 0.5 = 1<<19)
    x0 = x0 + (1 << 19)
    // Stages 4,3,2: x0..x3
    let (a, b) = ((x0 + x1) >> 2, (x0 - x1) >> 2)
    x0 = a; x1 = b
    let (a, b) = dct_box(x2 >> 13, x3 >> 13, 1108, -2676) // sqrt2inv_cos6, -sqrt2inv_sin6 @12bit
    x2 = a; x3 = b
    let (a, b) = (x1 + x2, x1 - x2)
    x1 = a; x2 = b
    let (a, b) = (x0 + x3, x0 - x3)
    x0 = a; x3 = b
    // Stages 4,3,2: x4..x7
    let (a, b) = (x7 + x4, x7 - x4)
    x7 = a; x4 = b
    x5 = (x5 >> 13) * 11585 // sqrt2inv @14bit
    x6 = (x6 >> 13) * 11585
    let (a, b) = (x7 + x5, x7 - x5)
    x7 = a; x5 = b
    let (a, b) = (x4 + x6, x4 - x6)
    x4 = a; x6 = b
    let (a, b) = dct_box(x4 >> 14, x7 >> 14, 3406, -2276) // cos3, -sin3 @12bit
    x4 = a; x7 = b
    let (a, b) = dct_box(x5 >> 14, x6 >> 14, 4017, -799) // cos1, -sin1 @12bit
    x5 = a; x6 = b
    // Stage 1
    let (a, b) = (x0 + x7, x0 - x7)
    x0 = a; x7 = b
    let (a, b) = (x1 + x6, x1 - x6)
    x1 = a; x6 = b
    let (a, b) = (x2 + x5, x2 - x5)
    x2 = a; x5 = b
    let (a, b) = (x3 + x4, x3 - x4)
    x3 = a; x4 = b
    // Cut Q10.21 → Q10.3 by >>18, then +128 level shift and clamp
    dst.unsafe_set(0 * 8 + i, idct_clamp_byte((x0 >> 18) + 128))
    dst.unsafe_set(1 * 8 + i, idct_clamp_byte((x1 >> 18) + 128))
    dst.unsafe_set(2 * 8 + i, idct_clamp_byte((x2 >> 18) + 128))
    dst.unsafe_set(3 * 8 + i, idct_clamp_byte((x3 >> 18) + 128))
    dst.unsafe_set(4 * 8 + i, idct_clamp_byte((x4 >> 18) + 128))
    dst.unsafe_set(5 * 8 + i, idct_clamp_byte((x5 >> 18) + 128))
    dst.unsafe_set(6 * 8 + i, idct_clamp_byte((x6 >> 18) + 128))
    dst.unsafe_set(7 * 8 + i, idct_clamp_byte((x7 >> 18) + 128))
  }
}
