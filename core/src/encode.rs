use ::image::{codecs, ExtendedColorType, ImageEncoder};

use crate::image::Image;
use crate::resize::resize_to_fit;

#[derive(Clone, Copy)]
pub enum Format {
    Jpeg,
    Png,
    WebP,
    Avif,
}

pub struct EncodeOptions {
    pub format: Format,
    /// 1–100. Ignored for PNG (always lossless).
    pub quality: u8,
    /// 0 means no constraint on this axis.
    pub max_width: u32,
    pub max_height: u32,
}

pub fn encode(image: &Image, opts: &EncodeOptions) -> Result<Vec<u8>, EncodeError> {
    let resized = resize_to_fit(image, opts.max_width, opts.max_height);
    let view = resized.as_ref().unwrap_or(image);

    match opts.format {
        Format::Jpeg => encode_jpeg(view, opts.quality),
        Format::Png => encode_png(view),
        Format::WebP => encode_webp(view, opts.quality),
        Format::Avif => encode_avif(view, opts.quality),
    }
}

fn encode_jpeg(image: &Image, quality: u8) -> Result<Vec<u8>, EncodeError> {
    // JPEG has no alpha channel; flatten transparent pixels onto white so they
    // don't end up rendered as black.
    let rgb = flatten_alpha_to_white(&image.pixels);
    let mut out = Vec::with_capacity(image.pixels.len() / 4);
    codecs::jpeg::JpegEncoder::new_with_quality(&mut out, quality)
        .write_image(&rgb, image.width, image.height, ExtendedColorType::Rgb8)
        .map_err(|_| EncodeError::Failed)?;
    Ok(out)
}

fn encode_png(image: &Image) -> Result<Vec<u8>, EncodeError> {
    let mut out = Vec::new();
    codecs::png::PngEncoder::new_with_quality(
        &mut out,
        codecs::png::CompressionType::Best,
        codecs::png::FilterType::Adaptive,
    )
    .write_image(
        &image.pixels,
        image.width,
        image.height,
        ExtendedColorType::Rgba8,
    )
    .map_err(|_| EncodeError::Failed)?;
    Ok(out)
}

fn encode_webp(image: &Image, quality: u8) -> Result<Vec<u8>, EncodeError> {
    let encoder = webp::Encoder::from_rgba(&image.pixels, image.width, image.height);
    Ok(encoder.encode(quality as f32).to_vec())
}

fn encode_avif(image: &Image, quality: u8) -> Result<Vec<u8>, EncodeError> {
    let pixels: Vec<rgb::RGBA8> = image
        .pixels
        .chunks_exact(4)
        .map(|c| rgb::RGBA8::new(c[0], c[1], c[2], c[3]))
        .collect();

    let view = ravif::Img::new(pixels.as_slice(), image.width as usize, image.height as usize);

    let result = ravif::Encoder::new()
        .with_quality(quality as f32)
        .with_speed(6)
        .encode_rgba(view)
        .map_err(|_| EncodeError::Failed)?;

    Ok(result.avif_file)
}

fn flatten_alpha_to_white(rgba: &[u8]) -> Vec<u8> {
    let mut rgb = Vec::with_capacity(rgba.len() / 4 * 3);
    for px in rgba.chunks_exact(4) {
        let a = px[3] as u32;
        let inv = 255 - a;
        rgb.push(((px[0] as u32 * a + 255 * inv) / 255) as u8);
        rgb.push(((px[1] as u32 * a + 255 * inv) / 255) as u8);
        rgb.push(((px[2] as u32 * a + 255 * inv) / 255) as u8);
    }
    rgb
}

#[derive(Debug)]
pub enum EncodeError {
    Failed,
}
