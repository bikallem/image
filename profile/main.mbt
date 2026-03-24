///|
fn main {
  let mut failures = 0

  // PNG
  let png_data = @fs.read_file_to_bytes("testdata/video-001.png") catch {
    _ => { println("FAIL PNG: can't read file"); abort("") }
  }
  let png_img = @png.decode(png_data) catch {
    _ => { println("FAIL PNG: can't decode"); abort("") }
  }
  let b = png_img.bounds()
  let mut sum : Int64 = 0L
  for y = b.min_y; y < b.max_y; y = y + 1 {
    for x = b.min_x; x < b.max_x; x = x + 1 {
      let (r, g, bv, a) = png_img.at(x, y).rgba()
      sum += r.reinterpret_as_int().to_int64()
      sum += g.reinterpret_as_int().to_int64()
      sum += bv.reinterpret_as_int().to_int64()
      sum += a.reinterpret_as_int().to_int64()
    }
  }
  let (r0, g0, b0, a0) = png_img.at(0, 0).rgba()
  let (r1, g1, b1, a1) = png_img.at(100, 75).rgba()
  println(
    "PNG \{b.dx()}x\{b.dy()} checksum=\{sum} [0,0]=\{r0},\{g0},\{b0},\{a0} [100,75]=\{r1},\{g1},\{b1},\{a1}",
  )
  // Go values: PNG 150x103 checksum=2241542178 [0,0]=32125,3598,514,65535 [100,75]=62194,64764,63736,65535
  if sum != 2241542178L {
    println("FAIL PNG: checksum \{sum} != 2241542178")
    failures += 1
  }
  if r0 != 32125U || g0 != 3598U || b0 != 514U || a0 != 65535U {
    println("FAIL PNG[0,0]: got \{r0},\{g0},\{b0},\{a0} want 32125,3598,514,65535")
    failures += 1
  }
  // PNG roundtrip
  let re_encoded = @png.encode(png_img)
  let re_decoded = @png.decode(re_encoded) catch {
    _ => { println("FAIL PNG roundtrip: re-decode failed"); abort("") }
  }
  let mut mismatch = 0
  for y = b.min_y; y < b.max_y; y = y + 1 {
    for x = b.min_x; x < b.max_x; x = x + 1 {
      let (r1, g1, b1, a1) = png_img.at(x, y).rgba()
      let (r2, g2, b2, a2) = re_decoded.at(x, y).rgba()
      if r1 != r2 || g1 != g2 || b1 != b2 || a1 != a2 {
        mismatch += 1
      }
    }
  }
  if mismatch > 0 {
    println("FAIL PNG roundtrip: \{mismatch} pixel mismatches")
    failures += 1
  } else {
    println("PNG roundtrip: \{b.dx() * b.dy()} pixels match")
  }

  // JPEG
  let jpeg_data = @fs.read_file_to_bytes("testdata/video-001.jpeg") catch {
    _ => { println("FAIL JPEG: can't read file"); abort("") }
  }
  let jpeg_img = @jpeg.decode(jpeg_data) catch {
    _ => { println("FAIL JPEG: can't decode"); abort("") }
  }
  let jb = jpeg_img.bounds()
  let mut jsum : Int64 = 0L
  for y = jb.min_y; y < jb.max_y; y = y + 1 {
    for x = jb.min_x; x < jb.max_x; x = x + 1 {
      let (r, g, bv, a) = jpeg_img.at(x, y).rgba()
      jsum += r.reinterpret_as_int().to_int64()
      jsum += g.reinterpret_as_int().to_int64()
      jsum += bv.reinterpret_as_int().to_int64()
      jsum += a.reinterpret_as_int().to_int64()
    }
  }
  let (jr0, jg0, jb0, ja0) = jpeg_img.at(0, 0).rgba()
  let (jr1, jg1, jb1, ja1) = jpeg_img.at(100, 75).rgba()
  println(
    "JPEG \{jb.dx()}x\{jb.dy()} checksum=\{jsum} [0,0]=\{jr0},\{jg0},\{jb0},\{ja0} [100,75]=\{jr1},\{jg1},\{jb1},\{ja1}",
  )
  // Go values: JPEG 150x103 checksum=2241929914 [0,0]=32178,4043,738,65535 [100,75]=62199,64908,63993,65535
  if jsum != 2241929914L {
    println("FAIL JPEG: checksum \{jsum} != 2241929914")
    failures += 1
  }
  if jr0 != 32178U || jg0 != 4043U || jb0 != 738U || ja0 != 65535U {
    println(
      "FAIL JPEG[0,0]: got \{jr0},\{jg0},\{jb0},\{ja0} want 32178,4043,738,65535",
    )
    failures += 1
  }

  // GIF
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif") catch {
    _ => { println("FAIL GIF: can't read file"); abort("") }
  }
  let gif_img = @gif.decode(gif_data) catch {
    _ => { println("FAIL GIF: can't decode"); abort("") }
  }
  let gb = gif_img.bounds()
  let (gr0, gg0, gb0, ga0) = gif_img.at(0, 0).rgba()
  let (gr1, gg1, gb1, ga1) = gif_img.at(100, 75).rgba()
  println(
    "GIF \{gb.dx()}x\{gb.dy()} [0,0]=\{gr0},\{gg0},\{gb0},\{ga0} [100,75]=\{gr1},\{gg1},\{gb1},\{ga1}",
  )
  // Go values: GIF 150x103 [0,0]=32125,3084,0,65535 [100,75]=62965,64507,64764,65535
  if gr0 != 32125U || gg0 != 3084U || gb0 != 0U || ga0 != 65535U {
    println(
      "FAIL GIF[0,0]: got \{gr0},\{gg0},\{gb0},\{ga0} want 32125,3084,0,65535",
    )
    failures += 1
  }
  if gr1 != 62965U || gg1 != 64507U || gb1 != 64764U || ga1 != 65535U {
    println(
      "FAIL GIF[100,75]: got \{gr1},\{gg1},\{gb1},\{ga1} want 62965,64507,64764,65535",
    )
    failures += 1
  }

  // Summary
  println("")
  if failures == 0 {
    println("PASS: all parity checks passed")
  } else {
    println("FAIL: \{failures} parity checks failed")
  }
}
