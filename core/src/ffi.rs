//! C ABI exposed to Swift.
//!
//! Memory rules:
//! - Every successful `pulp_*_new` / `pulp_decode` / `pulp_encode` call returns
//!   a pointer the caller must release with the matching `pulp_*_free`.
//! - Failure is signalled by a null return; nothing needs to be freed in that
//!   case.
//! - Input byte buffers are never retained — they're copied or consumed before
//!   the function returns.

use std::slice;

use crate::decode;
use crate::encode::{self, EncodeOptions, Format};
use crate::image::Image;

/// Encoded output buffer owned by Rust. Read `data[..len]`, then call
/// [`pulp_buffer_free`].
#[repr(C)]
pub struct PulpBuffer {
    pub data: *mut u8,
    pub len: usize,
    capacity: usize,
}

/// Knobs for a single encode pass. `format` matches the order of [`Format`]:
/// 0 = JPEG, 1 = PNG, 2 = WebP, 3 = AVIF. Unknown values fall back to JPEG.
/// `max_width` / `max_height` of 0 mean "no limit on that axis."
#[repr(C)]
pub struct PulpEncodeOptions {
    pub format: u8,
    pub quality: u8,
    pub max_width: u32,
    pub max_height: u32,
}

/// Decode encoded image bytes into an opaque image handle.
///
/// # Safety
/// `data` must point to `len` readable bytes, or be null (in which case the
/// call returns null).
#[no_mangle]
pub unsafe extern "C" fn pulp_decode(data: *const u8, len: usize) -> *mut Image {
    if data.is_null() {
        return std::ptr::null_mut();
    }
    let bytes = slice::from_raw_parts(data, len);
    decode::decode(bytes)
        .map(|img| Box::into_raw(Box::new(img)))
        .unwrap_or(std::ptr::null_mut())
}

/// Wrap an externally-decoded RGBA8 buffer (e.g. from macOS ImageIO) as a
/// `PulpImage`. The buffer is copied; the caller keeps ownership of `pixels`.
///
/// # Safety
/// `pixels` must point to `len` readable bytes, or be null.
#[no_mangle]
pub unsafe extern "C" fn pulp_image_from_rgba(
    pixels: *const u8,
    len: usize,
    width: u32,
    height: u32,
) -> *mut Image {
    if pixels.is_null() {
        return std::ptr::null_mut();
    }
    let copied = slice::from_raw_parts(pixels, len).to_vec();
    Image::from_rgba(copied, width, height)
        .map(|img| Box::into_raw(Box::new(img)))
        .unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn pulp_image_width(image: *const Image) -> u32 {
    image.as_ref().map(|i| i.width).unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn pulp_image_height(image: *const Image) -> u32 {
    image.as_ref().map(|i| i.height).unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn pulp_image_free(image: *mut Image) {
    if !image.is_null() {
        drop(Box::from_raw(image));
    }
}

/// Encode an image with the given options. Returns null on failure.
///
/// # Safety
/// `image` and `options` must be valid pointers obtained from this library's
/// API, or null (in which case the call returns null).
#[no_mangle]
pub unsafe extern "C" fn pulp_encode(
    image: *const Image,
    options: *const PulpEncodeOptions,
) -> *mut PulpBuffer {
    let (Some(img), Some(raw_opts)) = (image.as_ref(), options.as_ref()) else {
        return std::ptr::null_mut();
    };

    let opts = EncodeOptions {
        format: format_from_tag(raw_opts.format),
        quality: raw_opts.quality.clamp(1, 100),
        max_width: raw_opts.max_width,
        max_height: raw_opts.max_height,
    };

    match encode::encode(img, &opts) {
        Ok(mut bytes) => {
            bytes.shrink_to_fit();
            let buffer = PulpBuffer {
                data: bytes.as_mut_ptr(),
                len: bytes.len(),
                capacity: bytes.capacity(),
            };
            std::mem::forget(bytes);
            Box::into_raw(Box::new(buffer))
        }
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn pulp_buffer_free(buffer: *mut PulpBuffer) {
    if buffer.is_null() {
        return;
    }
    let owned = Box::from_raw(buffer);
    drop(Vec::from_raw_parts(owned.data, owned.len, owned.capacity));
}

fn format_from_tag(tag: u8) -> Format {
    match tag {
        0 => Format::Jpeg,
        1 => Format::Png,
        2 => Format::WebP,
        3 => Format::Avif,
        _ => Format::Jpeg,
    }
}
