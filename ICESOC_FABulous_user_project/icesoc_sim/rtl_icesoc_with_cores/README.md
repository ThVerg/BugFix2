# rtl_icesoc_with_cores/ — SoC RTL

The non-fabric part of the SoC: CPU cores, UART, RAM, interconnect, and the integration TOP that connects the CPUs to the eFPGA fabric.

## Layout

```
rtl_icesoc_with_cores/
├── eFPGA_CPU_top.v                ← TOP: connects CPU ↔ eFPGA fabric
├── icesoc_with_cores.v            ← (older variant, may be unused)
├── defines.v                      ← project-wide defines
├── icesoc_netlists.vh             ← netlist headers
│
├── ibex_core/                     ← FlexBex (Ibex variant) RTL
│   ├── flexbex_ibex_core.v            ← top of FlexBex (the CORE 2 variant with eFPGA hooks)
│   ├── flexbex_ibex_decoder.v         ← decodes RISC-V + custom eFPGA opcode 0x0B
│   ├── flexbex_ibex_eFPGA.v           ← the eFPGA accelerator FSM (en/operator/delay → endresult)
│   ├── flexbex_ibex_id_stage.v        ← decode stage with eFPGA hooks (operand_a/b → regfile reads)
│   ├── flexbex_ibex_ex_block.v        ← execute block (eFPGA result mux → regfile writeback)
│   ├── flexbex_ibex_alu.v             ← ALU
│   ├── flexbex_ibex_compressed_decoder.v
│   ├── flexbex_ibex_controller.v
│   ├── flexbex_ibex_cs_registers.v
│   ├── flexbex_ibex_fetch_fifo.v
│   ├── flexbex_ibex_if_stage.v
│   ├── flexbex_ibex_int_controller.v
│   ├── flexbex_ibex_load_store_unit.v
│   ├── flexbex_ibex_multdiv_fast.v
│   ├── flexbex_ibex_prefetch_buffer.v
│   ├── flexbex_ibex_register_file.v
│   ├── flexbex_prim_clock_gating.v
│   └── ibex_*.v                       ← regular Ibex modules used by ibex_top (CORE 1)
│
├── icesoc/                        ← SoC infrastructure
│   ├── icesoc_top.v                   ← icesoc wrapper (instantiates 2× cores + RAM + peripherals)
│   ├── inter.v                        ← data interconnect (RW)
│   ├── inter_read.v                   ← instruction-fetch interconnect (read-only)
│   ├── peripheral.v                   ← misc peripheral logic
│   ├── sky130_sram_1kbyte_1rw1r_32x256_8.v   ← 1KB dual-port SRAM (×2 instantiated)
│   ├── axi_uart.v                     ← UART (Wishbone-attached)
│   ├── uart.v, uart_rx.v, uart_tx.v   ← UART pieces
│   └── uart_to_mem.v                  ← UART decoder that writes incoming bytes to SRAM
│
└── original_fabric_files/         ← stale snapshot of the old fabric (EXCLUDED by Test/Makefile)
```

## Two CPU cores

- **Core 1 (ibex_top)** — vanilla Ibex with eFPGA hooks. Wired so its `eFPGA_operand_a_1_o` drives W_OPA[34:3] and reads W_RES0/1/2 as `eFPGA_result_a/b/c_1_i`.
- **Core 2 (flexbex_ibex_core)** — Ibex extended with the FlexBex custom-instruction decoder for opcode 0x0B. Its operands → E_OPA[34:3] / E_OPB[31:0]; results from E_RES0/1/2.

Both boot at PC=0 (per `boot_addr_i(32'h00000000)` in icesoc_top.v) but the actual reset vector lands them at PC=0x80 (verified via instruction-fetch trace). Both share the same SRAM and run the same program from there.

For our verification, only the FlexBex executes the eFPGA opcode — ibex_top sees it as illegal and traps.

## eFPGA_CPU_top.v — the integration glue

This is where most of the SoC fixes were applied. Key bits:

- **`SelfWriteData / SelfWriteStrobe`** — the CPU's eFPGA write_strobe drives these (continuous assigns from `eFPGA_operand_a_1_o` / `eFPGA_write_strobe_1_o`). They feed the fabric's Config FSM.
- **Testbench overrides (`tb_sw_*` and `tb_drive_ops/*`)** — let the testbench bypass the CPU for fast bitstream load and deterministic stress patterns. Default off; harmless in synthesis.
- **`eFPGA_top.resetn` connection** — wired to `~wb_rst_i`. Was unconnected in the original RTL (`// this does not exist in the original rtl`) which blocked all bitstream loading.
- **OPA_I / OPB_I / RES{0,1,2}_O mapping** — generate-loop that interleaves W/E bits per fabric row Y, with bit-reverse inside each 4-bit BEL slot. Replaces the original naive `{W_OPA, E_OPA}` concat which was structurally wrong.

## icesoc_top.v — interconnect + CPU instantiations

Houses the two cores plus all interconnect and SRAMs. Fixes applied:

- **Wire decl ordering** for `master_data_*_to_inter_ro` — moved up before first use to satisfy iverilog's strict mode.
- **Tied off `irq_ack_1_o` / `irq_id_1_o`** — ibex_top doesn't expose those outputs (only flexbex does); they were floating Z and contaminating W_OPA.

## Memory map

The data interconnect (`inter.v`) routes byte addresses:
- `0x000-0x3FF` → sram_1 RW (Port 0) — instruction + data RAM for both cores
- `0x400-0x7FF` → sram_2 RW (Port 0)
- `0x800-0xBFF` → Wishbone slave (peripherals)

Instruction-fetch interconnect (`inter_read.v`) routes:
- bits[10] = 0 → sram_1 R-only (Port 1)
- bits[10] = 1 → sram_2 R-only (Port 1)

Both SRAMs are dual-port: Port 0 for data RW, Port 1 for instruction fetch. Same `mem` array.

## See also

- [../README.md](../README.md) — SoC overview
- [../Test/README.md](../Test/README.md) — how this RTL is exercised by the testbench
- [eFPGA_CPU_top.v](eFPGA_CPU_top.v) — the main integration file
- [icesoc/icesoc_top.v](icesoc/icesoc_top.v) — CPU instantiations + interconnect
- [ibex_core/flexbex_ibex_eFPGA.v](ibex_core/flexbex_ibex_eFPGA.v) — the eFPGA accelerator FSM
- [ibex_core/flexbex_ibex_decoder.v](ibex_core/flexbex_ibex_decoder.v) — the opcode 0x0B decode
