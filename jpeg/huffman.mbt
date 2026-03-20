///|
/// Build a Huffman table from DHT segment data.
/// bits_count[i] = number of codes of length i+1 (for i in 0..15)
/// symbols = list of symbol values
pub fn build_huffman_table(
  table : HuffmanTable,
  bits_count : FixedArray[Int],
  symbols : FixedArray[Int],
) -> Unit raise JpegError {
  // Copy num_codes
  for i in 0..<16 {
    table.num_codes.unsafe_set(i, bits_count[i])
  }
  // Copy symbols
  let mut sym_idx = 0
  for i in 0..<16 {
    for _ in 0..<bits_count.unsafe_get(i) {
      if sym_idx >= 256 {
        raise JpegError::FormatError("too many Huffman symbols")
      }
      table.symbols.unsafe_set(sym_idx, symbols[sym_idx])
      sym_idx += 1
    }
  }
  // Build min_code, max_code, val_ptr
  let mut code = 0
  let mut si = 0
  for i in 0..<16 {
    let n = bits_count.unsafe_get(i)
    if n == 0 {
      table.min_code.unsafe_set(i, 0)
      table.max_code.unsafe_set(i, -1)
      table.val_ptr.unsafe_set(i, 0)
    } else {
      table.min_code.unsafe_set(i, code)
      table.val_ptr.unsafe_set(i, si)
      code = code + n
      table.max_code.unsafe_set(i, code - 1)
      si = si + n
    }
    code = code << 1
  }
}

///|
/// Read n bits from the JPEG byte stream (with 0xFF byte-stuffing removal).
/// Fills bits.buf and bits.n.
fn ensure_bits(d : Decoder, n : Int) -> Unit raise JpegError {
  while d.bits.n < n {
    let b = d.r.read_byte()
    if b == b'\xFF' {
      // JPEG byte-stuffing: 0xFF followed by 0x00 means literal 0xFF
      let next = d.r.read_byte()
      if next != b'\x00' {
        // Could be a restart marker — put both bytes back by adjusting pos
        // We treat this as end of entropy-coded data
        d.r.pos -= 2
        // Fill remaining bits with zeros to avoid infinite loop
        d.bits.buf = d.bits.buf << (n - d.bits.n)
        d.bits.n = n
        return
      }
    }
    d.bits.buf = (d.bits.buf << 8) | b.to_int()
    d.bits.n = d.bits.n + 8
  }
}

///|
/// Peek at the top n bits without consuming them.
fn peek_bits(d : Decoder, n : Int) -> Int raise JpegError {
  ensure_bits(d, n)
  (d.bits.buf >> (d.bits.n - n)) & ((1 << n) - 1)
}

///|
/// Consume n bits.
fn consume_bits(d : Decoder, n : Int) -> Unit {
  d.bits.n = d.bits.n - n
  d.bits.buf = d.bits.buf & ((1 << d.bits.n) - 1)
}

///|
/// Read and return n bits as an integer.
fn read_bits(d : Decoder, n : Int) -> Int raise JpegError {
  if n == 0 {
    return 0
  }
  let v = peek_bits(d, n)
  consume_bits(d, n)
  v
}

///|
/// Decode one Huffman-coded symbol from the bit stream.
pub fn decode_huffman(d : Decoder, table : HuffmanTable) -> Int raise JpegError {
  // Fast path: peek 8 bits, check if any code of length 1..8 matches.
  // Most JPEG Huffman codes are ≤8 bits, so this resolves ~95% of symbols
  // with a single peek + compare chain instead of 1-bit-at-a-time loop.
  ensure_bits(d, 8)
  let peek = peek_bits(d, 8)
  let mut code = 0
  for i in 0..<8 {
    code = (code << 1) | ((peek >> (7 - i)) & 1)
    if table.max_code.unsafe_get(i) >= 0 && code <= table.max_code.unsafe_get(i) {
      consume_bits(d, i + 1)
      let idx = table.val_ptr.unsafe_get(i) + code - table.min_code.unsafe_get(i)
      return table.symbols.unsafe_get(idx)
    }
  }
  // Slow path for codes > 8 bits (rare)
  consume_bits(d, 8)
  for i in 8..<16 {
    let bit = read_bits(d, 1)
    code = (code << 1) | bit
    if table.max_code.unsafe_get(i) >= 0 && code <= table.max_code.unsafe_get(i) {
      let idx = table.val_ptr.unsafe_get(i) + code - table.min_code.unsafe_get(i)
      return table.symbols.unsafe_get(idx)
    }
  }
  raise JpegError::FormatError("invalid Huffman code")
}

///|
/// Read n bits and return as a signed value (for DC/AC coefficients).
/// This implements the JPEG "receive and extend" operation.
fn receive_and_extend(d : Decoder, n : Int) -> Int raise JpegError {
  if n == 0 {
    return 0
  }
  let v = read_bits(d, n)
  // If top bit is 0, value is negative: subtract (2^n - 1)
  if v < 1 << (n - 1) {
    v - (1 << n) + 1
  } else {
    v
  }
}

///|
/// Flush the remaining bits in the bit reader (used after restart markers).
fn flush_bits(d : Decoder) -> Unit {
  d.bits.buf = 0
  d.bits.n = 0
}
