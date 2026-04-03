///|
let max_color : UInt = 0xffffU

///|
/// Fast division by 65535: exact for all uint32 inputs in [0, 65535*65535].
fn div65535(x : UInt) -> UInt {
  (x + (x >> 16) + 1U) >> 16
}

///|
/// Op is a Porter-Duff compositing operator.
pub(all) enum Op {
  Over
  Src
} derive(Eq, Debug)

///|
pub fn draw(
  dst : &@image.Image,
  r : @image.Rectangle,
  src : &@image.Image,
  sp : @image.Point,
  op : Op,
) -> Unit {
  draw_mask(dst, r, src, sp, None, { x: 0, y: 0 }, op)
}

///|
fn clip(
  dst : &@image.Image,
  r : @image.Rectangle,
  src : &@image.Image,
  sp : @image.Point,
  mask : &@image.Image?,
  mp : @image.Point,
) -> (@image.Rectangle, @image.Point, @image.Point) {
  let orig = r.min()
  let mut r2 = r.intersect(dst.bounds())
  r2 = r2.intersect(src.bounds().add(orig.sub(sp)))
  match mask {
    Some(mask_img) => r2 = r2.intersect(mask_img.bounds().add(orig.sub(mp)))
    None => ()
  }
  let dx = r2.min_x - orig.x
  let dy = r2.min_y - orig.y
  let sp2 : @image.Point = { x: sp.x + dx, y: sp.y + dy }
  let mp2 : @image.Point = { x: mp.x + dx, y: mp.y + dy }
  (r2, sp2, mp2)
}

///|
pub fn draw_mask(
  dst : &@image.Image,
  r : @image.Rectangle,
  src : &@image.Image,
  sp : @image.Point,
  mask : &@image.Image?,
  mp : @image.Point,
  op : Op,
) -> Unit {
  let (r, sp, mp) = clip(dst, r, src, sp, mask, mp)
  if r.empty() {
    return
  }
  draw_generic(dst, r, src, sp, mask, mp, op)
}

///|
fn draw_generic(
  dst : &@image.Image,
  r : @image.Rectangle,
  src : &@image.Image,
  sp : @image.Point,
  mask : &@image.Image?,
  mp : @image.Point,
  op : Op,
) -> Unit {
  for y = r.min_y; y < r.max_y; y = y + 1 {
    let sy = sp.y + y - r.min_y
    let my = mp.y + y - r.min_y
    for x = r.min_x; x < r.max_x; x = x + 1 {
      let sx = sp.x + x - r.min_x
      let mx = mp.x + x - r.min_x
      let (sr0, sg0, sb0, sa0) = src.at(sx, sy).rgba()
      let (sr1, sg1, sb1, sa1) = match mask {
        Some(mask_img) => {
          let (_, _, _, ma) = mask_img.at(mx, my).rgba()
          (
            div65535(sr0 * ma),
            div65535(sg0 * ma),
            div65535(sb0 * ma),
            div65535(sa0 * ma),
          )
        }
        None => (sr0, sg0, sb0, sa0)
      }
      let (sr, sg, sb, sa) = if op == Over {
        let (dr, dg, db, da) = dst.at(x, y).rgba()
        let a = max_color - sa1
        (
          div65535(dr * a) + sr1,
          div65535(dg * a) + sg1,
          div65535(db * a) + sb1,
          div65535(da * a) + sa1,
        )
      } else {
        (sr1, sg1, sb1, sa1)
      }
      dst.set(x, y, @color.RGBA64::{ r: sr, g: sg, b: sb, a: sa })
    }
  }
}
