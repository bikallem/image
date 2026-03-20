///|
pub fn read_uint16_be(b : FixedArray[Byte], off : Int) -> UInt {
  (b.unsafe_get(off).to_uint() << 8) | b.unsafe_get(off + 1).to_uint()
}

///|
pub fn read_uint16_le(b : FixedArray[Byte], off : Int) -> UInt {
  b.unsafe_get(off).to_uint() | (b.unsafe_get(off + 1).to_uint() << 8)
}

///|
pub fn read_uint32_be(b : FixedArray[Byte], off : Int) -> UInt {
  (b.unsafe_get(off).to_uint() << 24) |
  (b.unsafe_get(off + 1).to_uint() << 16) |
  (b.unsafe_get(off + 2).to_uint() << 8) |
  b.unsafe_get(off + 3).to_uint()
}

///|
pub fn read_uint32_le(b : FixedArray[Byte], off : Int) -> UInt {
  b.unsafe_get(off).to_uint() |
  (b.unsafe_get(off + 1).to_uint() << 8) |
  (b.unsafe_get(off + 2).to_uint() << 16) |
  (b.unsafe_get(off + 3).to_uint() << 24)
}

///|
pub fn write_uint16_be(b : FixedArray[Byte], off : Int, v : UInt) -> Unit {
  b.unsafe_set(off, (v >> 8).to_byte())
  b.unsafe_set(off + 1, v.to_byte())
}

///|
pub fn write_uint16_le(b : FixedArray[Byte], off : Int, v : UInt) -> Unit {
  b.unsafe_set(off, v.to_byte())
  b.unsafe_set(off + 1, (v >> 8).to_byte())
}

///|
pub fn write_uint32_be(b : FixedArray[Byte], off : Int, v : UInt) -> Unit {
  b.unsafe_set(off, (v >> 24).to_byte())
  b.unsafe_set(off + 1, (v >> 16).to_byte())
  b.unsafe_set(off + 2, (v >> 8).to_byte())
  b.unsafe_set(off + 3, v.to_byte())
}

///|
pub fn write_uint32_le(b : FixedArray[Byte], off : Int, v : UInt) -> Unit {
  b.unsafe_set(off, v.to_byte())
  b.unsafe_set(off + 1, (v >> 8).to_byte())
  b.unsafe_set(off + 2, (v >> 16).to_byte())
  b.unsafe_set(off + 3, (v >> 24).to_byte())
}

///|
pub fn read_uint16_be_bytes(b : Bytes, off : Int) -> UInt {
  (b.unsafe_get(off).to_uint() << 8) | b.unsafe_get(off + 1).to_uint()
}

///|
pub fn read_uint32_be_bytes(b : Bytes, off : Int) -> UInt {
  (b.unsafe_get(off).to_uint() << 24) |
  (b.unsafe_get(off + 1).to_uint() << 16) |
  (b.unsafe_get(off + 2).to_uint() << 8) |
  b.unsafe_get(off + 3).to_uint()
}

///|
pub fn read_uint16_le_bytes(b : Bytes, off : Int) -> UInt {
  b.unsafe_get(off).to_uint() | (b.unsafe_get(off + 1).to_uint() << 8)
}

///|
pub fn read_uint32_le_bytes(b : Bytes, off : Int) -> UInt {
  b.unsafe_get(off).to_uint() |
  (b.unsafe_get(off + 1).to_uint() << 8) |
  (b.unsafe_get(off + 2).to_uint() << 16) |
  (b.unsafe_get(off + 3).to_uint() << 24)
}
