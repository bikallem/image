///|
fn reset_dc_preds(d : Decoder) -> Unit {
  for i in 0..<d.num_components {
    d.comp.unsafe_get(i).dc_pred = 0
  }
}

///|
fn max_sampling(d : Decoder) -> (Int, Int) {
  let mut max_h = 1
  let mut max_v = 1
  for i in 0..<d.num_components {
    if d.comp.unsafe_get(i).h > max_h {
      max_h = d.comp.unsafe_get(i).h
    }
    if d.comp.unsafe_get(i).v > max_v {
      max_v = d.comp.unsafe_get(i).v
    }
  }
  (max_h, max_v)
}

///|
fn ensure_coeff_blocks(
  d : Decoder,
  ci : Int,
  mcu_cols : Int,
  mcu_rows : Int,
) -> Unit {
  let n_blocks = mcu_cols *
    mcu_rows *
    d.comp.unsafe_get(ci).h *
    d.comp.unsafe_get(ci).v
  if d.prog_coeffs.unsafe_get(ci).length() == 0 {
    let blocks : Array[FixedArray[Int]] = Array::new(capacity=n_blocks)
    for _ in 0..<n_blocks {
      blocks.push(FixedArray::make(64, 0))
    }
    d.prog_coeffs.unsafe_set(ci, blocks)
  }
}

///|
/// Process a SOS segment and store decoded coefficients into d.prog_coeffs.
pub fn process_sos(d : Decoder) -> Unit raise JpegError {
  let length = d.r.read_uint16_be()
  let seg_len = length.reinterpret_as_int() - 2
  if d.num_components == 0 {
    raise JpegError::FormatError("missing SOF marker")
  }
  if seg_len < 6 || seg_len > 4 + 2 * d.num_components || seg_len % 2 != 0 {
    raise JpegError::FormatError("SOS has wrong length")
  }
  let ns = d.r.read_byte().to_int()
  if seg_len != 4 + 2 * ns {
    raise JpegError::FormatError(
      "SOS length inconsistent with number of components",
    )
  }
  let scan_comp = FixedArray::make(ns, 0)
  let mut total_hv = 0
  for i in 0..<ns {
    let cs = d.r.read_byte().to_int()
    let td_ta = d.r.read_byte().to_int()
    let td = (td_ta >> 4) & 0x0F
    let ta = td_ta & 0x0F
    let mut ci = -1
    for j in 0..<d.num_components {
      if d.comp.unsafe_get(j).id == cs {
        ci = j
      }
    }
    if ci < 0 {
      raise JpegError::FormatError("unknown component selector")
    }
    for j in 0..<i {
      if scan_comp.unsafe_get(j) == ci {
        raise JpegError::FormatError("repeated component selector")
      }
    }
    if td > 3 || (d.baseline && td > 1) {
      raise JpegError::FormatError("bad Td value")
    }
    if ta > 3 || (d.baseline && ta > 1) {
      raise JpegError::FormatError("bad Ta value")
    }
    scan_comp.unsafe_set(i, ci)
    total_hv += d.comp.unsafe_get(ci).h * d.comp.unsafe_get(ci).v
    d.comp.unsafe_get(ci).dc_huff_idx = td
    d.comp.unsafe_get(ci).ac_huff_idx = ta
  }
  if d.num_components > 1 && total_hv > 10 {
    raise JpegError::FormatError("total sampling factors too large")
  }
  let ss = d.r.read_byte().to_int()
  let se = d.r.read_byte().to_int()
  let ah_al = d.r.read_byte().to_int()
  let ah = (ah_al >> 4) & 0x0F
  let al = ah_al & 0x0F
  if d.progressive {
    if (ss == 0 && se != 0) || ss > se || se >= 64 {
      raise JpegError::FormatError("bad spectral selection bounds")
    }
    if ss != 0 && ns != 1 {
      raise JpegError::FormatError(
        "progressive AC coefficients for more than one component",
      )
    }
    if ah != 0 && ah != al + 1 {
      raise JpegError::FormatError("bad successive approximation values")
    }
  } else {
    if ss != 0 || se != 63 {
      raise JpegError::FormatError("bad spectral selection bounds")
    }
    if ah != 0 || al != 0 {
      raise JpegError::FormatError("bad successive approximation values")
    }
  }
  flush_bits(d)
  d.eob_run = 0
  reset_dc_preds(d)
  let (max_h, max_v) = max_sampling(d)
  let mcu_cols = (d.width + max_h * 8 - 1) / (max_h * 8)
  let mcu_rows = (d.height + max_v * 8 - 1) / (max_v * 8)
  for i in 0..<ns {
    ensure_coeff_blocks(d, scan_comp.unsafe_get(i), mcu_cols, mcu_rows)
  }
  let mut mcu_count = 0
  let mut block_count = 0
  let mut expected_rst = marker_rst0
  for my in 0..<mcu_rows {
    for mx in 0..<mcu_cols {
      if d.restart_interval > 0 &&
        mcu_count > 0 &&
        mcu_count % d.restart_interval == 0 {
        flush_bits(d)
        reset_dc_preds(d)
        d.eob_run = 0
        consume_restart_marker(d, expected_rst)
        expected_rst = if expected_rst == marker_rst7 {
          marker_rst0
        } else {
          expected_rst + 1U
        }
      }
      mcu_count += 1
      for si in 0..<ns {
        let ci = scan_comp.unsafe_get(si)
        let hi = d.comp.unsafe_get(ci).h
        let vi = d.comp.unsafe_get(ci).v
        for j in 0..<(hi * vi) {
          let (bx, by) = if ns != 1 {
            (hi * mx + j % hi, vi * my + j / hi)
          } else {
            let q = mcu_cols * hi
            let bx = block_count % q
            let by = block_count / q
            block_count += 1
            if bx * 8 >= d.width || by * 8 >= d.height {
              continue
            }
            (bx, by)
          }
          let block_idx = by * mcu_cols * hi + bx
          let b = d.prog_coeffs.unsafe_get(ci)[block_idx]
          if d.progressive {
            if ah != 0 {
              refine_ac(d, b, ss, se, al, ci)
            } else {
              let mut zig = ss
              if zig == 0 {
                let dc_table = d.huff.unsafe_get(0)[d.comp.unsafe_get(ci).dc_huff_idx]
                let dc_size = decode_huffman(d, dc_table)
                if dc_size > 16 {
                  raise JpegError::UnsupportedError("excessive DC component")
                }
                let dc_diff = receive_and_extend(d, dc_size)
                d.comp.unsafe_get(ci).dc_pred += dc_diff
                b.unsafe_set(0, d.comp.unsafe_get(ci).dc_pred << al)
                zig = 1
              }
              if zig <= se && d.eob_run > 0 {
                d.eob_run -= 1
              } else {
                let ac_table = d.huff.unsafe_get(1)[d.comp.unsafe_get(ci).ac_huff_idx]
                while zig <= se {
                  let rs = decode_huffman(d, ac_table)
                  let val0 = (rs >> 4) & 0x0F
                  let val1 = rs & 0x0F
                  if val1 != 0 {
                    zig += val0
                    if zig > se {
                      break
                    }
                    let ac = receive_and_extend(d, val1)
                    b.unsafe_set(unzig.unsafe_get(zig), ac << al)
                  } else {
                    if val0 != 0x0F {
                      d.eob_run = 1 << val0
                      if val0 != 0 {
                        let extra = read_bits(d, val0)
                        d.eob_run = d.eob_run | extra
                      }
                      d.eob_run -= 1
                      break
                    }
                    zig += 0x0F
                  }
                  zig += 1
                }
              }
            }
          } else {
            decode_block(d, ci, b)
          }
          d.prog_coeffs.unsafe_get(ci)[block_idx] = b
        }
      }
    }
  }
}

///|
/// Decode one 8x8 DCT block for component ci.
/// Fills block[] with 64 dequantized-but-zigzag-ordered coefficients.
fn decode_block(
  d : Decoder,
  ci : Int,
  block : FixedArray[Int],
) -> Unit raise JpegError {
  // Zero out block
  for k in 0..<64 {
    block.unsafe_set(k, 0)
  }
  let dc_table = d.huff.unsafe_get(0)[d.comp.unsafe_get(ci).dc_huff_idx]
  let ac_table = d.huff.unsafe_get(1)[d.comp.unsafe_get(ci).ac_huff_idx]
  // Decode DC coefficient
  let dc_size = decode_huffman(d, dc_table)
  if dc_size > 16 {
    raise JpegError::UnsupportedError("excessive DC component")
  }
  let dc_diff = receive_and_extend(d, dc_size)
  d.comp.unsafe_get(ci).dc_pred = d.comp.unsafe_get(ci).dc_pred + dc_diff
  block.unsafe_set(0, d.comp.unsafe_get(ci).dc_pred)
  // Decode AC coefficients
  let mut k = 1
  while k < 64 {
    let rs = decode_huffman(d, ac_table)
    let run = (rs >> 4) & 0x0F
    let size = rs & 0x0F
    if size == 0 {
      if run == 15 {
        // ZRL: skip 16 zeros
        k = k + 16
      } else {
        // EOB: end of block
        break
      }
    } else {
      k = k + run
      if k >= 64 {
        raise JpegError::FormatError("AC coefficient index out of range")
      }
      let coeff = receive_and_extend(d, size)
      block.unsafe_set(k, coeff)
      k = k + 1
    }
  }
}

///|
fn refine_ac(
  d : Decoder,
  b : FixedArray[Int],
  ss : Int,
  se : Int,
  al : Int,
  ci : Int,
) -> Unit raise JpegError {
  let delta = 1 << al
  if ss == 0 {
    if se != 0 {
      raise JpegError::FormatError("bad spectral selection bounds")
    }
    let bit = read_bit(d)
    if bit {
      b.unsafe_set(0, b.unsafe_get(0) | delta)
    }
    return
  }
  let ac_table = d.huff.unsafe_get(1)[d.comp.unsafe_get(ci).ac_huff_idx]
  let mut zig = ss
  if d.eob_run == 0 {
    let mut done = false
    while zig <= se && !done {
      let rs = decode_huffman(d, ac_table)
      let val0 = (rs >> 4) & 0x0F
      let val1 = rs & 0x0F
      let mut z = 0
      if val1 == 0 {
        if val0 != 0x0F {
          d.eob_run = 1 << val0
          if val0 != 0 {
            let extra = read_bits(d, val0)
            d.eob_run = d.eob_run | extra
          }
          done = true
        }
      } else if val1 == 1 {
        z = delta
        let bit = read_bit(d)
        if !bit {
          z = -z
        }
      } else {
        raise JpegError::FormatError("unexpected Huffman code in refinement")
      }
      if !done {
        zig = refine_non_zeroes(d, b, zig, se, val0, delta)
        if zig > se {
          raise JpegError::FormatError("too many coefficients")
        }
        if z != 0 {
          b.unsafe_set(unzig.unsafe_get(zig), z)
        }
        zig += 1
      }
    }
  }
  if d.eob_run > 0 {
    d.eob_run -= 1
    ignore(refine_non_zeroes(d, b, zig, se, -1, delta))
  }
}

///|
fn refine_non_zeroes(
  d : Decoder,
  b : FixedArray[Int],
  zig : Int,
  se : Int,
  nz : Int,
  delta : Int,
) -> Int raise JpegError {
  let mut zig = zig
  let mut nz = nz
  while zig <= se {
    let u = unzig.unsafe_get(zig)
    if b.unsafe_get(u) == 0 {
      if nz == 0 {
        break
      }
      if nz > 0 {
        nz -= 1
      }
      zig += 1
      continue
    }
    let bit = read_bit(d)
    if bit {
      if b.unsafe_get(u) >= 0 {
        b.unsafe_set(u, b.unsafe_get(u) + delta)
      } else {
        b.unsafe_set(u, b.unsafe_get(u) - delta)
      }
    }
    zig += 1
  }
  zig
}

///|
fn read_bit(d : Decoder) -> Bool raise JpegError {
  if d.bits.n == 0 {
    ensure_bits(d, 1)
  }
  d.bits.n -= 1
  ((d.bits.buf >> d.bits.n) & 1) != 0
}

///|
/// Reconstruct the full image from progressive coefficients.
fn reconstruct_coefficients(d : Decoder) -> &@image.Image raise JpegError {
  let (max_h, max_v) = max_sampling(d)
  let mcu_cols = (d.width + max_h * 8 - 1) / (max_h * 8)
  let mcu_rows = (d.height + max_v * 8 - 1) / (max_v * 8)
  // Allocate component planes
  let comp_data : FixedArray[FixedArray[Byte]] = FixedArray::make(
    d.num_components,
    FixedArray::make(0, b'\x00'),
  )
  let comp_width = FixedArray::make(d.num_components, 0)
  let comp_height = FixedArray::make(d.num_components, 0)
  for i in 0..<d.num_components {
    let cw = mcu_cols * d.comp.unsafe_get(i).h * 8
    let ch = mcu_rows * d.comp.unsafe_get(i).v * 8
    comp_width.unsafe_set(i, cw)
    comp_height.unsafe_set(i, ch)
    comp_data.unsafe_set(i, FixedArray::make(cw * ch, b'\x00'))
  }
  let nat = @blit.make_uninit_int(64)
  let idct_out = @blit.make_uninit(64)
  let idct_ws = FixedArray::make(64, 0)
  // For each component, dequantize and IDCT all blocks
  for ci in 0..<d.num_components {
    if d.prog_coeffs.unsafe_get(ci).length() == 0 {
      continue
    }
    let stride = mcu_cols * d.comp.unsafe_get(ci).h
    let qt_idx = d.comp.unsafe_get(ci).qt
    for block_idx, b in d.prog_coeffs.unsafe_get(ci) {
      let bx = block_idx % stride
      let by = block_idx / stride
      // Dequantize
      for k in 0..<64 {
        nat.unsafe_set(k, 0)
      }
      for k in 0..<64 {
        nat.unsafe_set(
          unzig.unsafe_get(k),
          b.unsafe_get(k) * d.quant.unsafe_get(qt_idx).data.unsafe_get(k),
        )
      }
      // Note: b[k] is stored at zig-zag position k, quant is also zig-zag
      // nat[unzig.unsafe_get(k)] places into natural order for IDCT
      idct_islow(nat, idct_out, idct_ws)
      // Write to comp_data
      let cw = comp_width.unsafe_get(ci)
      for py in 0..<8 {
        for px in 0..<8 {
          let cx = bx * 8 + px
          let cy = by * 8 + py
          if cx < cw && cy < comp_height.unsafe_get(ci) {
            comp_data.unsafe_get(ci)[cy * cw + cx] = idct_out.unsafe_get(
              py * 8 + px,
            )
          }
        }
      }
    }
  }
  // Build output image (same as sequential)
  let rect : @image.Rectangle = {
    min_x: 0,
    min_y: 0,
    max_x: d.width,
    max_y: d.height,
  }
  if d.num_components == 1 {
    let img = @image.new_image_gray(rect)
    for y in 0..<d.height {
      for x in 0..<d.width {
        img.pix.unsafe_set(
          y * img.stride + x,
          comp_data.unsafe_get(0)[y * comp_width.unsafe_get(0) + x],
        )
      }
    }
    (img : &@image.Image)
  } else {
    build_output_image(d, comp_data, comp_width, comp_height, rect)
  }
}

///|
fn build_output_image(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  comp_height : FixedArray[Int],
  rect : @image.Rectangle,
) -> &@image.Image raise JpegError {
  if d.num_components == 4 {
    components_to_cmyk(d, comp_data, comp_width, rect)
  } else if is_rgb_jpeg(d) {
    rgb_to_rgba(d, comp_data, comp_width, rect)
  } else {
    components_to_ycbcr(d, comp_data, comp_width, comp_height, rect)
  }
}

///|
fn is_rgb_jpeg(d : Decoder) -> Bool {
  if d.jfif {
    return false
  }
  if d.adobe_transform_valid && d.adobe_transform == adobe_transform_unknown {
    return true
  }
  d.num_components == 3 &&
  d.comp.unsafe_get(0).id == b'R'.to_int() &&
  d.comp.unsafe_get(1).id == b'G'.to_int() &&
  d.comp.unsafe_get(2).id == b'B'.to_int()
}

///|
fn ycbcr_subsample_ratio(
  d : Decoder,
) -> @image.YCbCrSubsampleRatio raise JpegError {
  let (max_h, max_v) = max_sampling(d)
  let h_ratio = max_h / d.comp.unsafe_get(1).h
  let v_ratio = max_v / d.comp.unsafe_get(1).v
  match (h_ratio << 4) | v_ratio {
    0x11 => @image.Ratio444
    0x12 => @image.Ratio440
    0x21 => @image.Ratio422
    0x22 => @image.Ratio420
    0x41 => @image.Ratio411
    0x42 => @image.Ratio410
    _ => raise JpegError::UnsupportedError("unsupported subsampling ratio")
  }
}

///|
fn is_flex_ycbcr(d : Decoder) -> Bool {
  let (max_h, max_v) = max_sampling(d)
  if d.comp.unsafe_get(1).h != d.comp.unsafe_get(2).h ||
    d.comp.unsafe_get(1).v != d.comp.unsafe_get(2).v ||
    d.comp.unsafe_get(0).h != max_h ||
    d.comp.unsafe_get(0).v != max_v {
    return true
  }
  let h_ratio = max_h / d.comp.unsafe_get(1).h
  let v_ratio = max_v / d.comp.unsafe_get(1).v
  match (h_ratio << 4) | v_ratio {
    0x11 | 0x12 | 0x21 | 0x22 | 0x41 | 0x42 => false
    _ => true
  }
}

///|
fn components_to_ycbcr(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  comp_height : FixedArray[Int],
  rect : @image.Rectangle,
) -> &@image.Image raise JpegError {
  if is_flex_ycbcr(d) {
    return components_to_ycbcr444(d, comp_data, comp_width, comp_height, rect)
  }
  let full = @image.new_image_ycbcr(
    @image.rect(0, 0, comp_width.unsafe_get(0), comp_height.unsafe_get(0)),
    ycbcr_subsample_ratio(d),
  )
  let y_plane = comp_data.unsafe_get(0)
  let cb_plane = comp_data.unsafe_get(1)
  let cr_plane = comp_data.unsafe_get(2)
  for i in 0..<y_plane.length() {
    full.y_.unsafe_set(i, y_plane.unsafe_get(i))
  }
  for i in 0..<cb_plane.length() {
    full.cb.unsafe_set(i, cb_plane.unsafe_get(i))
    full.cr.unsafe_set(i, cr_plane.unsafe_get(i))
  }
  full.sub_image(rect)
}

///|
fn components_to_ycbcr444(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  comp_height : FixedArray[Int],
  rect : @image.Rectangle,
) -> &@image.Image {
  let (max_h, max_v) = max_sampling(d)
  let mut full_width = 0
  let mut full_height = 0
  for i in 0..<3 {
    if comp_width.unsafe_get(i) > full_width {
      full_width = comp_width.unsafe_get(i)
    }
    if comp_height.unsafe_get(i) > full_height {
      full_height = comp_height.unsafe_get(i)
    }
  }
  let full = @image.new_image_ycbcr(
    @image.rect(0, 0, full_width, full_height),
    @image.Ratio444,
  )
  for y in 0..<full_height {
    let row_start = y * full_width
    for x in 0..<full_width {
      full.y_.unsafe_set(
        row_start + x,
        sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 0, x, y,
        ),
      )
      full.cb.unsafe_set(
        row_start + x,
        sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 1, x, y,
        ),
      )
      full.cr.unsafe_set(
        row_start + x,
        sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 2, x, y,
        ),
      )
    }
  }
  full.sub_image(rect)
}

///|
fn sample_component_with_max(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  max_h : Int,
  max_v : Int,
  ci : Int,
  x : Int,
  y : Int,
) -> Byte {
  let h_ratio = max_h / d.comp.unsafe_get(ci).h
  let v_ratio = max_v / d.comp.unsafe_get(ci).v
  let sx = x / h_ratio
  let sy = y / v_ratio
  comp_data.unsafe_get(ci)[sy * comp_width.unsafe_get(ci) + sx]
}

///|
fn rgb_to_rgba(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  rect : @image.Rectangle,
) -> &@image.Image {
  let (max_h, max_v) = max_sampling(d)
  let img = @image.new_image_rgba(rect)
  for y in 0..<d.height {
    let di_row = y * img.stride
    for x in 0..<d.width {
      let di = di_row + x * 4
      img.pix.unsafe_set(
        di,
        sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 0, x, y,
        ),
      )
      img.pix.unsafe_set(
        di + 1,
        sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 1, x, y,
        ),
      )
      img.pix.unsafe_set(
        di + 2,
        sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 2, x, y,
        ),
      )
      img.pix.unsafe_set(di + 3, b'\xff')
    }
  }
  img
}

///|
fn components_to_cmyk(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  rect : @image.Rectangle,
) -> &@image.Image raise JpegError {
  let (max_h, max_v) = max_sampling(d)
  if !d.adobe_transform_valid {
    raise JpegError::UnsupportedError(
      "unknown color model: 4-component JPEG doesn't have Adobe APP14 metadata",
    )
  }
  let img = @image.new_image_cmyk(rect)
  for y in 0..<d.height {
    for x in 0..<d.width {
      if d.adobe_transform == adobe_transform_unknown {
        img.set_cmyk(x, y, {
          c: (255 -
          sample_component_with_max(
            d, comp_data, comp_width, max_h, max_v, 0, x, y,
          ).to_int()).to_byte(),
          m: (255 -
          sample_component_with_max(
            d, comp_data, comp_width, max_h, max_v, 1, x, y,
          ).to_int()).to_byte(),
          y: (255 -
          sample_component_with_max(
            d, comp_data, comp_width, max_h, max_v, 2, x, y,
          ).to_int()).to_byte(),
          k: (255 -
          sample_component_with_max(
            d, comp_data, comp_width, max_h, max_v, 3, x, y,
          ).to_int()).to_byte(),
        })
      } else {
        let yy = sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 0, x, y,
        )
        let cb = sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 1, x, y,
        )
        let cr = sample_component_with_max(
          d, comp_data, comp_width, max_h, max_v, 2, x, y,
        )
        let (c, m, yv) = @color.ycbcr_to_rgb(yy, cb, cr)
        img.set_cmyk(x, y, {
          c,
          m,
          y: yv,
          k: (255 -
          sample_component_with_max(
            d, comp_data, comp_width, max_h, max_v, 3, x, y,
          ).to_int()).to_byte(),
        })
      }
    }
  }
  img
}

///|
fn consume_restart_marker(
  d : Decoder,
  expected_rst : UInt,
) -> Unit raise JpegError {
  let b0 = d.r.read_byte()
  let b1 = d.r.read_byte()
  if b0 != b'\xFF' || (0xFF00U | b1.to_uint()) != expected_rst {
    find_restart_marker(d, b0, b1, expected_rst)
  }
}

///|
fn find_restart_marker(
  d : Decoder,
  b0 : Byte,
  b1 : Byte,
  expected_rst : UInt,
) -> Unit raise JpegError {
  let mut b0 = b0
  let mut b1 = b1
  while true {
    let mut shift_by_one = false
    if b0 == b'\xFF' {
      if (0xFF00U | b1.to_uint()) == expected_rst {
        return
      }
      if b1 == b'\xFF' {
        shift_by_one = true
      } else if b1 != b'\x00' {
        raise JpegError::FormatError("bad RST marker")
      }
    } else if b1 == b'\xFF' {
      b0 = b'\xFF'
      shift_by_one = true
    }
    if shift_by_one {
      b1 = d.r.read_byte()
    } else {
      b0 = d.r.read_byte()
      b1 = d.r.read_byte()
    }
  }
}
