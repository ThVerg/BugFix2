# user_design/ — bare-fabric user design

The Verilog the user wants to map onto the eFPGA. Used by the bare-fabric simulation flow ([../Test/](../Test/)). For the SoC version (slimmer, no IO counter), see [../icesoc_sim/user_design_icesoc/](../icesoc_sim/user_design_icesoc/).

## Files

- **`top.v`** — the user logic module. Inputs: `clk`, 36-bit `W_OPA/W_OPB/E_OPA/E_OPB`, 10-bit `io_in`. Outputs: 36-bit `W_RES0/1/2/E_RES0/1/2`, 10-bit `io_out/io_oeb`. Computes:
  - **W side** (LUT-only): `W_RES0 = W_OPA ^ W_OPB`, `W_RES1 = W_OPA & W_OPB`, `W_RES2[31:0] = (W_OPA[31:0] | W_OPB[31:0]) ^ rotate_left_1(W_OPA)`, `W_RES2[35:32] = regfile_a XOR regfile_b` — the regfile read drives the high nibble.
  - **E side**: `E_RES0 = E_OPA + E_OPB`, `E_RES1 = E_OPA - E_OPB`, `E_RES2 = 32'h0_DEADBEEF` (zero-extended) for the high 4 bits, plus 8x8 LUT multiplier on the low 16 bits.
  - **RegFile**: 32-entry × 4-bit array, written each cycle on `W_OPA[3:0]` at addr `W_OPB[12:8]`. Inferred by yosys as `RegFile_32x4` BEL (placed on the RegFile tile).
  - **Counter**: 32-bit counter incremented when `io_in[1]` (en) is high, reset by `io_in[0]`. Drives `io_out[9:2] = counter[7:0]`.

- **`top_wrapper.v`** — the BEL-placement shim. Has `(* keep, BEL="X3Y9.OPA" *)` etc. attributes that pin specific I/O BELs to specific (X,Y) coordinates on the fabric. Yosys + nextpnr-fabulous use these `(* keep, BEL=... *)` attributes during placement. Without the wrapper, nextpnr would pick BELs freely and the testbench's bit mapping would not match.

## How `top` and `top_wrapper` interact

- Yosys synthesizes `top_wrapper` (top-level for synth) which instantiates `top user_design_i (...)`.
- `top_wrapper` has many `(* keep, BEL=... *)` lines forcing specific BEL placements for the I/O pads (10× IO_1_bidirectional pads, 9 rows × 5 BELs/row of CPU_IO InPass4/OutPass4, the BRAM I/O pads, etc.).
- `top.v`'s logic gets placed wherever nextpnr decides (mostly LUT4AB tiles), with the placed BELs driving/sinking the pads in `top_wrapper`.

## RegFile inference — why no `initial` block

The behavioral `reg [3:0] regfile [0:31]` array gets inferred to a `RegFile_32x4` BEL. Earlier we tried initializing with `initial for (...) regfile[i] = 0;` — but that **prevented yosys from inferring the RegFile** (it's a known issue: an initial block on a memory-pattern array makes yosys treat it as logic, not memory). Instead, the testbench warmup phase walks all 32 addresses with random data so the inferred BEL and the gold sim model start in the same state.

## Sentinel: where the regfile is observable

The regfile output is mixed into `W_RES2[35:32]` so the testbench can compare it against gold. Without this, yosys would optimize the regfile away as dead logic.

## See also

- [top.v](top.v) — the actual user logic
- [top_wrapper.v](top_wrapper.v) — BEL-pinning shim
- [../Test/README.md](../Test/README.md) — how the testbench drives this design
- [../icesoc_sim/user_design_icesoc/README.md](../icesoc_sim/user_design_icesoc/README.md) — slimmer SoC variant
