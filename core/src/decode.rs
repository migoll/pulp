use std::io::Cursor;

use ::image::ImageReader;

use crate::image::Image;

/// Decode an encoded image (JPEG, PNG, WebP, TIFF, GIF, BMP) into RGBA8.
///
/// HEIC and AVIF are intentionally not handled here — the macOS shell decodes
/// those through ImageIO and hands the resulting RGBA buffer back via
/// [`crate::ffi::pulp_image_from_rgba`].
pub fn decode(data: &[u8]) -> Result<Image, DecodeError> {
    let reader = ImageReader::new(Cursor::new(data))
        .with_guessed_format()
        .map_err(|_| DecodeError::Unreadable)?;

    let dynamic = reader.decode().map_err(|_| DecodeError::Unsupported)?;
    let rgba = dynamic.into_rgba8();
    let (width, height) = rgba.dimensions();

    Ok(Image {
        pixels: rgba.into_raw(),
        width,
        height,
    })
}

#[derive(Debug)]
pub enum DecodeError {
    Unreadable,
    Unsupported,
}
