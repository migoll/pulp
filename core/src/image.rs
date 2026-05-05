/// A decoded image held as a packed RGBA8 buffer in row-major order.
///
/// Held by value across the FFI boundary as an opaque `*mut Image`. Swift
/// never sees the fields directly — it owns the pointer and asks Rust for
/// dimensions or encoded bytes through the [`crate::ffi`] functions.
pub struct Image {
    pub pixels: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

impl Image {
    pub fn from_rgba(pixels: Vec<u8>, width: u32, height: u32) -> Result<Self, ImageError> {
        let expected = (width as usize)
            .checked_mul(height as usize)
            .and_then(|n| n.checked_mul(4))
            .ok_or(ImageError::DimensionsOverflow)?;
        if pixels.len() != expected {
            return Err(ImageError::PixelCountMismatch);
        }
        Ok(Self { pixels, width, height })
    }
}

#[derive(Debug)]
pub enum ImageError {
    DimensionsOverflow,
    PixelCountMismatch,
}
