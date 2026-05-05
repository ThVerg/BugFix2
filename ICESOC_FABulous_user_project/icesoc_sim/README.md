# icesoc_sim/ — full SoC simulation

Tests the **whole SoC**: bitstream load → CPU runs from SRAM → CPU drives the eFPGA via the FlexBex custom instruction → result returns to a register and is stored to memory. Verifies the entire chain end-to-end.

Compared to [../Test/](../Test/) (which is bare-fabric), this directory wraps the eFPGA in:

- Two RISC-V CPU cores (FlexBex/Ibex)
- A Wishbone slave interface
- Logic Analyzer probes
- 38 GPIO pads (Caravel-standard)
- An axi_uart + uart_to_mem for loading instructions into SRAM
- Two 1KB Sky130 SRAM macros (instruction + data, dual-ported)

## Layout

```
icesoc_sim/
├── rtl_icesoc_with_cores/             ← FlexBex + Ibex + UART + RAM RTL
│   ├── eFPGA_CPU_top.v                    ← TOP: connects CPU↔fabric (the integration glue)
│   ├── ibex_core/                         ← FlexBex (Ibex variant) RTL
│   │   ├── flexbex_ibex_core.v               ← top of FlexBex
│   │   ├── flexbex_ibex_decoder.v            ← decodes RISC-V + custom eFPGA opcode 0x0B
│   │   ├── flexbex_ibex_eFPGA.v              ← the eFPGA accelerator FSM (en/operator/delay → endresult)
│   │   ├── flexbex_ibex_id_stage.v           ← instruction decode stage with eFPGA hooks
│   │   ├── flexbex_ibex_ex_block.v           ← execute block (alu, eFPGA result mux → regfile)
│   │   └── ibex_*.v                          ← regular Ibex modules (alu, regfile, lsu, etc.)
│   ├── icesoc/                            ← SoC infrastructure (UART, RAM, interconnect)
│   │   ├── icesoc_top.v                       ← icesoc wrapper (instantiates 2x cores + RAM + peripherals)
│   │   ├── inter.v, inter_read.v              ← data + instruction-fetch interconnects
│   │   ├── sky130_sram_1kbyte_*.v             ← 1KB SRAM model (dual-port)
│   │   ├── axi_uart.v, uart*.v                ← UART for loading SRAM contents
│   │   ├── peripheral.v
│   │   └── icesoc_netlists.vh
│   ├── original_fabric_files/             ← stale snapshot, EXCLUDED by Makefile
│   ├── defines.v
│   └── icesoc_with_cores.v
│
├── user_design_icesoc/                ← SoC user_design (no IO counter, just W/E ALU)
│   ├── top.v                              ← W/E XOR/AND/OR + ADD/SUB + DEADBEEF
│   └── top_wrapper.v                      ← BEL-placement shim
│
├── Test/                              ← SoC simulation flow (build + sim Makefile + testbench)
│   ├── Makefile, top_tb.v
│   ├── mem.hex                            ← legacy CPU program (testbench bypasses; forces SRAM directly)
│   ├── icesoc_waveforms.gtkw              ← GTKWave save file
│   └── README.md
└── README.md                          ← (this file)
```

## How CPU↔fabric is wired

`eFPGA_CPU_top.v` is the integration TOP. Critical wiring (see comments in the file for the row-interleave generate loop):

- ibex_top (core 1) drives `eFPGA_operand_a_1_o[31:0]` → `W_OPA[34:3]` (W column, X=3).
- flexbex_ibex_core (core 2) drives `eFPGA_operand_a_2_o[31:0]` → `E_OPA[34:3]` (E column, X=11).
- Same for operand_b → W_OPB / E_OPB[31:0].
- `W_OPA[35]` = eFPGA_en, `W_OPA[2:0]` = irq_id/irq_ack (from core), etc.
- A `generate` loop rebuilds `OPA_I[71:0]` (and OPB_I, RES{0,1,2}_O) by **interleaving W and E bits per fabric row Y** with a per-4-bit-slot bit-reverse — this matches the fabric's actual port layout.

Result busses flow back: fabric `RES0_O[71:0]` → de-interleave → `W_RES0[35:0]` and `E_RES0[35:0]` → low 32 bits → `eFPGA_result_a_{1,2}_i` → CPU.

## SoC-only fixes (vs upstream)

- **Wired `eFPGA_top.resetn`** (was unconnected) — single-line fix that blocked all bitstream loading.
- **Fixed `OPA_I/OPB_I/RES*_O` mapping** — was naive `{W_OPA, E_OPA}` concat, now correct row-interleave.
- **Tied off `irq_ack_1_o` / `irq_id_1_o`** in icesoc_top.v — ibex_top doesn't drive these, only flexbex does.
- **Reordered wire decls** in icesoc_top.v above first use (iverilog declaration-before-use).
- **Added testbench overrides** in eFPGA_CPU_top.v (`tb_sw_force` for fast bitstream load, `tb_drive_ops` for deterministic operand drives).

## See also

- [Test/README.md](Test/README.md) — how to run the SoC sim, what each test phase verifies
- [user_design_icesoc/README.md](user_design_icesoc/README.md) — the user logic
- [rtl_icesoc_with_cores/README.md](rtl_icesoc_with_cores/README.md) — RTL deep dive
- [../README.md](../README.md) — top-level project overview
