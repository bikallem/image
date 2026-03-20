///|
pub(all) suberror GifError {
  FormatError(String)
  UnsupportedError(String)
  UnexpectedEOF
} derive(Show)

///|
/// GIF represents the multiple frames of a GIF image.
pub(all) struct GIF {
  image : Array[@image.ImagePaletted]
  delay : Array[Int]
  loop_count : Int
  disposal : Array[Byte]
  background_index : Byte
  config : @image.Config
}

///|
// GIF signature
let gif87a : String = "GIF87a"

///|
let gif89a : String = "GIF89a"

///|
// Block types
let ext_introducer : Byte = b'\x21'

///|
let image_descriptor : Byte = b'\x2c'

///|
let trailer : Byte = b'\x3b'

///|
// Extension labels
let ext_graphic_control : Byte = b'\xf9'

///|
let ext_application : Byte = b'\xff'

///|
/// Disposal methods
pub let disposal_none : Byte = b'\x00'

///|
pub let disposal_background : Byte = b'\x01'

///|
pub let disposal_previous : Byte = b'\x02'

///|
priv struct GifByteReader {
  data : Bytes
  mut pos : Int
}

///|
fn GifByteReader::new(data : Bytes) -> GifByteReader {
  { data, pos: 0 }
}

///|
fn GifByteReader::remaining(self : GifByteReader) -> Int {
  self.data.length() - self.pos
}

///|
fn GifByteReader::read_byte(self : GifByteReader) -> Byte raise GifError {
  if self.pos >= self.data.length() {
    raise UnexpectedEOF
  }
  let b = self.data[self.pos]
  self.pos = self.pos + 1
  b
}

///|
fn GifByteReader::read_uint16_le(self : GifByteReader) -> UInt raise GifError {
  if self.pos + 2 > self.data.length() {
    raise UnexpectedEOF
  }
  let v = @binary.read_uint16_le_bytes(self.data, self.pos)
  self.pos = self.pos + 2
  v
}

///|
fn GifByteReader::read_bytes(
  self : GifByteReader,
  n : Int,
) -> Bytes raise GifError {
  if self.pos + n > self.data.length() {
    raise UnexpectedEOF
  }
  let buf = @buffer.new(size_hint=n)
  for i in 0..<n {
    buf.write_byte(self.data[self.pos + i])
  }
  self.pos = self.pos + n
  buf.to_bytes()
}

///|
fn GifByteReader::skip(self : GifByteReader, n : Int) -> Unit raise GifError {
  if self.pos + n > self.data.length() {
    raise UnexpectedEOF
  }
  self.pos = self.pos + n
}
