///|
priv struct Format {
  name : String
  magic : String
  decode : (Bytes) -> AnyImage raise Error
  decode_config : (Bytes) -> Config raise Error
}

///|
let formats : Array[Format] = []

///|
pub fn register_format(
  name : String,
  magic : String,
  decode : (Bytes) -> AnyImage raise Error,
  decode_config : (Bytes) -> Config raise Error,
) -> Unit {
  formats.push({ name, magic, decode, decode_config })
}

///|
fn match_magic(magic : String, b : Bytes) -> Bool {
  if magic.length() > b.length() {
    return false
  }
  for i in 0..<magic.length() {
    if magic[i] != '?' && magic[i].to_int() != b[i].to_int() {
      return false
    }
  }
  true
}

///|
fn sniff(data : Bytes) -> Format? {
  for f in formats {
    if match_magic(f.magic, data) {
      return Some(f)
    }
  }
  None
}

///|
pub fn decode(data : Bytes) -> (AnyImage, String) raise Error {
  guard sniff(data) is Some(f) else {
    raise ImageError::FormatError("unknown format")
  }
  let img = (f.decode)(data)
  (img, f.name)
}

///|
pub fn decode_config(data : Bytes) -> (Config, String) raise Error {
  guard sniff(data) is Some(f) else {
    raise ImageError::FormatError("unknown format")
  }
  let cfg = (f.decode_config)(data)
  (cfg, f.name)
}
