"""Independent cycle/reference model for anc_fx_lms_tm_core.

The model deliberately uses Python integers and explicit signed saturation rather
than importing RTL or a simulator.  Its externally visible tick semantics match
posedge sampling: inputs are applied before tick(), and returned outputs are the
values after that edge.
"""

from dataclasses import dataclass, field
from typing import Dict, List

TAPS = 128
LAST_TAP = TAPS - 1
U32_MAX = (1 << 32) - 1
S16_MIN, S16_MAX = -(1 << 15), (1 << 15) - 1
S24_MIN, S24_MAX = -(1 << 23), (1 << 23) - 1


def sat16(value: int) -> int:
    return max(S16_MIN, min(S16_MAX, int(value)))


def sat24(value: int) -> int:
    return max(S24_MIN, min(S24_MAX, int(value)))


def inc_sat32(value: int) -> int:
    return U32_MAX if int(value) >= U32_MAX else int(value) + 1


def arshift(value: int, amount: int = 15) -> int:
    """Arithmetic right shift; Python's signed shift has the RTL behavior."""
    return int(value) >> amount


@dataclass
class TmFxLmsCycleModel:
    coeff: List[int] = field(default_factory=lambda: [0] * TAPS)
    x_hist: List[int] = field(default_factory=lambda: [0] * TAPS)
    state: str = "IDLE"
    tap_index: int = 0
    write_ptr: int = 0
    sample_ptr: int = 0
    ref_reg: int = 0
    error_reg: int = 0
    mu_reg: int = 0
    gradient_q15: int = 0
    fir_acc: int = 0
    sample_out_valid: int = 0
    anti_noise_sample: int = 0
    residual_sample: int = 0
    sample_count: int = 0
    clip_count: int = 0
    overrun: int = 0
    overrun_count: int = 0

    def outputs(self, rst: int = 0) -> Dict[str, int]:
        rst = int(bool(rst))
        idle = self.state == "IDLE"
        return {
            "sample_ready": int(idle and not rst),
            "coeff_wr_ready": int(idle and not rst),
            "busy": int((not idle) and not rst),
            "overrun": self.overrun,
            "overrun_count": self.overrun_count,
            "sample_out_valid": self.sample_out_valid,
            "anti_noise_sample": self.anti_noise_sample,
            "residual_sample": self.residual_sample,
            "sample_count": self.sample_count,
            "clip_count": self.clip_count,
        }

    def _tap_value(self) -> int:
        if self.tap_index == 0:
            return self.ref_reg
        return self.x_hist[(self.sample_ptr - self.tap_index) & LAST_TAP]

    def _reset(self) -> None:
        self.coeff = [0] * TAPS
        self.x_hist = [0] * TAPS
        self.state = "IDLE"
        self.tap_index = 0
        self.write_ptr = 0
        self.sample_ptr = 0
        self.ref_reg = 0
        self.error_reg = 0
        self.mu_reg = 0
        self.gradient_q15 = 0
        self.fir_acc = 0
        self.sample_out_valid = 0
        self.anti_noise_sample = 0
        self.residual_sample = 0
        self.sample_count = 0
        self.clip_count = 0
        self.overrun = 0
        self.overrun_count = 0

    def tick(self, *, rst: int = 0, sample_valid: int = 0,
             enable: int = 0, bypass: int = 0, ref_sample: int = 0,
             error_sample: int = 0, mu_q15: int = 0, coeff_wr_en: int = 0,
             coeff_wr_addr: int = 0, coeff_wr_data: int = 0) -> Dict[str, int]:
        """Advance one rising edge and return post-edge visible outputs."""
        if rst:
            self._reset()
            return self.outputs(rst=1)

        # The RTL clears this pulse every non-reset edge.
        self.sample_out_valid = 0
        idle = self.state == "IDLE"
        if (not idle) and sample_valid:
            self.overrun = 1
            self.overrun_count = inc_sat32(self.overrun_count)

        if coeff_wr_en and idle:
            self.coeff[int(coeff_wr_addr) & 0x7f] = sat16(coeff_wr_data)

        if self.state == "IDLE":
            if sample_valid:
                self.ref_reg = int(ref_sample)
                self.error_reg = int(error_sample)
                self.mu_reg = int(mu_q15)
                self.sample_ptr = self.write_ptr
                self.x_hist[self.write_ptr] = int(ref_sample)
                self.write_ptr = (self.write_ptr + 1) & LAST_TAP
                self.sample_count = inc_sat32(self.sample_count)
                if bypass:
                    self.anti_noise_sample = sat24(ref_sample)
                    self.residual_sample = sat24(error_sample)
                    self.sample_out_valid = 1
                elif not enable:
                    self.anti_noise_sample = 0
                    self.residual_sample = sat24(error_sample)
                    self.sample_out_valid = 1
                else:
                    self.fir_acc = 0
                    self.tap_index = 0
                    self.state = "FIR"

        elif self.state == "FIR":
            product = int(self.coeff[self.tap_index]) * self._tap_value()
            fir_acc_next = self.fir_acc + product
            fir_output_wide = arshift(fir_acc_next)
            if self.tap_index == LAST_TAP:
                self.anti_noise_sample = sat24(fir_output_wide)
                self.residual_sample = sat24(self.error_reg)
                self.sample_out_valid = 1
                if fir_output_wide > S24_MAX or fir_output_wide < S24_MIN:
                    self.clip_count = inc_sat32(self.clip_count)
                self.tap_index = 0
                self.state = "GRAD"
            else:
                self.fir_acc = fir_acc_next
                self.tap_index += 1

        elif self.state == "GRAD":
            self.gradient_q15 = arshift(int(self.mu_reg) * int(self.error_reg))
            self.tap_index = 0
            self.state = "DELTA"

        elif self.state == "DELTA":
            delta = arshift(int(self.gradient_q15) * self._tap_value())
            if enable and not bypass:
                self.coeff[self.tap_index] = sat16(self.coeff[self.tap_index] + delta)
            if self.tap_index == LAST_TAP:
                self.state = "IDLE"
            else:
                self.tap_index += 1

        else:
            self.state = "IDLE"

        return self.outputs(rst=0)


def enabled_latency() -> int:
    """Number of clocks from acceptance edge E0 until ready is restored."""
    return 128 + 1 + 128


if __name__ == "__main__":
    model = TmFxLmsCycleModel()
    assert model.tick(rst=1)["sample_ready"] == 0
    assert model.tick()["sample_ready"] == 1
    model.coeff[0] = 16384
    out = model.tick(sample_valid=1, enable=1, ref_sample=1000,
                     error_sample=0, mu_q15=0)
    assert out["busy"] == 1
    for _ in range(128):
        out = model.tick()
    assert out["sample_out_valid"] == 1
    assert out["anti_noise_sample"] == 500
    for _ in range(129):
        out = model.tick()
    assert out["sample_ready"] == 1
    assert enabled_latency() == 257
    print("TM_MODEL_SELFTEST_PASS")
