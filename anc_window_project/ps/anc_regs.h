#ifndef ANC_REGS_H
#define ANC_REGS_H

#include <stdint.h>
#include <stddef.h>

/*
 * The AXI/PS physical base address is intentionally not guessed here.
 * Define ANC_MMIO_BASE in the board-specific application after the Vivado
 * address map is assigned and reviewed.
 */
#define ANC_CONTROL       0x000u
#define ANC_MU_Q15        0x004u
#define ANC_STATUS        0x008u
#define ANC_SAMPLE_COUNT  0x00Cu
#define ANC_CLIP_COUNT    0x010u
#define ANC_ANTI_NOISE    0x014u
#define ANC_RESIDUAL      0x018u
#define ANC_COEFF_BASE    0x100u
#define ANC_CONTROL_ENABLE 0x1u
#define ANC_CONTROL_BYPASS 0x2u

static inline void anc_write(volatile uint32_t *base, uint32_t offset,
                             uint32_t value) {
    base[offset >> 2] = value;
}

static inline uint32_t anc_read(volatile uint32_t *base, uint32_t offset) {
    return base[offset >> 2];
}

static inline void anc_write_coefficients(volatile uint32_t *base,
                                           const int16_t *coefficients,
                                           size_t count) {
    size_t i;
    if (count > 128u) count = 128u;
    for (i = 0; i < count; ++i)
        anc_write(base, ANC_COEFF_BASE + (uint32_t)(4u * i),
                  (uint32_t)(uint16_t)coefficients[i]);
}

/* Safe software sequence: bypass first, then enable after coefficients/MU. */
static inline void anc_configure(volatile uint32_t *base,
                                 const int16_t *coefficients, size_t count,
                                 uint16_t mu_q15) {
    anc_write(base, ANC_CONTROL, ANC_CONTROL_BYPASS);
    anc_write_coefficients(base, coefficients, count);
    anc_write(base, ANC_MU_Q15, (uint32_t)mu_q15);
    anc_write(base, ANC_CONTROL, ANC_CONTROL_ENABLE | ANC_CONTROL_BYPASS);
}

static inline void anc_enable(volatile uint32_t *base) {
    anc_write(base, ANC_CONTROL, ANC_CONTROL_ENABLE);
}

static inline void anc_disable(volatile uint32_t *base) {
    anc_write(base, ANC_CONTROL, ANC_CONTROL_BYPASS);
}

#endif
