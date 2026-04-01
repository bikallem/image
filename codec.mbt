///|
pub type Config = @coreimage.Config

///|
pub type ImageError = @coreimage.ImageError

///|
fn is_png(data : Bytes) -> Bool {
  data.length() >= 8 &&
  data.unsafe_get(0) == b'\x89' &&
  data.unsafe_get(1) == b'P' &&
  data.unsafe_get(2) == b'N' &&
  data.unsafe_get(3) == b'G' &&
  data.unsafe_get(4) == b'\r' &&
  data.unsafe_get(5) == b'\n' &&
  data.unsafe_get(6) == b'\x1a' &&
  data.unsafe_get(7) == b'\n'
}

///|
fn is_jpeg(data : Bytes) -> Bool {
  data.length() >= 2 &&
  data.unsafe_get(0) == b'\xff' &&
  data.unsafe_get(1) == b'\xd8'
}

///|
fn is_gif(data : Bytes) -> Bool {
  data.length() >= 6 &&
  data.unsafe_get(0) == b'G' &&
  data.unsafe_get(1) == b'I' &&
  data.unsafe_get(2) == b'F' &&
  data.unsafe_get(3) == b'8' &&
  (data.unsafe_get(4) == b'7' || data.unsafe_get(4) == b'9') &&
  data.unsafe_get(5) == b'a'
}

///|
/// Decodes PNG, JPEG, and GIF directly, and otherwise falls back to the
/// explicit registry in `bikallem/image/image`.
pub fn decode(data : Bytes) -> (&@coreimage.Image, String) raise {
  if is_png(data) {
    return (@png.decode(data), "png")
  }
  if is_jpeg(data) {
    return (@jpeg.decode(data), "jpeg")
  }
  if is_gif(data) {
    return (@gif.decode(data), "gif")
  }
  @coreimage.decode(data)
}

///|
/// Decodes the config for PNG, JPEG, and GIF directly, and otherwise falls back
/// to the explicit registry in `bikallem/image/image`.
pub fn decode_config(data : Bytes) -> (Config, String) raise {
  if is_png(data) {
    return (@png.decode_config(data), "png")
  }
  if is_jpeg(data) {
    return (@jpeg.decode_config(data), "jpeg")
  }
  if is_gif(data) {
    return (@gif.decode_config(data), "gif")
  }
  @coreimage.decode_config(data)
}

///|
/// Registers an additional format in the explicit core image registry.
pub fn register_format(
  name : String,
  magic : String,
  decode : (Bytes) -> &@coreimage.Image raise Error,
  decode_config : (Bytes) -> Config raise Error,
) -> Unit {
  @coreimage.register_format(name, magic, decode, decode_config)
}
