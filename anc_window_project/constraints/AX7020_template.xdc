# AX7020 / XC7Z020 constraint template.
# Pin numbers are intentionally not asserted: the board revision and WM8731
# schematic were not available in this environment. Fill these placeholders
# from the exact AX7020 schematic before enabling Vivado implementation.
#
# Example only (do not uncomment without verified pin facts):
# set_property PACKAGE_PIN <SYS_CLK_PIN> [get_ports sys_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
# create_clock -period 10.000 -name sys_clk [get_ports sys_clk]
# set_property PACKAGE_PIN <I2S_BCLK_PIN> [get_ports i2s_bclk]
# set_property PACKAGE_PIN <I2S_LRCLK_PIN> [get_ports i2s_lrclk]
# set_property PACKAGE_PIN <I2S_SDIN_PIN> [get_ports i2s_sdin]
# set_property PACKAGE_PIN <I2S_SDOUT_PIN> [get_ports i2s_sdout]
# set_property IOSTANDARD LVCMOS33 [get_ports {i2s_bclk i2s_lrclk i2s_sdin i2s_sdout}]
#
# Board action required: confirm bank voltage, oscillator frequency, codec
# wiring, reset polarity, and whether the fitted board actually has WM8731.
