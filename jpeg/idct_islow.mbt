///|
/// ISLOW IDCT — port of libjpeg-turbo's jidctint.c (jpeg_idct_islow).
/// Produces output matching libjpeg-turbo for 8-bit JPEG.
/// Input: block[64] of dequantized coefficients in natural (row-major) order.
/// Output: dst[64] of pixel bytes [0,255] after +128 level shift.

// Fixed-point constants scaled by 2^13 = 8192 (CONST_BITS=13)
let fix_0_298631336 : Int = 2446

///|
let fix_0_390180644 : Int = 3196

///|
let fix_0_541196100 : Int = 4433

///|
let fix_0_765366865 : Int = 6270

///|
let fix_0_899976223 : Int = 7373

///|
let fix_1_175875602 : Int = 9633

///|
let fix_1_501321110 : Int = 12299

///|
let fix_1_847759065 : Int = 15137

///|
let fix_1_961570560 : Int = 16069

///|
let fix_2_053119869 : Int = 16819

///|
let fix_2_562915447 : Int = 20995

///|
let fix_3_072711026 : Int = 25172

///|
let islow_const_bits : Int = 13

///|
let islow_pass1_bits : Int = 2

///|
fn descale(x : Int, n : Int) -> Int {
  (x + (1 << (n - 1))) >> n
}

///|
/// ISLOW IDCT matching libjpeg-turbo's jpeg_idct_islow.
pub fn idct_islow(block : FixedArray[Int], dst : FixedArray[Byte]) -> Unit {
  let ws = FixedArray::make(64, 0)
  // Pass 1: process rows. Input: dequantized coefficients. Output: workspace.
  for row in 0..<8 {
    let base = row * 8
    let d0 = block.unsafe_get(base)
    let d1 = block.unsafe_get(base + 1)
    let d2 = block.unsafe_get(base + 2)
    let d3 = block.unsafe_get(base + 3)
    let d4 = block.unsafe_get(base + 4)
    let d5 = block.unsafe_get(base + 5)
    let d6 = block.unsafe_get(base + 6)
    let d7 = block.unsafe_get(base + 7)
    if d1 == 0 && d2 == 0 && d3 == 0 && d4 == 0 && d5 == 0 && d6 == 0 &&
      d7 == 0 {
      let dcval = d0 << islow_pass1_bits
      ws.unsafe_set(base, dcval)
      ws.unsafe_set(base + 1, dcval)
      ws.unsafe_set(base + 2, dcval)
      ws.unsafe_set(base + 3, dcval)
      ws.unsafe_set(base + 4, dcval)
      ws.unsafe_set(base + 5, dcval)
      ws.unsafe_set(base + 6, dcval)
      ws.unsafe_set(base + 7, dcval)
      continue
    }
    // Even part: d0, d2, d4, d6
    let tmp10 = (d0 + d4) << islow_const_bits
    let tmp11 = (d0 - d4) << islow_const_bits
    let z1 = (d2 + d6) * fix_0_541196100
    let tmp12 = z1 - d6 * fix_1_847759065
    let tmp13 = z1 + d2 * fix_0_765366865
    let tmp0 = tmp10 + tmp13
    let tmp3 = tmp10 - tmp13
    let tmp1 = tmp11 + tmp12
    let tmp2 = tmp11 - tmp12
    // Odd part: d1, d3, d5, d7
    let z1 = d1 + d7
    let z2 = d3 + d5
    let z3 = d1 + d5
    let z4 = d3 + d7
    let z5 = (z3 + z4) * fix_1_175875602
    let tmp4 = d1 * fix_0_298631336
    let tmp5 = d3 * fix_2_053119869
    let tmp6 = d5 * fix_3_072711026
    let tmp7 = d7 * fix_1_501321110
    let z1 = z1 * (0 - fix_0_899976223)
    let z2 = z2 * (0 - fix_2_562915447)
    let z3 = z3 * (0 - fix_1_961570560) + z5
    let z4 = z4 * (0 - fix_0_390180644) + z5
    let tmp4 = tmp4 + z1 + z3
    let tmp5 = tmp5 + z2 + z4
    let tmp6 = tmp6 + z2 + z3
    let tmp7 = tmp7 + z1 + z4
    // Combine and descale
    ws.unsafe_set(base, descale(tmp0 + tmp7, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 7, descale(tmp0 - tmp7, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 1, descale(tmp1 + tmp6, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 6, descale(tmp1 - tmp6, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 2, descale(tmp2 + tmp5, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 5, descale(tmp2 - tmp5, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 3, descale(tmp3 + tmp4, islow_const_bits - islow_pass1_bits))
    ws.unsafe_set(base + 4, descale(tmp3 - tmp4, islow_const_bits - islow_pass1_bits))
  }
  // Pass 2: process columns. Input: workspace. Output: clamped bytes.
  let range_center = 128
  for col in 0..<8 {
    let d0 = ws.unsafe_get(0 * 8 + col)
    let d1 = ws.unsafe_get(1 * 8 + col)
    let d2 = ws.unsafe_get(2 * 8 + col)
    let d3 = ws.unsafe_get(3 * 8 + col)
    let d4 = ws.unsafe_get(4 * 8 + col)
    let d5 = ws.unsafe_get(5 * 8 + col)
    let d6 = ws.unsafe_get(6 * 8 + col)
    let d7 = ws.unsafe_get(7 * 8 + col)
    if d1 == 0 && d2 == 0 && d3 == 0 && d4 == 0 && d5 == 0 && d6 == 0 &&
      d7 == 0 {
      let dcval = idct_clamp_byte(
        descale(d0, islow_pass1_bits + 3) + range_center,
      )
      dst.unsafe_set(0 * 8 + col, dcval)
      dst.unsafe_set(1 * 8 + col, dcval)
      dst.unsafe_set(2 * 8 + col, dcval)
      dst.unsafe_set(3 * 8 + col, dcval)
      dst.unsafe_set(4 * 8 + col, dcval)
      dst.unsafe_set(5 * 8 + col, dcval)
      dst.unsafe_set(6 * 8 + col, dcval)
      dst.unsafe_set(7 * 8 + col, dcval)
      continue
    }
    // Even part
    let tmp10 = (d0 + d4) << islow_const_bits
    let tmp11 = (d0 - d4) << islow_const_bits
    let z1 = (d2 + d6) * fix_0_541196100
    let tmp12 = z1 - d6 * fix_1_847759065
    let tmp13 = z1 + d2 * fix_0_765366865
    // Add rounding bias
    let tmp10 = tmp10 + (1 << (islow_const_bits + islow_pass1_bits + 3 - 1))
    let tmp0 = tmp10 + tmp13
    let tmp3 = tmp10 - tmp13
    let tmp1 = tmp11 + tmp12
    let tmp2 = tmp11 - tmp12
    // Odd part
    let z1 = d1 + d7
    let z2 = d3 + d5
    let z3 = d1 + d5
    let z4 = d3 + d7
    let z5 = (z3 + z4) * fix_1_175875602
    let tmp4 = d1 * fix_0_298631336
    let tmp5 = d3 * fix_2_053119869
    let tmp6 = d5 * fix_3_072711026
    let tmp7 = d7 * fix_1_501321110
    let z1 = z1 * (0 - fix_0_899976223)
    let z2 = z2 * (0 - fix_2_562915447)
    let z3 = z3 * (0 - fix_1_961570560) + z5
    let z4 = z4 * (0 - fix_0_390180644) + z5
    let tmp4 = tmp4 + z1 + z3
    let tmp5 = tmp5 + z2 + z4
    let tmp6 = tmp6 + z2 + z3
    let tmp7 = tmp7 + z1 + z4
    // Combine, descale, level-shift, clamp
    let shift = islow_const_bits + islow_pass1_bits + 3
    dst.unsafe_set(
      0 * 8 + col, idct_clamp_byte(((tmp0 + tmp7) >> shift) + range_center),
    )
    dst.unsafe_set(
      7 * 8 + col, idct_clamp_byte(((tmp0 - tmp7) >> shift) + range_center),
    )
    dst.unsafe_set(
      1 * 8 + col, idct_clamp_byte(((tmp1 + tmp6) >> shift) + range_center),
    )
    dst.unsafe_set(
      6 * 8 + col, idct_clamp_byte(((tmp1 - tmp6) >> shift) + range_center),
    )
    dst.unsafe_set(
      2 * 8 + col, idct_clamp_byte(((tmp2 + tmp5) >> shift) + range_center),
    )
    dst.unsafe_set(
      5 * 8 + col, idct_clamp_byte(((tmp2 - tmp5) >> shift) + range_center),
    )
    dst.unsafe_set(
      3 * 8 + col, idct_clamp_byte(((tmp3 + tmp4) >> shift) + range_center),
    )
    dst.unsafe_set(
      4 * 8 + col, idct_clamp_byte(((tmp3 - tmp4) >> shift) + range_center),
    )
  }
}
