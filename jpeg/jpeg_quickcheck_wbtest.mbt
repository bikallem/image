///|
fn qc_jpeg_quality(seed : Int) -> Int {
  let normalized = seed % 100
  (if normalized < 0 { normalized + 100 } else { normalized }) + 1
}

///|
fn qc_jpeg_coeff(seed : Int) -> Int {
  let normalized = seed % 8191
  (if normalized < 0 { normalized + 8191 } else { normalized }) - 4095
}

///|
fn qc_non_negative(seed : Int) -> Int {
  if seed < 0 {
    -seed
  } else {
    seed
  }
}

///|
fn qc_coeff_from_size_value(size : Int, value : Int) -> Int {
  if size == 0 {
    0
  } else {
    let threshold = 1 << (size - 1)
    if value < threshold {
      value - ((1 << size) - 1)
    } else {
      value
    }
  }
}

///|
fn qc_quant_tables_monotone(
  low : FixedArray[Byte],
  high : FixedArray[Byte],
) -> Bool {
  for i in 0..<64 {
    if low[i].to_int() < high[i].to_int() {
      return false
    }
  }
  true
}

///|
fn prop_scale_quant_monotone(qualities : (Int, Int)) -> Bool {
  let (q0, q1) = qualities
  let qa = qc_jpeg_quality(q0)
  let qb = qc_jpeg_quality(q1)
  let low_quality = if qa <= qb { qa } else { qb }
  let high_quality = if qa <= qb { qb } else { qa }
  qc_quant_tables_monotone(
    scale_quant(unscaled_quant_luma, low_quality),
    scale_quant(unscaled_quant_luma, high_quality),
  ) &&
  qc_quant_tables_monotone(
    scale_quant(unscaled_quant_chroma, low_quality),
    scale_quant(unscaled_quant_chroma, high_quality),
  )
}

///|
fn prop_scale_quant_clamps(seed : Int) -> Bool {
  let large = qc_non_negative(seed)
  scale_quant(unscaled_quant_luma, -large - 1) ==
  scale_quant(unscaled_quant_luma, 1) &&
  scale_quant(unscaled_quant_chroma, -large - 1) ==
  scale_quant(unscaled_quant_chroma, 1) &&
  scale_quant(unscaled_quant_luma, large + 100) ==
  scale_quant(unscaled_quant_luma, 100) &&
  scale_quant(unscaled_quant_chroma, large + 100) ==
  scale_quant(unscaled_quant_chroma, 100)
}

///|
fn prop_coeff_size_value_roundtrip(seed : Int) -> Bool {
  let coeff = qc_jpeg_coeff(seed)
  let (size, value) = coeff_to_size_value(coeff)
  qc_coeff_from_size_value(size, value) == coeff
}

///|
test "jpeg_quickcheck" {
  @qc.quick_check_fn(prop_scale_quant_monotone, max_success=200)
  @qc.quick_check_fn(prop_scale_quant_clamps, max_success=200)
  @qc.quick_check_fn(prop_coeff_size_value_roundtrip, max_success=200)
}
