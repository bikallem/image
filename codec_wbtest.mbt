///|
test "root_decode_builtin_codecs" {
  let png_data = @fs.read_file_to_bytes("testdata/video-001.png")
  let jpeg_data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif")

  let (png_img, png_name) = decode(png_data)
  let (jpeg_img, jpeg_name) = decode(jpeg_data)
  let (gif_img, gif_name) = decode(gif_data)

  assert_eq(png_name, "png")
  assert_eq(jpeg_name, "jpeg")
  assert_eq(gif_name, "gif")
  assert_true(png_img.bounds().dx() > 0)
  assert_true(jpeg_img.bounds().dx() > 0)
  assert_true(gif_img.bounds().dx() > 0)
}

///|
test "root_decode_config_builtin_codecs" {
  let png_data = @fs.read_file_to_bytes("testdata/video-001.png")
  let jpeg_data = @fs.read_file_to_bytes("testdata/video-001.jpeg")
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif")

  let (png_cfg, png_name) = decode_config(png_data)
  let (jpeg_cfg, jpeg_name) = decode_config(jpeg_data)
  let (gif_cfg, gif_name) = decode_config(gif_data)

  assert_eq(png_name, "png")
  assert_eq(jpeg_name, "jpeg")
  assert_eq(gif_name, "gif")
  assert_true(png_cfg.width > 0)
  assert_true(jpeg_cfg.width > 0)
  assert_true(gif_cfg.width > 0)
}

///|
fn decode_fake_image(_data : Bytes) -> AnyImage {
  @coreimage.AnyImage::Gray(
    @coreimage.new_image_gray(@coreimage.rect(0, 0, 1, 1)),
  )
}

///|
fn decode_fake_config(_data : Bytes) -> Config {
  { color_model: @color.AnyModel::GrayModel, width: 1, height: 1 }
}

///|
fn decode_fake_image_registered(data : Bytes) -> AnyImage raise Error {
  if data.length() < 0 {
    raise @coreimage.ImageError::FormatError("unreachable")
  }
  decode_fake_image(data)
}

///|
fn decode_fake_config_registered(data : Bytes) -> Config raise Error {
  if data.length() < 0 {
    raise @coreimage.ImageError::FormatError("unreachable")
  }
  decode_fake_config(data)
}

///|
test "root_decode_falls_back_to_explicit_registry" {
  register_format(
    "fake", "FAKE", decode_fake_image_registered, decode_fake_config_registered,
  )
  let data = b"FAKE payload"
  let (img, name) = decode(data)
  let (cfg, cfg_name) = decode_config(data)
  assert_eq(name, "fake")
  assert_eq(cfg_name, "fake")
  assert_eq(img.bounds().dx(), 1)
  assert_eq(cfg.width, 1)
}
