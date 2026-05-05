//! Pulp's image processing core.
//!
//! Source images are decoded once into an in-memory RGBA8 buffer ([`Image`]).
//! That buffer is then re-encoded on demand: format, quality and dimensions
//! become near-free knobs, which is what makes the UI feel live.
//!
//! The C ABI in [`ffi`] is the only stable surface and the only thing Swift
//! links against. Everything else is internal and may change.

mod decode;
mod encode;
mod ffi;
mod image;
mod resize;

pub use crate::image::Image;
pub use decode::{decode, DecodeError};
pub use encode::{encode, EncodeError, EncodeOptions, Format};
