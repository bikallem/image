///|
fn abs_diff64(a : Int64, b : Int64) -> Int64 {
  if a > b { a - b } else { b - a }
}

///|
fn abs_diff(a : UInt, b : UInt) -> UInt {
  if a > b { a - b } else { b - a }
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
  let re = @png.encode(png_img)
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
  if jdiff > 2241929L {
    println("FAIL JPEG checksum diff=\{jdiff} (>0.1%)")
    failures += 1
  }
  let (jr, jg, jbv, _) = jpeg_img.at(0, 0).rgba()
  let jpd = abs_diff(jr, 32178U).reinterpret_as_int() +
    abs_diff(jg, 4043U).reinterpret_as_int() +
    abs_diff(jbv, 738U).reinterpret_as_int()
  if jpd > 1536 {
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
  println("")
  if failures == 0 {
    println("PASS: all parity checks passed")
  } else {
    println("FAIL: \{failures} parity checks failed")
  }
}
