# icesoc/ — SoC infrastructure RTL

The CPU-agnostic SoC pieces: interconnect, RAM macros, UART, peripheral.

## Files

| File | Role |
|---|---|
| **`icesoc_top.v`** | The icesoc wrapper. Instantiates 2× CPU cores, the data + instruction-fetch interconnects, both 1KB SRAMs, and the UART/peripheral. |
| **`inter.v`** | Data RW interconnect (4 masters × 3 slaves). Address-decodes byte addresses to slaves. |
| **`inter_read.v`** | Read-only instruction-fetch interconnect (2 masters × 2 slaves). Routes per address bit 10. |
| **`peripheral.v`** | Generic peripheral logic. |
| **`sky130_sram_1kbyte_1rw1r_32x256_8.v`** | The Sky130 1KB SRAM model. Dual-port: Port 0 RW, Port 1 R-only. 32-bit × 256 entries (the `addr0` input is byte-stride-indexed). |
| **`axi_uart.v`** | UART with Wishbone interface. |
| **`uart.v`, `uart_rx.v`, `uart_tx.v`** | UART pieces. |
| **`uart_to_mem.v`** | Decodes incoming UART bytes into SRAM writes (the path `mem.hex` uses to load the CPU's program). |

## icesoc_top.v fixes in this snapshot

- **Wire declaration ordering** — moved `master_data_*_to_inter_ro` (and the matching slave_data_*) wire decls **above** the ibex_core_1 instantiation. iverilog's strict declaration-before-use mode rejected elaboration; the SystemVerilog standard allows late declaration but iverilog doesn't.
- **Tied off floating outputs** — `assign irq_ack_1_o = 1'b0; assign irq_id_1_o = 5'b0;` at the bottom (just before `endmodule`). ibex_top's port list doesn't include `irq_ack_o`/`irq_id_o` (those are flexbex-only), so the icesoc_top output ports were floating Z, contaminating W_OPA[2:0] in eFPGA_CPU_top.v. The `_2_o` versions ARE driven by flexbex internally; do NOT add tie-offs for those (would create multi-driver conflicts).

## Memory map (data interconnect)

`inter.v` parameters: `MASTER_ADDR_MATCH = {12'h800, 12'h400, 12'h0}`, `MASTER_ADDR_MASK = {12'hC00, 12'hC00, 12'hC00}`. So:

- `(addr & 0xC00) == 0x000` → slave 0 (sram_1, Port 0 RW)
- `(addr & 0xC00) == 0x400` → slave 1 (sram_2, Port 0 RW)
- `(addr & 0xC00) == 0x800` → slave 2 (Wishbone peripheral / wbs interface)

For instruction-fetch (`inter_read.v`):
- `addr[10] == 0` → sram_1 Port 1 (R)
- `addr[10] == 1` → sram_2 Port 1 (R)

A 32-bit instruction at byte address X is read as `mem[X]` (the SRAM treats `addr0`/`addr1` as a byte-stride index; the model writes 32-bit data at the indexed slot). The CPU reads/writes 32-bit words.

## See also

- [../README.md](../README.md) — RTL deep-dive
- [icesoc_top.v](icesoc_top.v) — the wrapper
- [inter.v](inter.v), [inter_read.v](inter_read.v) — interconnect logic
