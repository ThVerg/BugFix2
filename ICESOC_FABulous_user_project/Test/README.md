# Test/ — bare-fabric simulation flow

Tests **just the eFPGA fabric**: bitstream load → fabric → external pins → testbench. No CPU. The testbench drives `OPA_I/OPB_I/RES{0,1,2}_O` directly via the fabric's external ports (mediated through the row-interleave mapping).

This is the simpler of the two simulation flows — see [../icesoc_sim/Test/](../icesoc_sim/Test/) for the SoC-level flow.

## Files

- **`Makefile`** — build + sim driver. Targets:
  - `build_test_design` — runs yosys synth → nextpnr P&R → bit_gen → makehex.py.
  - `run_simulation` — iverilog compile + vvp run.
  - `sim` / `FAB_sim` / `full_sim` / `clean` — common combinations.
- **`top_tb.v`** — testbench (~ 350 lines). Three phases:
  1. **Counter** — 100 cycles of W_IO bidirectional pads + LUT4AB DFF chain (32-bit counter), comparing fabric `I_top`/`T_top` against the gold `top dut_i` reference.
  2. **Stress patterns** — 16 hand-crafted (OPA, OPB) pairs, 5 cycles each, comparing all 6 RES outputs (W: XOR/AND/OR/rotate; E: ADD/SUB/8x8 MUL).
  3. **RegFile warmup + random stress** — walks all 32 RegFile addresses to align gold and fabric state, then runs 200 random patterns × 6 outputs.
- **`makehex.py`** — converts the binary bitstream (`top.bin`) into one-byte-per-line hex for `$readmemh` in the testbench.
- **`build_fabulous_fabric.tcl`** — TCL script to regenerate the fabric from inside FABulous's interactive shell (used by the `build_demo_fabric` Makefile target).

## How to run

```bash
source ~/oss-cad-suite/environment             # if not already in your shell
cd ICESOC_FABulous_user_project/Test
make build_test_design
make run_simulation VVP_ARGS="+bitstream_hex=build/top.hex"
```

The `VVP_ARGS` override skips the FST waveform dump (much faster — ~5s wall time vs ~30s with FST). To get a waveform for GTKWave, use `make sim` (default Makefile config emits FST).

## What it verifies

After bitstream load:
1. The fabric's W and E sides compute the user_design's combinational logic correctly.
2. Sequential logic (the 32-bit counter in the LUT4AB DFFs) increments per clock.
3. The bidirectional W_IO pads correctly drive `io_in` / `io_out` / `io_oeb`.
4. The RegFile_32x4 BEL stores and reads back data driven by the testbench's regfile-warmup phase.
5. Across 216 input patterns (16 hand + 200 random), all 6 RES outputs (W_RES0/1/2 + E_RES0/1/2) match the gold reference exactly — 0 mismatches.

## What this does NOT cover

- **No CPU.** All operands come from the testbench. The CPU integration is verified by the SoC test in [`../icesoc_sim/Test/`](../icesoc_sim/Test/).
- **No DSP MULADD.** The 8×8 multiply on `E_RES2` is LUT-based (the synth/sim signature mismatch on MULADD blocks direct instantiation).
- **No BRAM access.** The RAM_IO tile's BELs exist on the fabric but aren't routed to user_design ports.

## Bitstream byte layout

The makehex output zero-pads to `MAX_BITBYTES = 20000` bytes. The actual bitstream is ~18024 bytes for the current `top.v`. The testbench's `bitstream_bytes` counter scans backward from the end to find the last non-zero byte and bounds the SelfWrite loop accordingly — without that, strobing trailing zero words can roll the Config FSM and corrupt earlier-loaded frames.
