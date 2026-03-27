///|
fn qc_byte(n : Int) -> Byte {
  let m = n % 256
  let normalized = if m < 0 { m + 256 } else { m }
  normalized.to_byte()
}

///|
fn prop_ycbcr_roundtrip_random(rgb : (Int, Int, Int)) -> Bool {
  let (r_seed, g_seed, b_seed) = rgb
  let r0 = qc_byte(r_seed)
  let g0 = qc_byte(g_seed)
  let b0 = qc_byte(b_seed)
  let (y, cb, cr) = rgb_to_ycbcr(r0, g0, b0)
  let (r1, g1, b1) = ycbcr_to_rgb(y, cb, cr)
  byte_delta(r0, r1) <= 2 && byte_delta(g0, g1) <= 2 && byte_delta(b0, b1) <= 2
}

///|
fn prop_ycbcr_to_rgb_consistency_random(ycc : (Int, Int, Int)) -> Bool {
  let (y_seed, cb_seed, cr_seed) = ycc
  let y = qc_byte(y_seed)
  let cb = qc_byte(cb_seed)
  let cr = qc_byte(cr_seed)
  let x : YCbCr = { y, cb, cr }
  let (r0, g0, b0, _) = x.rgba()
  let r1 = (r0 >> 8).to_byte()
  let g1 = (g0 >> 8).to_byte()
  let b1 = (b0 >> 8).to_byte()
  let (r2, g2, b2) = ycbcr_to_rgb(y, cb, cr)
  r1 == r2 && g1 == g2 && b1 == b2
}

///|
fn prop_cmyk_roundtrip_random(rgb : (Int, Int, Int)) -> Bool {
  let (r_seed, g_seed, b_seed) = rgb
  let r0 = qc_byte(r_seed)
  let g0 = qc_byte(g_seed)
  let b0 = qc_byte(b_seed)
  let (c, m, y, k) = rgb_to_cmyk(r0, g0, b0)
  let (r1, g1, b1) = cmyk_to_rgb(c, m, y, k)
  byte_delta(r0, r1) <= 1 && byte_delta(g0, g1) <= 1 && byte_delta(b0, b1) <= 1
}

///|
fn prop_cmyk_to_rgb_consistency_random(cmyk : (Int, Int, Int, Int)) -> Bool {
  let (c_seed, m_seed, y_seed, k_seed) = cmyk
  let c = qc_byte(c_seed)
  let m = qc_byte(m_seed)
  let y = qc_byte(y_seed)
  let k = qc_byte(k_seed)
  let x : CMYK = { c, m, y, k }
  let (r0, g0, b0, _) = x.rgba()
  let r1 = (r0 >> 8).to_byte()
  let g1 = (g0 >> 8).to_byte()
  let b1 = (b0 >> 8).to_byte()
  let (r2, g2, b2) = cmyk_to_rgb(c, m, y, k)
  r1 == r2 && g1 == g2 && b1 == b2
}

///|
test "color_quickcheck" {
  @qc.quick_check_fn(prop_ycbcr_roundtrip_random, max_success=200)
  @qc.quick_check_fn(prop_ycbcr_to_rgb_consistency_random, max_success=200)
  @qc.quick_check_fn(prop_cmyk_roundtrip_random, max_success=200)
  @qc.quick_check_fn(prop_cmyk_to_rgb_consistency_random, max_success=200)
}
