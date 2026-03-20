///|
pub(all) suberror PngError {
  FormatError(String)
  UnsupportedError(String)
  UnexpectedEOF
} derive(Show)

///|
let png_header : FixedArray[Byte] = [
  b'\x89', b'\x50', b'\x4e', b'\x47', b'\x0d', b'\x0a', b'\x1a', b'\x0a',
]

///|
// Chunk types
let ct_ihdr : UInt = 0x49484452U // "IHDR"

///|
let ct_plte : UInt = 0x504c5445U // "PLTE"

///|
let ct_trns : UInt = 0x74524e53U // "tRNS"

///|
let ct_idat : UInt = 0x49444154U // "IDAT"

///|
let ct_iend : UInt = 0x49454e44U // "IEND"

///|
// Color type constants
let ct_grayscale : Byte = b'\x00'

///|
let ct_true_color : Byte = b'\x02'

///|
let ct_paletted : Byte = b'\x03'

///|
let ct_grayscale_alpha : Byte = b'\x04'

///|
let ct_true_color_alpha : Byte = b'\x06'

///|
// Filter types
let ft_none : Byte = b'\x00'

///|
let ft_sub : Byte = b'\x01'

///|
let ft_up : Byte = b'\x02'

///|
let ft_average : Byte = b'\x03'

///|
let ft_paeth : Byte = b'\x04'

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
pub fn ByteReader::read_byte(self : ByteReader) -> Byte raise PngError {
  if self.pos >= self.data.length() {
    raise UnexpectedEOF
  }
  let b = self.data.unsafe_get(self.pos)
  self.pos = self.pos + 1
  b
}

///|
pub fn ByteReader::read_bytes(
  self : ByteReader,
  n : Int,
) -> Bytes raise PngError {
  if self.pos + n > self.data.length() {
    raise UnexpectedEOF
  }
  let buf = @buffer.new(size_hint=n)
  for i in 0..<n {
    buf.write_byte(self.data.unsafe_get(self.pos + i))
  }
  self.pos = self.pos + n
  buf.to_bytes()
}

///|
pub fn ByteReader::read_uint32_be(self : ByteReader) -> UInt raise PngError {
  if self.pos + 4 > self.data.length() {
    raise UnexpectedEOF
  }
  let v = @binary.read_uint32_be_bytes(self.data, self.pos)
  self.pos = self.pos + 4
  v
}

///|
pub fn ByteReader::skip(self : ByteReader, n : Int) -> Unit raise PngError {
  if self.pos + n > self.data.length() {
    raise UnexpectedEOF
  }
  self.pos = self.pos + n
}
