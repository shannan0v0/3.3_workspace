/* PS-side usage example; the physical base comes from the reviewed AXI map. */
#include "anc_regs.h"

/* Replace this function's base argument with the mapped AXI-Lite PL window. */
int anc_start_example(volatile uint32_t *anc_base) {
    static const int16_t initial_coefficients[128] = { 0 };
    anc_configure(anc_base, initial_coefficients, 128u, 64u);
    return (anc_read(anc_base, ANC_STATUS) == 0u) ? 0 : 1;
}

void anc_stop_example(volatile uint32_t *anc_base) {
    anc_disable(anc_base);
}

uint32_t anc_clip_count_example(volatile uint32_t *anc_base) {
    return anc_read(anc_base, ANC_CLIP_COUNT);
}

/*
 * Integration checklist:
 * 1. Add the AXI-Lite adapter and assign its physical base in Vivado.
 * 2. Map the window uncached or use the platform's MMIO accessors.
 * 3. Confirm reset polarity and write/read ordering on the target PS.
 * 4. Run bypass A/B before enabling cancellation.
 */
