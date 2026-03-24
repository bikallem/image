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
/// Performs a 1D IDCT on an 8-element row of the block (in-place).
/// Input values are scaled by 8 (i.e., left-shifted by 3 relative to spec).
/// Output is 64 Int DCT coefficients (natural order), level-shifted by -128.
pub fn fdct(pixels : FixedArray[Byte], block : FixedArray[Int]) -> Unit {
  let tmp = FixedArray::make(64, 0)
  // Row pass
  for y in 0..<8 {
    let base = y * 8
    let p0 = pixels.unsafe_get(base).to_int() - 128
    let p1 = pixels.unsafe_get(base + 1).to_int() - 128
    let p2 = pixels.unsafe_get(base + 2).to_int() - 128
    let p3 = pixels.unsafe_get(base + 3).to_int() - 128
    let p4 = pixels.unsafe_get(base + 4).to_int() - 128
    let p5 = pixels.unsafe_get(base + 5).to_int() - 128
    let p6 = pixels.unsafe_get(base + 6).to_int() - 128
    let p7 = pixels.unsafe_get(base + 7).to_int() - 128
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
    tmp.unsafe_set(base, (t8 + t9) << 3)
    tmp.unsafe_set(
      base + 1,
      (t7 * w1pw7 + t6 * w7 + t5 * w1mw7 + t4 * w1 + 1024) >> 11,
    )
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
    tmp.unsafe_set(base, (ee0 + ee1) << 3)
    tmp.unsafe_set(base + 4, (ee0 - ee1) << 3)
    // eo: need to multiply by cos values
    // For simplicity use scaled integer multiply
    tmp.unsafe_set(base + 2, (eo0 * w6 + eo1 * w2 + 1024) >> 11)
    tmp.unsafe_set(base + 6, (eo0 * w2 - eo1 * w6 + 1024) >> 11)
    // Odd part
    tmp.unsafe_set(
      base + 1,
      (o0 * w7 + o1 * w1mw7 + o2 * w1pw7 + o3 * w1 + 1024) >> 11,
    )
    tmp.unsafe_set(
      base + 3,
      (o0 * w3 - o1 * w3mw5 - o2 * w3pw5 - o3 * w5 + 1024) >> 11,
    )
    tmp.unsafe_set(
      base + 5,
      (o0 * w5 - o1 * w3pw5 + o2 * w3mw5 + o3 * w3 + 1024) >> 11,
    )
    tmp.unsafe_set(
      base + 7,
      (o0 * w1 - o1 * w1pw7 + o2 * w1mw7 - o3 * w7 + 1024) >> 11,
    )
    // Undo the first two assignments that were computed before the cleaner version
    ignore(t8)
    ignore(t9)
  }
  // Column pass
  for x in 0..<8 {
    let p0 = tmp.unsafe_get(x)
    let p1 = tmp.unsafe_get(8 + x)
    let p2 = tmp.unsafe_get(16 + x)
    let p3 = tmp.unsafe_get(24 + x)
    let p4 = tmp.unsafe_get(32 + x)
    let p5 = tmp.unsafe_get(40 + x)
    let p6 = tmp.unsafe_get(48 + x)
    let p7 = tmp.unsafe_get(56 + x)
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
    block.unsafe_set(x, (ee0 + ee1 + 4) >> 3)
    block.unsafe_set(32 + x, (ee0 - ee1 + 4) >> 3)
    block.unsafe_set(16 + x, (eo0 * w6 + eo1 * w2 + 8192) >> 14)
    block.unsafe_set(48 + x, (eo0 * w2 - eo1 * w6 + 8192) >> 14)
    block.unsafe_set(
      8 + x,
      (o0 * w7 + o1 * w1mw7 + o2 * w1pw7 + o3 * w1 + 8192) >> 14,
    )
    block.unsafe_set(
      24 + x,
      (o0 * w3 - o1 * w3mw5 - o2 * w3pw5 - o3 * w5 + 8192) >> 14,
    )
    block.unsafe_set(
      40 + x,
      (o0 * w5 - o1 * w3pw5 + o2 * w3mw5 + o3 * w3 + 8192) >> 14,
    )
    block.unsafe_set(
      56 + x,
      (o0 * w1 - o1 * w1pw7 + o2 * w1mw7 - o3 * w7 + 8192) >> 14,
    )
  }
}
