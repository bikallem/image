///|
fn main {
  // PNG parity
  let png_data = @fs.read_file_to_bytes("testdata/video-001.png") catch {
    _ => { println("ERROR: can't read PNG"); return }
  }
  let png_img = @png.decode(png_data) catch {
    _ => { println("ERROR: can't decode PNG"); return }
  }
  let b = png_img.bounds()
  println("PNG: \{b.dx()}x\{b.dy()}")
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
  println("PNG pixel checksum: \{sum}")
  let (r, g, bv, a) = png_img.at(0, 0).rgba()
  println("PNG[0,0]: \{r} \{g} \{bv} \{a}")
  let (r, g, bv, a) = png_img.at(100, 75).rgba()
  println("PNG[100,75]: \{r} \{g} \{bv} \{a}")
  // PNG roundtrip
  let re_encoded = @png.encode(png_img)
  let re_decoded = @png.decode(re_encoded) catch {
    _ => { println("ERROR: re-decode failed"); return }
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
  println("PNG roundtrip: \{b.dx() * b.dy() - mismatch} match, \{mismatch} mismatch")
  // JPEG parity
  let jpeg_data = @fs.read_file_to_bytes("testdata/video-001.jpeg") catch {
    _ => { println("ERROR: can't read JPEG"); return }
  }
  let jpeg_img = @jpeg.decode(jpeg_data) catch {
    _ => { println("ERROR: can't decode JPEG"); return }
  }
  let jb = jpeg_img.bounds()
  println("JPEG: \{jb.dx()}x\{jb.dy()}")
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
  println("JPEG pixel checksum: \{jsum}")
  let (r, g, bv, a) = jpeg_img.at(0, 0).rgba()
  println("JPEG[0,0]: \{r} \{g} \{bv} \{a}")
  let (r, g, bv, a) = jpeg_img.at(100, 75).rgba()
  println("JPEG[100,75]: \{r} \{g} \{bv} \{a}")
  // GIF parity
  let gif_data = @fs.read_file_to_bytes("testdata/video-001.gif") catch {
    _ => { println("ERROR: can't read GIF"); return }
  }
  let gif_img = @gif.decode(gif_data) catch {
    _ => { println("ERROR: can't decode GIF"); return }
  }
  let gb = gif_img.bounds()
  println("GIF: \{gb.dx()}x\{gb.dy()}")
  let (r, g, bv, a) = gif_img.at(0, 0).rgba()
  println("GIF[0,0]: \{r} \{g} \{bv} \{a}")
  let (r, g, bv, a) = gif_img.at(100, 75).rgba()
  println("GIF[100,75]: \{r} \{g} \{bv} \{a}")
}
