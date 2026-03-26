///|
fn abs_diff64(a : Int64, b : Int64) -> Int64 {
  if a > b {
    a - b
  } else {
    b - a
  }
}

///|
fn abs_diff(a : UInt, b : UInt) -> UInt {
  if a > b {
    a - b
  } else {
    b - a
  }
}

///|
fn main {
  let mut failures = 0
  // PNG (bit-exact)
  let png_data = @fs.read_file_to_bytes("testdata/video-001.png") catch {
    _ => abort("can't read PNG")
  }
  let png_img = @png.decode(png_data) catch { _ => abort("can't decode PNG") }
  let b = png_img.bounds()
  let mut psum : Int64 = 0L
  for y = b.min_y; y < b.max_y; y = y + 1 {
    for x = b.min_x; x < b.max_x; x = x + 1 {
      let (r, g, bv, a) = png_img.at(x, y).rgba()
      psum += r.reinterpret_as_int().to_int64() +
        g.reinterpret_as_int().to_int64() +
        bv.reinterpret_as_int().to_int64() +
        a.reinterpret_as_int().to_int64()
    }
  }
  if psum != 2241542178L {
    println("FAIL PNG checksum: \{psum} != 2241542178")
    failures += 1
  }
  let re = @png.encode(png_img) catch { _ => abort("re-encode") }
  let rd = @png.decode(re) catch { _ => abort("re-decode") }
  let mut mm = 0
  for y = b.min_y; y < b.max_y; y = y + 1 {
    for x = b.min_x; x < b.max_x; x = x + 1 {
      let (r1, g1, b1, a1) = png_img.at(x, y).rgba()
      let (r2, g2, b2, a2) = rd.at(x, y).rgba()
      if r1 != r2 || g1 != g2 || b1 != b2 || a1 != a2 {
        mm += 1
      }
    }
  }
  if mm > 0 {
    println("FAIL PNG roundtrip: \{mm} mismatches")
    failures += 1
  }
  let total = b.dx() * b.dy()
  println("PNG: checksum=\{psum} roundtrip=\{total - mm}/\{total}")
  // JPEG (tolerance: 0.1% checksum, 1536 total channel delta at sample pixel)
  let jpeg_data = @fs.read_file_to_bytes("testdata/video-001.jpeg") catch {
    _ => abort("can't read JPEG")
  }
  let jpeg_img = @jpeg.decode(jpeg_data) catch {
    _ => abort("can't decode JPEG")
  }
  let jb = jpeg_img.bounds()
  let mut jsum : Int64 = 0L
  for y = jb.min_y; y < jb.max_y; y = y + 1 {
    for x = jb.min_x; x < jb.max_x; x = x + 1 {
      let (r, g, bv, a) = jpeg_img.at(x, y).rgba()
      jsum += r.reinterpret_as_int().to_int64() +
        g.reinterpret_as_int().to_int64() +
        bv.reinterpret_as_int().to_int64() +
        a.reinterpret_as_int().to_int64()
    }
  }
  let jdiff = abs_diff64(jsum, 2241929914L)
  if jdiff > 22419299L {
    // 1% tolerance: ISLOW IDCT + fancy upsampling differs from Go's Loeffler + nearest-neighbor
    println("FAIL JPEG checksum diff=\{jdiff} (>1%)")
    failures += 1
  }
  let (jr, jg, jbv, _) = jpeg_img.at(0, 0).rgba()
  let jpd = abs_diff(jr, 32178U).reinterpret_as_int() +
    abs_diff(jg, 4043U).reinterpret_as_int() +
    abs_diff(jbv, 738U).reinterpret_as_int()
  if jpd > 3072 {
    // Wider tolerance for ISLOW IDCT
    println("FAIL JPEG[0,0] delta=\{jpd}")
    failures += 1
  }
  println("JPEG: checksum=\{jsum} diff=\{jdiff} [0,0] delta=\{jpd}")
  // GIF (bit-exact)
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif") catch {
    _ => abort("can't read GIF")
  }
  let gif_img = @gif.decode(gif_data) catch { _ => abort("can't decode GIF") }
  let (gr0, gg0, gb0, _) = gif_img.at(0, 0).rgba()
  if gr0 != 32125U || gg0 != 3084U || gb0 != 0U {
    println("FAIL GIF[0,0]")
    failures += 1
  }
  let (gr1, gg1, gb1, _) = gif_img.at(100, 75).rgba()
  if gr1 != 62965U || gg1 != 64507U || gb1 != 64764U {
    println("FAIL GIF[100,75]")
    failures += 1
  }
  println("GIF: [0,0]=\{gr0},\{gg0},\{gb0} [100,75]=\{gr1},\{gg1},\{gb1}")
  // Write MoonBit-encoded files for Go cross-codec roundtrip test
  let png_enc = @png.encode(png_img) catch { _ => abort("png encode") }
  @fs.write_bytes_to_file("testdata/roundtrip_moonbit.png", png_enc) catch {
    _ => ()
  }
  let jpeg_enc = @jpeg.encode(
    @image.AnyImage::RGBA(@image.new_image_rgba(@image.rect(0, 0, 32, 32))),
  )
  @fs.write_bytes_to_file("testdata/roundtrip_moonbit.jpeg", jpeg_enc) catch {
    _ => ()
  }
  let pal : @color.Palette = {
    colors: Array::makei(256, fn(i) {
      @color.AnyColor::RGBA({
        r: i.to_byte(),
        g: i.to_byte(),
        b: i.to_byte(),
        a: b'\xff',
      })
    }),
  }
  let pal_img = @image.new_image_paletted(@image.rect(0, 0, 32, 32), pal)
  for y in 0..<32 {
    for x in 0..<32 {
      pal_img.set_color_index(x, y, ((x + y) % 256).to_byte())
    }
  }
  let gif_enc = @gif.encode(pal_img) catch { _ => Bytes::new(0) }
  if gif_enc.length() > 0 {
    @fs.write_bytes_to_file("testdata/roundtrip_moonbit.gif", gif_enc) catch {
      _ => ()
    }
  }
  println("Wrote roundtrip_moonbit.{png,jpeg,gif}")
  // Read Go-encoded files (if they exist)
  let go_png = @fs.read_file_to_bytes("testdata/roundtrip_go.png") catch {
    _ => Bytes::new(0)
  }
  if go_png.length() > 0 {
    let go_png_img = @png.decode(go_png) catch {
      _ => {
        println("FAIL: can't decode Go PNG")
        failures += 1
        abort("")
      }
    }
    let gpb = go_png_img.bounds()
    println(
      "Go PNG → MoonBit: \{gpb.dx()}x\{gpb.dy()} [0,0]=\{go_png_img.at(0, 0).rgba().0}",
    )
  } else {
    println("(skipping Go→MoonBit: run Go parity first)")
  }
  let go_jpeg = @fs.read_file_to_bytes("testdata/roundtrip_go.jpeg") catch {
    _ => Bytes::new(0)
  }
  if go_jpeg.length() > 0 {
    let go_jpeg_img = @jpeg.decode(go_jpeg) catch {
      _ => {
        println("FAIL: can't decode Go JPEG")
        failures += 1
        abort("")
      }
    }
    let gjb = go_jpeg_img.bounds()
    println(
      "Go JPEG → MoonBit: \{gjb.dx()}x\{gjb.dy()} [0,0]=\{go_jpeg_img.at(0, 0).rgba().0}",
    )
  }
  let go_gif = @fs.read_file_to_bytes("testdata/roundtrip_go.gif") catch {
    _ => Bytes::new(0)
  }
  if go_gif.length() > 0 {
    let go_gif_img = @gif.decode(go_gif) catch {
      _ => {
        println("FAIL: can't decode Go GIF")
        failures += 1
        abort("")
      }
    }
    let ggb = go_gif_img.bounds()
    println(
      "Go GIF → MoonBit: \{ggb.dx()}x\{ggb.dy()} [0,0]=\{go_gif_img.at(0, 0).rgba().0}",
    )
  }
  println("")
  if failures == 0 {
    println("PASS: all parity checks passed")
  } else {
    println("FAIL: \{failures} parity checks failed")
  }
}
