///|
pub(all) suberror JpegError {
  FormatError(String)
  UnsupportedError(String)
  UnexpectedEOF
} derive(Show)

///|
// JPEG marker constants
let marker_soi : UInt = 0xFFD8U // Start of Image

///|
let marker_eoi : UInt = 0xFFD9U // End of Image

///|
let marker_sof0 : UInt = 0xFFC0U // Start of Frame (Baseline DCT)

///|
let marker_sof1 : UInt = 0xFFC1U // Start of Frame (Extended Sequential DCT)

///|
let marker_sof2 : UInt = 0xFFC2U // Start of Frame (Progressive DCT)

///|
let marker_dht : UInt = 0xFFC4U // Define Huffman Table

///|
let marker_dqt : UInt = 0xFFDBU // Define Quantization Table

///|
let marker_sos : UInt = 0xFFDAU // Start of Scan

///|
let marker_dri : UInt = 0xFFDDU // Define Restart Interval

///|
let marker_rst0 : UInt = 0xFFD0U // Restart Marker 0

///|
let marker_rst7 : UInt = 0xFFD7U // Restart Marker 7

///|
let marker_app0 : UInt = 0xFFE0U // Application-specific 0

///|
let marker_app15 : UInt = 0xFFEFU // Application-specific 15

///|
let marker_com : UInt = 0xFFFEU // Comment

///|
/// Standard JPEG zig-zag order for 8x8 blocks
let unzig : FixedArray[Int] = [
  0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
  41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15,
  23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62,
  63,
]

///|
/// ByteReader wraps Bytes with a position cursor.
pub(all) struct ByteReader {
  data : Bytes
  mut pos : Int
}

///|
pub fn ByteReader::new(data : Bytes) -> ByteReader {
  { data, pos: 0 }
}

///|
pub fn ByteReader::remaining(self : ByteReader) -> Int {
  self.data.length() - self.pos
}

///|
pub fn ByteReader::read_byte(self : ByteReader) -> Byte raise JpegError {
  if self.pos >= self.data.length() {
    raise UnexpectedEOF
  }
  let b = self.data.unsafe_get(self.pos)
  self.pos += 1
  b
}

///|
pub fn ByteReader::read_bytes(
  self : ByteReader,
  n : Int,
) -> Bytes raise JpegError {
  if self.pos + n > self.data.length() {
    raise UnexpectedEOF
  }
  let buf = @blit.Buffer::new(size_hint=n)
  for i in 0..<n {
    buf.write_byte(self.data.unsafe_get(self.pos + i))
  }
  self.pos += n
  buf.to_bytes()
}

///|
pub fn ByteReader::read_uint16_be(self : ByteReader) -> UInt raise JpegError {
  if self.pos + 2 > self.data.length() {
    raise UnexpectedEOF
  }
  let v = @binary.read_uint16_be_bytes(self.data, self.pos)
  self.pos += 2
  v
}

///|
pub fn ByteReader::skip(self : ByteReader, n : Int) -> Unit raise JpegError {
  if self.pos + n > self.data.length() {
    raise UnexpectedEOF
  }
  self.pos += n
}

///|
pub fn ByteReader::peek_byte(self : ByteReader) -> Byte raise JpegError {
  if self.pos >= self.data.length() {
    raise UnexpectedEOF
  }
  self.data.unsafe_get(self.pos)
}

///|
/// A quantization table: 64 uint16 values in natural (row-major) order.
pub(all) struct QuantTable {
  data : FixedArray[Int]
}

///|
pub fn QuantTable::new() -> QuantTable {
  { data: FixedArray::make(64, 0) }
}

///|
/// HuffmanTable stores a decoded JPEG Huffman table.
pub(all) struct HuffmanTable {
  // For each symbol length (1..16), the list of symbols
  // num_codes[i] = number of codes of length i+1
  num_codes : FixedArray[Int]
  // Flat list of symbols in order
  symbols : FixedArray[Int]
  // For fast decoding: minCode[i], maxCode[i], valPtr[i] for length i+1
  min_code : FixedArray[Int]
  max_code : FixedArray[Int]
  val_ptr : FixedArray[Int]
}

///|
pub fn HuffmanTable::new() -> HuffmanTable {
  {
    num_codes: FixedArray::make(16, 0),
    symbols: FixedArray::make(256, 0),
    min_code: FixedArray::make(16, 0),
    max_code: FixedArray::make(16, -1),
    val_ptr: FixedArray::make(16, 0),
  }
}

///|
/// Decoder state for JPEG decoding.
pub(all) struct Decoder {
  r : ByteReader
  quant : FixedArray[QuantTable]
  huff : FixedArray[FixedArray[HuffmanTable]]
  mut num_components : Int
  comp : FixedArray[Component]
  mut width : Int
  mut height : Int
  mut restart_interval : Int
  bits : BitReader
  // Progressive JPEG state
  mut progressive : Bool
  mut eob_run : Int
  // progCoeffs[compIndex] = array of 64-int blocks, one per 8x8 block
  prog_coeffs : FixedArray[Array[FixedArray[Int]]]
}

///|
pub(all) struct Component {
  mut id : Int
  mut h : Int // Horizontal sampling factor
  mut v : Int // Vertical sampling factor
  mut qt : Int // Quantization table index
  mut dc_huff_idx : Int
  mut ac_huff_idx : Int
  mut dc_pred : Int // DC prediction value
}

///|
pub fn Component::new() -> Component {
  { id: 0, h: 1, v: 1, qt: 0, dc_huff_idx: 0, ac_huff_idx: 0, dc_pred: 0 }
}

///|
/// BitReader reads individual bits from a byte stream (with JPEG byte-stuffing).
pub(all) struct BitReader {
  mut buf : Int // bit buffer
  mut n : Int // number of valid bits in buf
}

///|
pub fn BitReader::new() -> BitReader {
  { buf: 0, n: 0 }
}

///|
pub fn Decoder::new(data : Bytes) -> Decoder {
  let quant = FixedArray::make(4, QuantTable::new())
  for i in 0..<4 {
    quant.unsafe_set(i, QuantTable::new())
  }
  let huff : FixedArray[FixedArray[HuffmanTable]] = FixedArray::make(
    2,
    FixedArray::make(4, HuffmanTable::new()),
  )
  for tc in 0..<2 {
    let row = FixedArray::make(4, HuffmanTable::new())
    for th in 0..<4 {
      row.unsafe_set(th, HuffmanTable::new())
    }
    huff.unsafe_set(tc, row)
  }
  let comp = FixedArray::make(3, Component::new())
  for i in 0..<3 {
    comp.unsafe_set(i, Component::new())
  }
  let prog_coeffs : FixedArray[Array[FixedArray[Int]]] = FixedArray::make(4, [])
  {
    r: ByteReader::new(data),
    quant,
    huff,
    num_components: 0,
    comp,
    width: 0,
    height: 0,
    restart_interval: 0,
    bits: BitReader::new(),
    progressive: false,
    eob_run: 0,
    prog_coeffs,
  }
}
