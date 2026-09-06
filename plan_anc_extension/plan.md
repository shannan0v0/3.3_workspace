# ANC Window Extension Plan

需求：在不接入硬件的前提下扩展 ANC Window 工程，并在 Vivado 可用时完成可验证的工程化检查。
约束：保留已完成的 `plan_anc_window/plan.md`；不虚构板卡、codec、引脚或声学结果；每一步均需实际命令和证据。

## 计划
1. [✓ 2026-09-05：在`E:\vivado.vitis\Vivado\2025.2.1\Vivado\bin\vivado.bat`实测Vivado v2025.2.1；器件查询列出XC7Z020变体，随后以显式`xc7z020clg400-1`创建工程。] 定位 Vivado、确认版本和可用 FPGA part。
2. [✓ 2026-09-05：`scripts/run_rtl_python_regression.py`通过py_compile；Icarus编译/运行均返回0，203个边界与确定性随机trace逐样本匹配Python模型。] 扩充边界/随机回归与 RTL/Python 一致性验证。
3. [✓ 2026-09-05：`scripts/offline_anc_analysis.py`生成12个mu扫描结果（每项4096样本），饱和边界、独立CSV schema/首中尾抽查及重复SHA-256校验通过；报告明确identity路径与非声学结论边界。] 完成离线 ANC 参数/收敛分析及报告。
4. [✓ 2026-09-05：新增AXI-Lite→local bus桥、通用I2C三字节写主机、toggle CDC事件桥及3个自检TB；`run_interface_checks.py`三项编译/运行均返回0并输出TB_AXI_PASS/TB_I2C_PASS/TB_CDC_PASS；partial WSTRB、I2C NACK/STOP、异步脉冲/复位边界通过；旧`run_local_checks.ps1`与4个Python脚本py_compile亦通过。Vivado综合证据已在步骤5独立复核，板卡/codec/声学仍未验证。] 补充 AXI-Lite/I2C/CDC 可仿真工程化准备。
5. [✓ 2026-09-05：生成`vivado/create_project.tcl`、`run_synth_reports.tcl`、`HANDOFF.md`、README及惰性`constraints/AX7020_template.xdc`；以Vivado v2025.2.1和显式`xc7z020clg400-1`实际建工程并生成综合利用率/时序/DCP。独立DCP探针RC=0（248413 cells/199 ports）；LUT为147512/53200=277.28%，资源门失败；惰性XDC导致WNS/TNS为NA。证据见`audit/step5_vivado_handoff_audit.md`与`audit/step5_vivado_synthesis_evidence.md`；实现、bitstream及硬件结果仍未验证；VERDICT: PARTIAL。] 生成 Vivado TCL/工程交接文件，并在工具可用时执行综合/报告。
6. [✓ 2026-09-05：顺序重跑本地回归、AXI/I2C/CDC接口仿真、RTL/Python 203样本回归、4096样本×12参数分析及4脚本py_compile均通过；空PATH缺依赖探针按预期fail-closed；独立产物审计49/49通过；另完成Vivado综合/DCP证据复核，证据见`anc_window_project/audit/step6_final_review.md`和`audit/step5_vivado_synthesis_evidence.md`，执行日志已追加。总体仍为PARTIAL，因资源超限、约束不完整及实现/板卡/codec/声学边界未验证。] 汇总证据、更新日志并完成独立复核。

## 完成门
- [✓ 2026-09-05：已重读本计划全文；步骤1–6均有实际证据与结果。Vivado综合/DCP已验证，但资源超限、惰性XDC时序、实现/bitstream、准确板卡引脚、codec及声学边界已明确。] 终止检查：重读本计划全文，确认每项有结果且明确未验证边界。
