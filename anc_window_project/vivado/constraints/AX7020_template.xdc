# Intentionally inert XDC template. Replace placeholders only after reviewing
# the exact board revision schematic, package pins, IO voltage, and clocks.
# No board pin or clock period is asserted by this file.
# Example syntax (keep commented until verified):
# set_property PACKAGE_PIN <verified_pin> [get_ports sys_clk]
# set_property IOSTANDARD <verified_io_standard> [get_ports sys_clk]
# create_clock -period <verified_period_ns> [get_ports sys_clk]
# set_property PACKAGE_PIN <verified_pin> [get_ports i2s_bclk]
# set_property PACKAGE_PIN <verified_pin> [get_ports i2s_lrclk]
# set_property PACKAGE_PIN <verified_pin> [get_ports i2s_sdin]
# set_property PACKAGE_PIN <verified_pin> [get_ports i2s_sdout]
