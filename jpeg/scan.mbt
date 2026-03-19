///|
/// Process a SOS segment and decode the scan data, returning the final image.
pub fn process_sos(d : Decoder) -> @image.AnyImage raise JpegError {
  let length = d.r.read_uint16_be()
  let _seg_len = length.reinterpret_as_int() - 2
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
      if d.comp[j].id == cs {
        d.comp[j].dc_huff_idx = td
        d.comp[j].ac_huff_idx = ta
        found = true
      }
    }
    if !found {
      // Try by position
      if i < d.num_components {
        d.comp[i].dc_huff_idx = td
        d.comp[i].ac_huff_idx = ta
      }
    }
  }
  // Skip Ss, Se, Ah, Al
  let _ss = d.r.read_byte()
  let _se = d.r.read_byte()
  let _ah_al = d.r.read_byte()
  // Reset DC predictors
  for i in 0..<d.num_components {
    d.comp[i].dc_pred = 0
  }
  // Flush bit buffer
  flush_bits(d)
  // Compute MCU grid dimensions
  // Find max H and V sampling factors
  let mut max_h = 1
  let mut max_v = 1
  for i in 0..<d.num_components {
    if d.comp[i].h > max_h {
      max_h = d.comp[i].h
    }
    if d.comp[i].v > max_v {
      max_v = d.comp[i].v
    }
  }
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
    let cw = mcu_cols * d.comp[i].h * 8
    let ch = mcu_rows * d.comp[i].v * 8
    comp_width[i] = cw
    comp_height[i] = ch
    comp_data[i] = FixedArray::make(cw * ch, b'\x00')
  }
  // Block and idct buffers
  let block = FixedArray::make(64, 0)
  let idct_out = FixedArray::make(64, b'\x00')
  let mut mcu_count = 0
  // Decode MCUs
  for mcu_y in 0..<mcu_rows {
    for mcu_x in 0..<mcu_cols {
      // Check for restart
      if d.restart_interval > 0 {
        if mcu_count > 0 && mcu_count % d.restart_interval == 0 {
          // Read restart marker
          flush_bits(d)
          // Reset DC predictors
          for i in 0..<d.num_components {
            d.comp[i].dc_pred = 0
          }
          // Consume the restart marker
          consume_restart_marker(d)
        }
      }
      mcu_count += 1
      // Decode each component's data units in this MCU
      for ci in 0..<d.num_components {
        let h = d.comp[ci].h
        let v = d.comp[ci].v
        for vy in 0..<v {
          for hx in 0..<h {
            // Decode one 8x8 block
            decode_block(d, ci, block)
            // Dequantize
            let qt_idx = d.comp[ci].qt
            for k in 0..<64 {
              block[k] = block[k] * d.quant[qt_idx].data[unzig[k]]
            }
            // Reorder from zig-zag to natural order for IDCT
            let nat = FixedArray::make(64, 0)
            for k in 0..<64 {
              nat[unzig[k]] = block[k]
            }
            // IDCT
            idct(nat, idct_out)
            // Write to comp_data
            let block_x = mcu_x * h + hx
            let block_y = mcu_y * v + vy
            let cw = comp_width[ci]
            for py in 0..<8 {
              for px in 0..<8 {
                let cx = block_x * 8 + px
                let cy = block_y * 8 + py
                if cx < cw && cy < comp_height[ci] {
                  comp_data[ci][cy * cw + cx] = idct_out[py * 8 + px]
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
    min: { x: 0, y: 0 },
    max: { x: d.width, y: d.height },
  }
  if d.num_components == 1 {
    // Grayscale
    let img = @image.new_image_gray(rect)
    for y in 0..<d.height {
      for x in 0..<d.width {
        img.pix[y * img.stride + x] = comp_data[0][y * comp_width[0] + x]
      }
    }
    @image.AnyImage::Gray(img)
  } else {
    // YCbCr -> RGBA
    let img = @image.new_image_rgba(rect)
    // Chroma subsampling ratios
    let y_w = comp_width[0]
    let cb_w = comp_width[1]
    let cr_w = comp_width[2]
    let full_h = comp_height[0]
    let cb_h = comp_height[1]
    for y in 0..<d.height {
      for x in 0..<d.width {
        let yv = comp_data[0][y * y_w + x]
        // Map pixel coordinates to chroma sample coordinates
        let cx = if cb_w < y_w { x * cb_w / y_w } else { x }
        let cy = if cb_h < full_h { y * cb_h / full_h } else { y }
        let cbv = comp_data[1][cy * cb_w + cx]
        let crv = comp_data[2][cy * cr_w + cx]
        let (r, g, b) = @color.ycbcr_to_rgb(yv, cbv, crv)
        let di = y * img.stride + x * 4
        img.pix[di] = r
        img.pix[di + 1] = g
        img.pix[di + 2] = b
        img.pix[di + 3] = b'\xff'
      }
    }
    @image.AnyImage::RGBA(img)
  }
}

///|
/// Decode one 8x8 DCT block for component ci.
/// Fills block[] with 64 dequantized-but-zigzag-ordered coefficients.
fn decode_block(
  d : Decoder,
  ci : Int,
  block : FixedArray[Int]
) -> Unit raise JpegError {
  // Zero out block
  for k in 0..<64 {
    block[k] = 0
  }
  let dc_table = d.huff[0][d.comp[ci].dc_huff_idx]
  let ac_table = d.huff[1][d.comp[ci].ac_huff_idx]
  // Decode DC coefficient
  let dc_size = decode_huffman(d, dc_table)
  let dc_diff = receive_and_extend(d, dc_size)
  d.comp[ci].dc_pred = d.comp[ci].dc_pred + dc_diff
  block[0] = d.comp[ci].dc_pred
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
      block[k] = coeff
      k = k + 1
    }
  }
}

///|
/// After a restart marker is expected, consume the RST marker bytes.
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
