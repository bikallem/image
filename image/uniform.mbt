///|
pub(all) struct ImageUniform {
  c : @color.AnyColor
}

///|
pub fn ImageUniform::color_model(self : ImageUniform) -> @color.AnyModel {
  match self.c {
    @color.AnyColor::RGBA(_) => @color.AnyModel::RGBAModel
    @color.AnyColor::RGBA64(_) => @color.AnyModel::RGBA64Model
    @color.AnyColor::NRGBA(_) => @color.AnyModel::NRGBAModel
    @color.AnyColor::NRGBA64(_) => @color.AnyModel::NRGBA64Model
    @color.AnyColor::Alpha(_) => @color.AnyModel::AlphaModel
    @color.AnyColor::Alpha16(_) => @color.AnyModel::Alpha16Model
    @color.AnyColor::Gray(_) => @color.AnyModel::GrayModel
    @color.AnyColor::Gray16(_) => @color.AnyModel::Gray16Model
    @color.AnyColor::YCbCr(_) => @color.AnyModel::YCbCrModel
    @color.AnyColor::NYCbCrA(_) => @color.AnyModel::NYCbCrAModel
    @color.AnyColor::CMYK(_) => @color.AnyModel::CMYKModel
  }
}

///|
pub fn ImageUniform::bounds(_self : ImageUniform) -> Rectangle {
  { min_x: -1000000000, min_y: -1000000000, max_x: 1000000000, max_y: 1000000000 }
}

///|
pub fn ImageUniform::is_opaque(self : ImageUniform) -> Bool {
  let (_, _, _, a) = self.c.rgba()
  a == 0xffffU
}

///|
pub let black : ImageUniform = { c: @color.AnyColor::Gray16({ y: 0U }) }

///|
pub let white : ImageUniform = { c: @color.AnyColor::Gray16({ y: 0xffffU }) }

///|
pub let transparent : ImageUniform = { c: @color.AnyColor::Alpha16({ a: 0U }) }

///|
pub let fully_opaque : ImageUniform = {
  c: @color.AnyColor::Alpha16({ a: 0xffffU }),
}
