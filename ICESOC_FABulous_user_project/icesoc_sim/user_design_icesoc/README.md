# user_design_icesoc/ — SoC user design

The Verilog mapped onto the eFPGA in the SoC simulation flow ([../Test/](../Test/)). Slimmer than the bare-fabric variant ([../../user_design/](../../user_design/)) — no IO counter, no RegFile usage; just the W/E ALU since the CPU drives operands directly.

## Files

- **`top.v`** — the user logic. Just W/E ALU:
  ```verilog
  W_RES0 = W_OPA ^ W_OPB;       // XOR
  W_RES1 = W_OPA & W_OPB;       // AND
  W_RES2 = W_OPA | W_OPB;       // OR
  E_RES0 = E_OPA + E_OPB;       // 36-bit ADD
  E_RES1 = E_OPA - E_OPB;       // 36-bit SUB
  E_RES2 = 32'hDEADBEEF;        // CONST (zero-extended to 36 bits)
  ```
  No clk dependency — pure combinational. The CPU's eFPGA accelerator FSM holds operands stable for the configured `delay` cycles, captures the chosen result.

- **`top_wrapper.v`** — BEL-placement shim. Same role as the bare-fabric version: pins specific I/O BELs to specific (X,Y) coordinates. The pinning differs slightly because there's no `regfile` to keep alive.

## Why is this version simpler?

In the SoC, the CPU (FlexBex) is the operand source. Operands come from CPU registers via `eFPGA_operand_a/b_o`, results go back to CPU registers via `eFPGA_result_a/b/c_i`. There's no need for the RegFile, no need for the IO counter, etc. — those are bare-fabric verification scaffolding.

The W side gets ibex_top's operands; the E side gets flexbex's. The choice of W vs E is a CPU choice (which `eFPGA_operand_a_*_o` lane the CPU drives). Both sides are computed combinationally on every cycle and the CPU's FSM picks one based on the `operator` field of the custom-instruction.

## See also

- [top.v](top.v) — minimal user logic
- [top_wrapper.v](top_wrapper.v) — BEL pinning
- [../Test/README.md](../Test/README.md) — SoC test flow
- [../README.md](../README.md) — SoC overview
- [../../user_design/README.md](../../user_design/README.md) — bare-fabric variant
