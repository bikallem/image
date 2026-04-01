///|
pub(all) struct ImageUniform {
  c : &@color.Color
  model : &@color.Model
}

///|
pub impl Image for ImageUniform with color_model(self) -> &@color.Model {
  self.model
}

///|
pub impl Image for ImageUniform with bounds(_self) -> Rectangle {
  {
    min_x: -1000000000,
    min_y: -1000000000,
    max_x: 1000000000,
    max_y: 1000000000,
  }
}

///|
pub impl Image for ImageUniform with at(self, _x, _y) -> &@color.Color {
  self.c
}

///|
pub impl Image for ImageUniform with set(self, _x, _y, _c) -> Unit {
  ignore(self)
}

///|
pub fn ImageUniform::is_opaque(self : ImageUniform) -> Bool {
  let (_, _, _, a) = self.c.rgba()
  a == 0xffffU
}

///|
pub fn ImageUniform::black() -> ImageUniform {
  { c: @color.Gray16::{ y: 0U }, model: @color.Gray16Model::{  } }
}

///|
pub fn ImageUniform::white() -> ImageUniform {
  { c: @color.Gray16::{ y: 0xffffU }, model: @color.Gray16Model::{  } }
}

///|
pub fn ImageUniform::transparent() -> ImageUniform {
  { c: @color.Alpha16::{ a: 0U }, model: @color.Alpha16Model::{  } }
}

///|
pub fn ImageUniform::fully_opaque() -> ImageUniform {
  { c: @color.Alpha16::{ a: 0xffffU }, model: @color.Alpha16Model::{  } }
}
