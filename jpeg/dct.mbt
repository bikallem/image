///|
// IDCT constants scaled by sqrt(2)*2048
// These implement the AAN (Arai, Agui, Nakajima) fast IDCT algorithm
let w1 : Int = 2841

///|
let w2 : Int = 2676

///|
let w3 : Int = 2408

///|
let w5 : Int = 1609

///|
let w6 : Int = 1108

///|
let w7 : Int = 565

///|
// w1pw7 = w1 + w7
let w1pw7 : Int = w1 + w7

///|
// w1mw7 = w1 - w7
let w1mw7 : Int = w1 - w7

///|
// w3pw5 = w3 + w5
let w3pw5 : Int = w3 + w5

///|
// w3mw5 = w3 - w5
let w3mw5 : Int = w3 - w5

///|
// r2 = 181 (approximation of 128*sqrt(2))
let r2 : Int = 181

///|
/// Performs a 1D IDCT on an 8-element row of the block (in-place).
/// Input values are scaled by 8 (i.e., left-shifted by 3 relative to spec).
fn idct_1d(
  s0 : Int,
  s1 : Int,
  s2 : Int,
  s3 : Int,
  s4 : Int,
  s5 : Int,
  s6 : Int,
  s7 : Int
) -> (Int, Int, Int, Int, Int, Int, Int, Int) {
  // Even part
  let x0 = (s0 << 11) + 128
  let x1 = s4 << 11
  let x2 = s6 * w6 - s2 * w2
  let x3 = s2 * w6 + s6 * w2
  let x4 = s1 * w7 - s7 * w1
  let x5 = s7 * w7 + s1 * w1
  let x6 = s5 * w3 - s3 * w5
  let x7 = s3 * w3 + s5 * w5
  let x8 = x0 + x1
  let x9 = x0 - x1
  let x10 = x3 + x2
  let x11 = x3 - x2
  let x12 = ((x5 - x4) * r2 + 128) >> 8
  let x13 = ((x7 - x6) * r2 + 128) >> 8
  let x14 = x4 + x6
  let x15 = x5 + x7
  let p0 = (x8 + x10) >> 8
  let p1 = (x9 + x11) >> 8
  let p2 = (x9 - x11) >> 8
  let p3 = (x8 - x10) >> 8
  let p4 = (x14 + x15) >> 8
  let p5 = (x12 + x13) >> 8
  let p6 = (x13 - x12) >> 8
  let p7 = (x15 - x14) >> 8
  (p0 + p4, p1 + p5, p2 + p6, p3 + p7, p3 - p7, p2 - p6, p1 - p5, p0 - p4)
}

///|
/// Clamp an integer to [0, 255].
fn idct_clamp(x : Int) -> Byte {
  if x < 0 {
    b'\x00'
  } else if x > 255 {
    b'\xff'
  } else {
    x.to_byte()
  }
}

///|
/// Performs an 8x8 2D IDCT on a block of 64 Int coefficients (natural order).
/// Output is written to dst (64 bytes) with each sample clamped to [0,255]
/// and level-shifted by adding 128.
pub fn idct(block : FixedArray[Int], dst : FixedArray[Byte]) -> Unit {
  // Temporary buffer for row IDCT output
  let tmp = FixedArray::make(64, 0)
  // Row pass
  for y in 0..<8 {
    let base = y * 8
    let s0 = block[base]
    let s1 = block[base + 1]
    let s2 = block[base + 2]
    let s3 = block[base + 3]
    let s4 = block[base + 4]
    let s5 = block[base + 5]
    let s6 = block[base + 6]
    let s7 = block[base + 7]
    // If all AC terms are zero, shortcut
    if s1 == 0 && s2 == 0 && s3 == 0 && s4 == 0 && s5 == 0 && s6 == 0 &&
      s7 == 0 {
      let dc = (s0 << 3)
      tmp[base] = dc
      tmp[base + 1] = dc
      tmp[base + 2] = dc
      tmp[base + 3] = dc
      tmp[base + 4] = dc
      tmp[base + 5] = dc
      tmp[base + 6] = dc
      tmp[base + 7] = dc
    } else {
      let (r0, r1, r2v, r3, r4, r5, r6, r7) = idct_1d(
        s0, s1, s2, s3, s4, s5, s6, s7,
      )
      tmp[base] = r0
      tmp[base + 1] = r1
      tmp[base + 2] = r2v
      tmp[base + 3] = r3
      tmp[base + 4] = r4
      tmp[base + 5] = r5
      tmp[base + 6] = r6
      tmp[base + 7] = r7
    }
  }
  // Column pass
  for x in 0..<8 {
    let s0 = tmp[x]
    let s1 = tmp[8 + x]
    let s2 = tmp[16 + x]
    let s3 = tmp[24 + x]
    let s4 = tmp[32 + x]
    let s5 = tmp[40 + x]
    let s6 = tmp[48 + x]
    let s7 = tmp[56 + x]
    if s1 == 0 && s2 == 0 && s3 == 0 && s4 == 0 && s5 == 0 && s6 == 0 &&
      s7 == 0 {
      let dc = idct_clamp(((s0 + 16) >> 5) + 128)
      dst[x] = dc
      dst[8 + x] = dc
      dst[16 + x] = dc
      dst[24 + x] = dc
      dst[32 + x] = dc
      dst[40 + x] = dc
      dst[48 + x] = dc
      dst[56 + x] = dc
    } else {
      let (r0, r1, r2v, r3, r4, r5, r6, r7) = idct_1d(
        s0, s1, s2, s3, s4, s5, s6, s7,
      )
      dst[x] = idct_clamp(((r0 + 16) >> 5) + 128)
      dst[8 + x] = idct_clamp(((r1 + 16) >> 5) + 128)
      dst[16 + x] = idct_clamp(((r2v + 16) >> 5) + 128)
      dst[24 + x] = idct_clamp(((r3 + 16) >> 5) + 128)
      dst[32 + x] = idct_clamp(((r4 + 16) >> 5) + 128)
      dst[40 + x] = idct_clamp(((r5 + 16) >> 5) + 128)
      dst[48 + x] = idct_clamp(((r6 + 16) >> 5) + 128)
      dst[56 + x] = idct_clamp(((r7 + 16) >> 5) + 128)
    }
  }
}

///|
/// Forward DCT for encoding. Input is 8x8 block of pixel values [0,255].
/// Output is 64 Int DCT coefficients (natural order), level-shifted by -128.
pub fn fdct(pixels : FixedArray[Byte], block : FixedArray[Int]) -> Unit {
  let tmp = FixedArray::make(64, 0)
  // Row pass
  for y in 0..<8 {
    let base = y * 8
    let p0 = pixels[base].to_int() - 128
    let p1 = pixels[base + 1].to_int() - 128
    let p2 = pixels[base + 2].to_int() - 128
    let p3 = pixels[base + 3].to_int() - 128
    let p4 = pixels[base + 4].to_int() - 128
    let p5 = pixels[base + 5].to_int() - 128
    let p6 = pixels[base + 6].to_int() - 128
    let p7 = pixels[base + 7].to_int() - 128
    let t0 = p0 + p7
    let t1 = p1 + p6
    let t2 = p2 + p5
    let t3 = p3 + p4
    let t4 = p3 - p4
    let t5 = p2 - p5
    let t6 = p1 - p6
    let t7 = p0 - p7
    let t8 = t0 + t3
    let t9 = t1 + t2
    let ta = t1 - t2
    let tb = t0 - t3
    tmp[base] = (t8 + t9) << 3
    tmp[base + 1] = (t7 * w1pw7 + t6 * w7 + t5 * w1mw7 + t4 * w1 + 1024) >> 11
    // Actually use a simpler approach: just scale by 8
    // Re-implement using separable 1D DCT
    let _ = ta
    let _ = tb
    // Simple 8-point DCT via butterfly
    // We'll use a cleaner implementation:
    let e0 = p0 + p7
    let e1 = p1 + p6
    let e2 = p2 + p5
    let e3 = p3 + p4
    let o0 = p0 - p7
    let o1 = p1 - p6
    let o2 = p2 - p5
    let o3 = p3 - p4
    // Even part (DCT-II of [e0..e3])
    let ee0 = e0 + e3
    let ee1 = e1 + e2
    let eo0 = e0 - e3
    let eo1 = e1 - e2
    tmp[base] = (ee0 + ee1) << 3
    tmp[base + 4] = (ee0 - ee1) << 3
    // eo: need to multiply by cos values
    // For simplicity use scaled integer multiply
    tmp[base + 2] = (eo0 * w6 + eo1 * w2 + 1024) >> 11
    tmp[base + 6] = (eo0 * w2 - eo1 * w6 + 1024) >> 11
    // Odd part
    tmp[base + 1] = (o0 * w7 + o1 * w1mw7 + o2 * w1pw7 + o3 * w1 + 1024) >> 11
    tmp[base + 3] = (o0 * w3 - o1 * w3mw5 - o2 * w3pw5 - o3 * w5 + 1024) >> 11
    tmp[base + 5] = (o0 * w5 - o1 * w3pw5 + o2 * w3mw5 + o3 * w3 + 1024) >> 11
    tmp[base + 7] = (o0 * w1 - o1 * w1pw7 + o2 * w1mw7 - o3 * w7 + 1024) >> 11
    // Undo the first two assignments that were computed before the cleaner version
    ignore(t8)
    ignore(t9)
  }
  // Column pass
  for x in 0..<8 {
    let p0 = tmp[x]
    let p1 = tmp[8 + x]
    let p2 = tmp[16 + x]
    let p3 = tmp[24 + x]
    let p4 = tmp[32 + x]
    let p5 = tmp[40 + x]
    let p6 = tmp[48 + x]
    let p7 = tmp[56 + x]
    let e0 = p0 + p7
    let e1 = p1 + p6
    let e2 = p2 + p5
    let e3 = p3 + p4
    let o0 = p0 - p7
    let o1 = p1 - p6
    let o2 = p2 - p5
    let o3 = p3 - p4
    let ee0 = e0 + e3
    let ee1 = e1 + e2
    let eo0 = e0 - e3
    let eo1 = e1 - e2
    block[x] = (ee0 + ee1 + 4) >> 3
    block[32 + x] = (ee0 - ee1 + 4) >> 3
    block[16 + x] = (eo0 * w6 + eo1 * w2 + 8192) >> 14
    block[48 + x] = (eo0 * w2 - eo1 * w6 + 8192) >> 14
    block[8 + x] = (o0 * w7 + o1 * w1mw7 + o2 * w1pw7 + o3 * w1 + 8192) >> 14
    block[24 + x] = (o0 * w3 - o1 * w3mw5 - o2 * w3pw5 - o3 * w5 + 8192) >> 14
    block[40 + x] = (o0 * w5 - o1 * w3pw5 + o2 * w3mw5 + o3 * w3 + 8192) >> 14
    block[56 + x] = (o0 * w1 - o1 * w1pw7 + o2 * w1mw7 - o3 * w7 + 8192) >> 14
  }
}
