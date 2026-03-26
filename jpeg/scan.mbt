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
/// Process a SOS segment and decode the scan data, returning the final image.
pub fn process_sos(d : Decoder) -> @image.AnyImage raise JpegError {
  let length = d.r.read_uint16_be()
  ignore(length)
  let ns = d.r.read_byte().to_int() // number of components in scan
  if ns != d.num_components {
    raise JpegError::UnsupportedError(
      "scan component count mismatch: expected " +
      d.num_components.to_string() +
      ", got " +
      ns.to_string(),
    )
  }
  // Read scan component selectors
  for i in 0..<ns {
    let cs = d.r.read_byte().to_int() // component selector
    let td_ta = d.r.read_byte().to_int()
    let td = (td_ta >> 4) & 0x0F // DC table index
    let ta = td_ta & 0x0F // AC table index
    // Find matching component
    let mut found = false
    for j in 0..<d.num_components {
      if d.comp.unsafe_get(j).id == cs {
        d.comp.unsafe_get(j).dc_huff_idx = td
        d.comp.unsafe_get(j).ac_huff_idx = ta
        found = true
      }
    }
    if !found {
      // Try by position
      if i < d.num_components {
        d.comp.unsafe_get(i).dc_huff_idx = td
        d.comp.unsafe_get(i).ac_huff_idx = ta
      }
    }
  }
  // Skip Ss, Se, Ah|Al
  d.r.skip(3)
  reset_dc_preds(d)
  // Flush bit buffer
  flush_bits(d)
  // Compute MCU grid dimensions
  let (max_h, max_v) = max_sampling(d)
  let mcu_width = max_h * 8
  let mcu_height = max_v * 8
  let mcu_cols = (d.width + mcu_width - 1) / mcu_width
  let mcu_rows = (d.height + mcu_height - 1) / mcu_height
  // Allocate output planes
  // For each component: width_comp x height_comp sample array
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
  // Block and idct buffers — allocated once, reused per block
  let block = @blit.make_uninit_int(64)
  let nat = @blit.make_uninit_int(64)
  let idct_out = @blit.make_uninit(64)
  let idct_ws = FixedArray::make(64, 0)
  let mut mcu_count = 0
  // Decode MCUs
  for mcu_y in 0..<mcu_rows {
    for mcu_x in 0..<mcu_cols {
      // Check for restart
      if d.restart_interval > 0 {
        if mcu_count > 0 && mcu_count % d.restart_interval == 0 {
          // Read restart marker
          flush_bits(d)
          reset_dc_preds(d)
          // Consume the restart marker
          consume_restart_marker(d)
        }
      }
      mcu_count += 1
      // Decode each component's data units in this MCU
      for ci in 0..<d.num_components {
        let h = d.comp.unsafe_get(ci).h
        let v = d.comp.unsafe_get(ci).v
        for vy in 0..<v {
          for hx in 0..<h {
            // Decode one 8x8 block
            decode_block(d, ci, block)
            // Dequantize and reorder to natural order in one step
            // (matching Go's reconstructBlock: b[unzig[zig]] *= qt[zig])
            let qt_idx = d.comp.unsafe_get(ci).qt
            for k in 0..<64 {
              nat.unsafe_set(k, 0)
            }
            for k in 0..<64 {
              nat.unsafe_set(
                unzig.unsafe_get(k),
                block.unsafe_get(k) *
                d.quant.unsafe_get(qt_idx).data.unsafe_get(k),
              )
            }
            // IDCT
            idct_islow(nat, idct_out, idct_ws)
            // Write to comp_data
            let block_x = mcu_x * h + hx
            let block_y = mcu_y * v + vy
            let cw = comp_width.unsafe_get(ci)
            for py in 0..<8 {
              for px in 0..<8 {
                let cx = block_x * 8 + px
                let cy = block_y * 8 + py
                if cx < cw && cy < comp_height.unsafe_get(ci) {
                  comp_data.unsafe_get(ci)[cy * cw + cx] = idct_out.unsafe_get(
                    py * 8 + px,
                  )
                }
              }
            }
          }
        }
      }
    }
  }
  // Build output image
  let rect : @image.Rectangle = {
    min_x: 0,
    min_y: 0,
    max_x: d.width,
    max_y: d.height,
  }
  if d.num_components == 1 {
    // Grayscale
    let img = @image.new_image_gray(rect)
    for y in 0..<d.height {
      for x in 0..<d.width {
        img.pix.unsafe_set(
          y * img.stride + x,
          comp_data.unsafe_get(0)[y * comp_width.unsafe_get(0) + x],
        )
      }
    }
    @image.AnyImage::Gray(img)
  } else {
    build_output_image(d, comp_data, comp_width, comp_height, rect)
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
/// Process a SOS segment for progressive JPEG.
/// Stores coefficients into d.prog_coeffs instead of IDCT-ing.
fn process_sos_progressive(d : Decoder) -> Unit raise JpegError {
  ignore(d.r.read_uint16_be()) // segment length
  let ns = d.r.read_byte().to_int()
  // Read scan component selectors
  let scan_comp = FixedArray::make(ns, 0) // component index for each scan component
  for i in 0..<ns {
    let cs = d.r.read_byte().to_int()
    let td_ta = d.r.read_byte().to_int()
    let td = (td_ta >> 4) & 0x0F
    let ta = td_ta & 0x0F
    let mut ci = -1
    for j in 0..<d.num_components {
      if d.comp.unsafe_get(j).id == cs {
        ci = j
        d.comp.unsafe_get(j).dc_huff_idx = td
        d.comp.unsafe_get(j).ac_huff_idx = ta
      }
    }
    if ci < 0 {
      ci = i
      d.comp.unsafe_get(i).dc_huff_idx = td
      d.comp.unsafe_get(i).ac_huff_idx = ta
    }
    scan_comp.unsafe_set(i, ci)
  }
  let ss = d.r.read_byte().to_int() // spectral selection start
  let se = d.r.read_byte().to_int() // spectral selection end
  let ah_al = d.r.read_byte().to_int()
  let ah = (ah_al >> 4) & 0x0F // successive approximation high
  let al = ah_al & 0x0F // successive approximation low
  // Reset bit buffer
  flush_bits(d)
  d.eob_run = 0
  // Compute MCU grid
  let (max_h, max_v) = max_sampling(d)
  let mcu_cols = (d.width + max_h * 8 - 1) / (max_h * 8)
  let mcu_rows = (d.height + max_v * 8 - 1) / (max_v * 8)
  // Allocate prog_coeffs if needed
  for i in 0..<ns {
    let ci = scan_comp.unsafe_get(i)
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
  reset_dc_preds(d)
  // Decode scan
  let mut mcu_count = 0
  let mut block_count = 0
  for my in 0..<mcu_rows {
    for mx in 0..<mcu_cols {
      // Restart handling
      if d.restart_interval > 0 &&
        mcu_count > 0 &&
        mcu_count % d.restart_interval == 0 {
        flush_bits(d)
        reset_dc_preds(d)
        consume_restart_marker(d)
        d.eob_run = 0
      }
      mcu_count += 1
      for si in 0..<ns {
        let ci = scan_comp.unsafe_get(si)
        let hi = d.comp.unsafe_get(ci).h
        let vi = d.comp.unsafe_get(ci).v
        let n_blocks = hi * vi
        for j in 0..<n_blocks {
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
          if block_idx >= d.prog_coeffs.unsafe_get(ci).length() {
            continue
          }
          let b = d.prog_coeffs.unsafe_get(ci)[block_idx]
          if ah != 0 {
            // Successive approximation refinement — simplified: just read bits
            if ss == 0 {
              // DC refinement
              let bit = read_bit(d)
              if bit {
                b.unsafe_set(0, b.unsafe_get(0) | (1 << al))
              }
            } else {
              // AC refinement — complex, skip for now
              refine_ac(d, b, ss, se, al, ci)
            }
          } else {
            // First pass for these coefficients
            let mut zig = ss
            if zig == 0 {
              // DC coefficient
              let dc_table = d.huff.unsafe_get(0)[d.comp.unsafe_get(ci).dc_huff_idx]
              let dc_size = decode_huffman(d, dc_table)
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
        }
      }
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
  // Simplified AC refinement: read and apply bits
  let delta = 1 << al
  let ac_table = d.huff.unsafe_get(1)[d.comp.unsafe_get(ci).ac_huff_idx]
  let mut zig = ss
  if d.eob_run == 0 {
    while zig <= se {
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
          break
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
      // Skip val0 zero coefficients, refining non-zero ones
      let mut nz = val0
      while zig <= se {
        let u = unzig.unsafe_get(zig)
        if b.unsafe_get(u) == 0 {
          if nz == 0 {
            break
          }
          nz -= 1
        } else {
          let bit = read_bit(d)
          if bit {
            if b.unsafe_get(u) >= 0 {
              b.unsafe_set(u, b.unsafe_get(u) + delta)
            } else {
              b.unsafe_set(u, b.unsafe_get(u) - delta)
            }
          }
        }
        zig += 1
      }
      if zig <= se && z != 0 {
        b.unsafe_set(unzig.unsafe_get(zig), z)
      }
      zig += 1
    }
  }
  if d.eob_run > 0 {
    d.eob_run -= 1
    // Refine existing non-zero coefficients
    while zig <= se {
      let u = unzig.unsafe_get(zig)
      if b.unsafe_get(u) != 0 {
        let bit = read_bit(d)
        if bit {
          if b.unsafe_get(u) >= 0 {
            b.unsafe_set(u, b.unsafe_get(u) + delta)
          } else {
            b.unsafe_set(u, b.unsafe_get(u) - delta)
          }
        }
      }
      zig += 1
    }
  }
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
fn reconstruct_progressive(d : Decoder) -> @image.AnyImage raise JpegError {
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
    @image.AnyImage::Gray(img)
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
) -> @image.AnyImage raise JpegError {
  ignore(comp_height)
  if d.num_components == 4 {
    components_to_cmyk(d, comp_data, comp_width, rect)
  } else if is_rgb_jpeg(d) {
    rgb_to_rgba(d, comp_data, comp_width, rect)
  } else {
    ycbcr_to_rgba(d, comp_data, comp_width, comp_height, rect)
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
fn sample_component(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  ci : Int,
  x : Int,
  y : Int,
) -> Byte {
  let h_ratio = d.comp.unsafe_get(0).h / d.comp.unsafe_get(ci).h
  let v_ratio = d.comp.unsafe_get(0).v / d.comp.unsafe_get(ci).v
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
) -> @image.AnyImage {
  let img = @image.new_image_rgba(rect)
  for y in 0..<d.height {
    let di_row = y * img.stride
    for x in 0..<d.width {
      let di = di_row + x * 4
      img.pix.unsafe_set(
        di,
        sample_component(d, comp_data, comp_width, 0, x, y),
      )
      img.pix.unsafe_set(
        di + 1,
        sample_component(d, comp_data, comp_width, 1, x, y),
      )
      img.pix.unsafe_set(
        di + 2,
        sample_component(d, comp_data, comp_width, 2, x, y),
      )
      img.pix.unsafe_set(di + 3, b'\xff')
    }
  }
  @image.AnyImage::RGBA(img)
}

///|
fn components_to_cmyk(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  rect : @image.Rectangle,
) -> @image.AnyImage raise JpegError {
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
          c: (255 - sample_component(d, comp_data, comp_width, 0, x, y).to_int()).to_byte(),
          m: (255 - sample_component(d, comp_data, comp_width, 1, x, y).to_int()).to_byte(),
          y: (255 - sample_component(d, comp_data, comp_width, 2, x, y).to_int()).to_byte(),
          k: (255 - sample_component(d, comp_data, comp_width, 3, x, y).to_int()).to_byte(),
        })
      } else {
        let yy = sample_component(d, comp_data, comp_width, 0, x, y)
        let cb = sample_component(d, comp_data, comp_width, 1, x, y)
        let cr = sample_component(d, comp_data, comp_width, 2, x, y)
        let (c, m, yv) = @color.ycbcr_to_rgb(yy, cb, cr)
        img.set_cmyk(x, y, {
          c,
          m,
          y: yv,
          k: (255 - sample_component(d, comp_data, comp_width, 3, x, y).to_int()).to_byte(),
        })
      }
    }
  }
  @image.AnyImage::CMYK(img)
}

///|
/// Build RGBA image from YCbCr component planes with fancy chroma upsampling.
/// Uses triangle filter (9:3:3:1 weights for 4:2:0, 3:1 for 4:2:2/4:4:0)
/// matching libjpeg-turbo's default "fancy" upsampling for better visual quality.
fn ycbcr_to_rgba(
  d : Decoder,
  comp_data : FixedArray[FixedArray[Byte]],
  comp_width : FixedArray[Int],
  comp_height : FixedArray[Int],
  rect : @image.Rectangle,
) -> @image.AnyImage {
  let img = @image.new_image_rgba(rect)
  let y_w = comp_width.unsafe_get(0)
  let cb_w = comp_width.unsafe_get(1)
  let cr_w = comp_width.unsafe_get(2)
  let full_h = comp_height.unsafe_get(0)
  let cb_h = comp_height.unsafe_get(1)
  let y_data = comp_data.unsafe_get(0)
  let cb_data = comp_data.unsafe_get(1)
  let cr_data = comp_data.unsafe_get(2)
  let h_sub = cb_w < y_w
  let v_sub = cb_h < full_h
  let max_cx = cb_w - 1
  let max_cy = cb_h - 1
  // Hoist subsampling mode branch outside pixel loops
  if h_sub && v_sub {
    // 4:2:0 — bilinear from 4 neighbors with 9:3:3:1 weights
    for y in 0..<d.height {
      let y_row = y * y_w
      let di_row = y * img.stride
      let cy = y / 2
      let cy0 = if cy > 0 && (y & 1) == 0 { cy - 1 } else { cy }
      let cy1 = if cy < max_cy && (y & 1) != 0 { cy + 1 } else { cy }
      let cb_row0 = cy0 * cb_w
      let cb_row1 = cy1 * cb_w
      let cr_row0 = cy0 * cr_w
      let cr_row1 = cy1 * cr_w
      for x in 0..<d.width {
        let yv = y_data.unsafe_get(y_row + x)
        let cx = x / 2
        let cx0 = if cx > 0 && (x & 1) == 0 { cx - 1 } else { cx }
        let cx1 = if cx < max_cx && (x & 1) != 0 { cx + 1 } else { cx }
        let cb00 = cb_data.unsafe_get(cb_row0 + cx0).to_int()
        let cb01 = cb_data.unsafe_get(cb_row0 + cx1).to_int()
        let cb10 = cb_data.unsafe_get(cb_row1 + cx0).to_int()
        let cb11 = cb_data.unsafe_get(cb_row1 + cx1).to_int()
        let cr00 = cr_data.unsafe_get(cr_row0 + cx0).to_int()
        let cr01 = cr_data.unsafe_get(cr_row0 + cx1).to_int()
        let cr10 = cr_data.unsafe_get(cr_row1 + cx0).to_int()
        let cr11 = cr_data.unsafe_get(cr_row1 + cx1).to_int()
        let cbv = ((9 * cb00 + 3 * cb01 + 3 * cb10 + cb11 + 8) >> 4).to_byte()
        let crv = ((9 * cr00 + 3 * cr01 + 3 * cr10 + cr11 + 8) >> 4).to_byte()
        let (r, g, b) = @color.ycbcr_to_rgb(yv, cbv, crv)
        let di = di_row + x * 4
        img.pix.unsafe_set(di, r)
        img.pix.unsafe_set(di + 1, g)
        img.pix.unsafe_set(di + 2, b)
        img.pix.unsafe_set(di + 3, b'\xff')
      }
    }
  } else if h_sub {
    // 4:2:2 — horizontal-only with 3:1 weights
    for y in 0..<d.height {
      let y_row = y * y_w
      let di_row = y * img.stride
      let cb_row = y * cb_w
      let cr_row = y * cr_w
      for x in 0..<d.width {
        let yv = y_data.unsafe_get(y_row + x)
        let cx = x / 2
        let cx0 = if cx > 0 && (x & 1) == 0 { cx - 1 } else { cx }
        let cx1 = if cx < max_cx && (x & 1) != 0 { cx + 1 } else { cx }
        let cb0 = cb_data.unsafe_get(cb_row + cx0).to_int()
        let cb1 = cb_data.unsafe_get(cb_row + cx1).to_int()
        let cr0 = cr_data.unsafe_get(cr_row + cx0).to_int()
        let cr1 = cr_data.unsafe_get(cr_row + cx1).to_int()
        let cbv = ((3 * cb0 + cb1 + 2) >> 2).to_byte()
        let crv = ((3 * cr0 + cr1 + 2) >> 2).to_byte()
        let (r, g, b) = @color.ycbcr_to_rgb(yv, cbv, crv)
        let di = di_row + x * 4
        img.pix.unsafe_set(di, r)
        img.pix.unsafe_set(di + 1, g)
        img.pix.unsafe_set(di + 2, b)
        img.pix.unsafe_set(di + 3, b'\xff')
      }
    }
  } else if v_sub {
    // 4:4:0 — vertical-only with 3:1 weights
    for y in 0..<d.height {
      let y_row = y * y_w
      let di_row = y * img.stride
      let cy = y / 2
      let cy0 = if cy > 0 && (y & 1) == 0 { cy - 1 } else { cy }
      let cy1 = if cy < max_cy && (y & 1) != 0 { cy + 1 } else { cy }
      let cb_row0 = cy0 * cb_w
      let cb_row1 = cy1 * cb_w
      let cr_row0 = cy0 * cr_w
      let cr_row1 = cy1 * cr_w
      for x in 0..<d.width {
        let yv = y_data.unsafe_get(y_row + x)
        let cb0 = cb_data.unsafe_get(cb_row0 + x).to_int()
        let cb1 = cb_data.unsafe_get(cb_row1 + x).to_int()
        let cr0 = cr_data.unsafe_get(cr_row0 + x).to_int()
        let cr1 = cr_data.unsafe_get(cr_row1 + x).to_int()
        let cbv = ((3 * cb0 + cb1 + 2) >> 2).to_byte()
        let crv = ((3 * cr0 + cr1 + 2) >> 2).to_byte()
        let (r, g, b) = @color.ycbcr_to_rgb(yv, cbv, crv)
        let di = di_row + x * 4
        img.pix.unsafe_set(di, r)
        img.pix.unsafe_set(di + 1, g)
        img.pix.unsafe_set(di + 2, b)
        img.pix.unsafe_set(di + 3, b'\xff')
      }
    }
  } else {
    // 4:4:4 — no subsampling
    for y in 0..<d.height {
      let y_row = y * y_w
      let di_row = y * img.stride
      for x in 0..<d.width {
        let yv = y_data.unsafe_get(y_row + x)
        let cbv = cb_data.unsafe_get(y_row + x)
        let crv = cr_data.unsafe_get(y_row + x)
        let (r, g, b) = @color.ycbcr_to_rgb(yv, cbv, crv)
        let di = di_row + x * 4
        img.pix.unsafe_set(di, r)
        img.pix.unsafe_set(di + 1, g)
        img.pix.unsafe_set(di + 2, b)
        img.pix.unsafe_set(di + 3, b'\xff')
      }
    }
  }
  @image.AnyImage::RGBA(img)
}

///|
fn consume_restart_marker(d : Decoder) -> Unit raise JpegError {
  // Try to read a restart marker (0xFF 0xD0..0xD7)
  // If bytes don't look like a marker, skip silently
  if d.r.remaining() < 2 {
    return
  }
  let b0 = d.r.peek_byte()
  if b0 == b'\xFF' {
    d.r.pos += 1
    if d.r.remaining() > 0 {
      let b1 = d.r.read_byte()
      let m = 0xFF00U | b1.to_uint()
      if m < marker_rst0 || m > marker_rst7 {
        // Not a restart marker; put back
        d.r.pos -= 1
      }
    }
  }
}
