///|
/// Config holds an image's color model and dimensions.
pub(all) struct Config {
  color_model : @color.AnyModel
  width : Int
  height : Int
} derive(Show)

///|
pub(open) trait Image {
  color_model(Self) -> @color.AnyModel
  bounds(Self) -> Rectangle
  at(Self, Int, Int) -> @color.AnyColor
}

///|
pub(all) enum AnyImage {
  RGBA(ImageRGBA)
  RGBA64(ImageRGBA64)
  NRGBA(ImageNRGBA)
  NRGBA64(ImageNRGBA64)
  Alpha(ImageAlpha)
  Alpha16(ImageAlpha16)
  Gray(ImageGray)
  Gray16(ImageGray16)
  Paletted(ImagePaletted)
  YCbCr(ImageYCbCr)
  NYCbCrA(ImageNYCbCrA)
  Uniform(ImageUniform)
}

///|
pub impl Image for AnyImage with color_model(self) -> @color.AnyModel {
  match self {
    RGBA(_) => @color.AnyModel::RGBAModel
    RGBA64(_) => @color.AnyModel::RGBA64Model
    NRGBA(_) => @color.AnyModel::NRGBAModel
    NRGBA64(_) => @color.AnyModel::NRGBA64Model
    Alpha(_) => @color.AnyModel::AlphaModel
    Alpha16(_) => @color.AnyModel::Alpha16Model
    Gray(_) => @color.AnyModel::GrayModel
    Gray16(_) => @color.AnyModel::Gray16Model
    Paletted(p) => @color.AnyModel::PaletteModel(p.palette)
    YCbCr(_) => @color.AnyModel::YCbCrModel
    NYCbCrA(_) => @color.AnyModel::NYCbCrAModel
    Uniform(u) => u.color_model()
  }
}

///|
pub impl Image for AnyImage with bounds(self) -> Rectangle {
  match self {
    RGBA(img) => img.rect
    RGBA64(img) => img.rect
    NRGBA(img) => img.rect
    NRGBA64(img) => img.rect
    Alpha(img) => img.rect
    Alpha16(img) => img.rect
    Gray(img) => img.rect
    Gray16(img) => img.rect
    Paletted(img) => img.rect
    YCbCr(img) => img.rect
    NYCbCrA(img) => img.ycbcr.rect
    Uniform(u) => u.bounds()
  }
}

///|
pub impl Image for AnyImage with at(self, x, y) -> @color.AnyColor {
  match self {
    RGBA(img) => @color.AnyColor::RGBA(img.rgba_at(x, y))
    RGBA64(img) => @color.AnyColor::RGBA64(img.rgba64_at(x, y))
    NRGBA(img) => @color.AnyColor::NRGBA(img.nrgba_at(x, y))
    NRGBA64(img) => @color.AnyColor::NRGBA64(img.nrgba64_at(x, y))
    Alpha(img) => @color.AnyColor::Alpha(img.alpha_at(x, y))
    Alpha16(img) => @color.AnyColor::Alpha16(img.alpha16_at(x, y))
    Gray(img) => @color.AnyColor::Gray(img.gray_at(x, y))
    Gray16(img) => @color.AnyColor::Gray16(img.gray16_at(x, y))
    Paletted(img) => img.at(x, y)
    YCbCr(img) => @color.AnyColor::YCbCr(img.ycbcr_at(x, y))
    NYCbCrA(img) => @color.AnyColor::NYCbCrA(img.nycbcra_at(x, y))
    Uniform(u) => u.c
  }
}

///|
pub(all) suberror ImageError {
  FormatError(String)
} derive(Show)
