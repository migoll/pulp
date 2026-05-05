use fast_image_resize::{images::Image as FirImage, PixelType, ResizeOptions, Resizer};

use crate::image::Image;

/// Resize the image so it fits within `max_w × max_h`, preserving aspect ratio.
///
/// Returns `None` when no resize is needed: when both bounds are zero, or when
/// the source already fits. A zero on a single axis means "no limit on that
/// axis."
pub fn resize_to_fit(src: &Image, max_w: u32, max_h: u32) -> Option<Image> {
    let (target_w, target_h) = fit_dimensions(src.width, src.height, max_w, max_h)?;

    let source = FirImage::from_vec_u8(src.width, src.height, src.pixels.clone(), PixelType::U8x4)
        .ok()?;
    let mut destination = FirImage::new(target_w, target_h, PixelType::U8x4);

    Resizer::new()
        .resize(&source, &mut destination, &ResizeOptions::new())
        .ok()?;

    Some(Image {
        pixels: destination.into_vec(),
        width: target_w,
        height: target_h,
    })
}

fn fit_dimensions(src_w: u32, src_h: u32, max_w: u32, max_h: u32) -> Option<(u32, u32)> {
    if max_w == 0 && max_h == 0 {
        return None;
    }
    let bound_w = if max_w == 0 { u32::MAX } else { max_w };
    let bound_h = if max_h == 0 { u32::MAX } else { max_h };
    if src_w <= bound_w && src_h <= bound_h {
        return None;
    }

    let scale = f64::min(bound_w as f64 / src_w as f64, bound_h as f64 / src_h as f64);
    let target_w = ((src_w as f64) * scale).round().max(1.0) as u32;
    let target_h = ((src_h as f64) * scale).round().max(1.0) as u32;
    Some((target_w, target_h))
}
