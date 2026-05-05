# icesoc_sim/Test/ — SoC simulation flow

The end-to-end test for the ICESOC SoC: bitstream load + CPU instruction fetch + custom-instruction decode + eFPGA accelerator + result writeback + memory store. Verifies the full chain.

## Files

- **`Makefile`** — build + sim driver. Same flow as bare-fabric Test/ but pulls in the SoC RTL (`rtl_icesoc_with_cores/*.v`) on top of `Tile/` and `Fabric/`.
- **`top_tb.v`** — testbench (~620 lines). Five phases:
  1. **Bitstream load (fast)** — uses `tb_sw_force` override to drive `SelfWriteData/Strobe` directly into the eFPGA Config FSM, ~250us instead of UART's ~20s.
  2. **SoC stress (16 hand patterns)** — `tb_drive_ops` overrides drive operand busses; verifies SoC interconnect (interleave + bit-reverse) over hand-crafted patterns.
  3. **SoC random stress (200 patterns)** — same as above but with `$random` fills.
  4. **CPU firmware Phase A** — forces a 9-instruction RISC-V program into SRAM and lets the CPU run it. Three back-to-back `efpga op=2` instructions (capture `result_c` = constant `0xDEADBEEF`) into x5/x6/x7, then `sw` each register to `SRAM[0x100/0x104/0x108]`.
  5. **CPU firmware Phase B** — two `efpga op=0` instructions (capture `result_a` = `E_OPA + E_OPB`):
     - First with `rs1=0, rs2=0` → expected ~0
     - Second with `rs1=0x10000000, rs2=0x555` → expected `0x80000555` (bit-level prediction: `(rs1[28:0] << 3) + rs2`).
- **`mem.hex`** — legacy 6-instruction CPU program (UART-to-mem encoded). The testbench's Phase 4/5 forces SRAM directly, bypassing this.
- **`icesoc_waveforms.gtkw`** — GTKWave save file (signal selection / timestamps for debugging).
- **`build_fabulous_fabric.tcl`** — TCL helper (currently unused).
- **`makehex.py`** — bitstream binary → hex converter.

## How to run

```bash
source ~/oss-cad-suite/environment             # if not already in your shell
cd ICESOC_FABulous_user_project/icesoc_sim/Test
make build_test_design                         # synth + PnR + bit_gen
make run_icesoc_simulation \
    VVP_ARGS="+bitstream_hex=build_icesoc/top.hex +mem_hex=mem.hex"   # ~5s, no FST
```

Default Makefile uses FST. **Don't run with FST unless you're prepared to wait hours** — UART simulation + waveform writes is the slow combination.

## What it verifies

| Phase | What's exercised |
|---|---|
| 1 | Config FSM accepts SelfWrite frames; bitstream lands correctly in fabric latches. |
| 2-3 | SoC interconnect: CPU operand busses → row-interleave + bit-reverse → fabric input pads → fabric computation → fabric output pads → de-interleave → CPU result busses. 216 patterns × 6 outputs. |
| 4 | CPU instruction fetch from SRAM; FlexBex custom-instruction decode (opcode 0x0B); eFPGA accelerator FSM dispatch; register writeback to multiple rd values (x5, x6, x7); CPU `sw` data writes through inter → SRAM Port 0. |
| 5 | Operand-dependent fabric computation: rs1/rs2 register values flow to fabric → ADD computed → result returns to register → store. Verifies operands actually drive the fabric (not stuck constants). |

## FlexBex eFPGA opcode encoding (0x0B)

| Bits | Field |
|---|---|
| `[6:0]` | opcode = `0x0B` |
| `[11:7]` | rd (destination register) |
| `[13:12]` | operator: 00=result_a (W:XOR/E:ADD), 01=result_b (W:AND/E:SUB), 10=result_c (W:OR/E:DEADBEEF), 11=write_strobe (config write) |
| `[14]` | unused |
| `[19:15]` | rs1 → eFPGA_operand_a |
| `[24:20]` | rs2 → eFPGA_operand_b |
| `[28:25]` | delay (cycles to wait before result capture; 15 = wait for `eFPGA_fpga_done`) |
| `[31:29]` | unused |

Example `efpga x5, x1, x2, op=2, delay=2`:
- `rd=5 (00101)`, `rs1=1 (00001)`, `rs2=2 (00010)`, `op=10`, `delay=0010`
- Encoding = `delay<<25 | rs2<<20 | rs1<<15 | op<<12 | rd<<7 | 0x0B` = `0x0420A28B`

## Bit-level operand mapping (FlexBex / E side)

When the CPU executes `efpga` with rs1, rs2:

```
E_OPA[35]    = eFPGA_en (1 during op)
E_OPA[34:3]  = rs1[31:0]                 (CPU operand_a)
E_OPA[2:0]   = {irq_id_2_o[1:0], irq_ack_2_o}  (typically 0)

E_OPB[31:0]  = rs2[31:0]                 (CPU operand_b)
E_OPB[33:32] = eFPGA_delay[1:0]          (lower 2 bits of 4-bit delay)
E_OPB[35:34] = eFPGA_operator[1:0]
```

The fabric computes `E_RES0 = E_OPA + E_OPB` (etc.) on the full 36 bits, and the CPU sees `[31:0]` of that. So:

```
result_a[31:0] = ((rs1[28:0] << 3) | irq) + rs2[31:0]   (mod 2^32)
              ≈ (rs1[28:0] << 3) + rs2                  (assuming irq = 0)
```

That's why Phase B's `(rs1=0x10000000, rs2=0x555)` produces `0x80000555` exactly:
- `rs1[28:0] = 0x10000000`, `<< 3` = `0x80000000`
- `+ rs2 = 0x80000000 + 0x555 = 0x80000555` ✓

## Why both CPU cores run the same program

Both `ibex_top` (core 1) and `flexbex_ibex_core` (core 2) boot at PC=0x80 and execute from SRAM. Only the FlexBex decodes opcode 0x0B; ibex_top sees it as illegal and traps (wandering into garbage memory). The verification only depends on FlexBex's writes landing in SRAM — ibex's confused execution may briefly write garbage to mem[0x100] before FlexBex overwrites with `0xDEADBEEF`, which is what we observed in the trace.

If you wanted to silence ibex_top, you'd either disable it via reset or branch it to a tight loop before the eFPGA opcode (e.g., differentiate by reading `mhartid`).

## Result

Final state of the verification:
- 16/16 hand stress patterns pass
- 200/200 random stress patterns pass
- 3/3 Phase A constant-result sentinels (DEADBEEF) match
- Phase B: `mem[0x10C] = 0x00000000`, `mem[0x110] = 0x80000555` — both passing soft assertions

End-to-end CPU↔eFPGA round-trip verified.
