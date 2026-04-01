///|
/// Config holds an image's color model and dimensions.
pub(all) struct Config {
  color_model : &@color.Model
  width : Int
  height : Int
}

///|
pub impl Show for Config with output(self, logger) {
  logger
  ..write_string("Config { width: ")
  ..write_string(self.width.to_string())
  ..write_string(", height: ")
  ..write_string(self.height.to_string())
  .write_string(" }")
}

///|
pub(open) trait Image {
  color_model(Self) -> &@color.Model
  bounds(Self) -> Rectangle
  at(Self, Int, Int) -> &@color.Color
  set(Self, Int, Int, &@color.Color) -> Unit
}

///|
pub(all) suberror ImageError {
  FormatError(String)
} derive(Show)
