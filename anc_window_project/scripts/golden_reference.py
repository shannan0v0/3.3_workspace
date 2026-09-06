"""Independent integer reference for the bounded Q15 ANC core."""

Q15 = 15
MIN24, MAX24 = -(1 << 23), (1 << 23) - 1
MIN16, MAX16 = -(1 << 15), (1 << 15) - 1


def sat(value, lo, hi):
    return max(lo, min(hi, value))


class CoreModel:
    def __init__(self, taps=128):
        self.coeff = [0] * taps
        self.delay = [0] * taps
        self.samples = 0
        self.clips = 0

    def write_coeff(self, index, value):
        self.coeff[index] = sat(value, MIN16, MAX16)

    def sample(self, reference, error, enable, bypass, mu):
        acc = sum((reference if i == 0 else self.delay[i - 1]) * self.coeff[i]
                  for i in range(len(self.coeff)))
        wide = acc >> Q15
        output = reference if (bypass or not enable) else sat(wide, MIN24, MAX24)
        self.samples += 1
        if wide < MIN24 or wide > MAX24:
            self.clips += 1
        if enable and not bypass:
            for i in range(len(self.coeff)):
                tap = reference if i == 0 else self.delay[i - 1]
                delta = (mu * error * tap) >> 30
                self.coeff[i] = sat(self.coeff[i] + delta, MIN16, MAX16)
        self.delay[1:] = self.delay[:-1]
        self.delay[0] = reference
        return output, error


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    m = CoreModel()
    check(m.sample(12345, 0, False, True, 64)[0] == 12345, "disabled bypass")
    check(m.sample(-3210, 0, True, True, 64)[0] == -3210, "explicit bypass")

    check(m.sample(111, 0, True, False, 64)[0] == 0, "zero FIR")
    m.write_coeff(0, 16384)
    check(m.sample(1000, 0, True, False, 64)[0] == 500, "half gain FIR")

    m = CoreModel()
    check(m.sample(32768, 32768, True, False, 16384)[0] == 0, "LMS first output")
    check(m.coeff[0] == 16384, "LMS coefficient update")
    check(m.sample(32768, 0, True, False, 16384)[0] == 16384, "LMS updated output")

    m = CoreModel()
    m.write_coeff(0, 32767)
    m.write_coeff(1, 32767)
    check(m.sample(MAX24, 0, True, False, 0)[0] == 8388351, "near-limit FIR")
    check(m.sample(MAX24, 0, True, False, 0)[0] == MAX24, "24-bit saturation")
    check(m.clips == 1 and m.samples == 2, "counter behavior")
    print("PY_GOLDEN_PASS")


if __name__ == "__main__":
    main()
