// Pulp core C ABI. Hand-written to stay in lockstep with src/ffi.rs — keep
// the two in sync when changing either. Memory rules are documented there.

#ifndef PULP_CORE_H
#define PULP_CORE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PulpImageHandle PulpImageHandle;

typedef struct PulpBuffer {
    uint8_t *data;
    size_t   len;
    size_t   _capacity;
} PulpBuffer;

typedef struct PulpEncodeOptions {
    uint8_t  format;      // 0=JPEG, 1=PNG, 2=WebP, 3=AVIF
    uint8_t  quality;     // 1-100; ignored for PNG
    uint32_t max_width;   // 0 = no limit
    uint32_t max_height;  // 0 = no limit
} PulpEncodeOptions;

PulpImageHandle *pulp_decode(const uint8_t *data, size_t len);
PulpImageHandle *pulp_image_from_rgba(const uint8_t *pixels, size_t len,
                                      uint32_t width, uint32_t height);
uint32_t         pulp_image_width(const PulpImageHandle *image);
uint32_t         pulp_image_height(const PulpImageHandle *image);
void             pulp_image_free(PulpImageHandle *image);

PulpBuffer *pulp_encode(const PulpImageHandle *image, const PulpEncodeOptions *options);
void        pulp_buffer_free(PulpBuffer *buffer);

#ifdef __cplusplus
}
#endif

#endif // PULP_CORE_H
