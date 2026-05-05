# ibex_core/ — FlexBex (Ibex variant) RTL

This directory holds **FlexBex**: a customized [Ibex](https://github.com/lowRISC/ibex) RISC-V core with a custom instruction extension for eFPGA acceleration. It also has the regular Ibex modules used by the second core (`ibex_top`) in the SoC.

The icesoc instantiates **two cores**:
- **Core 1 / `ibex_top`** — a slightly extended vanilla Ibex with eFPGA hooks (drives W side of the fabric)
- **Core 2 / `flexbex_ibex_core`** — full FlexBex with custom-instruction decoding (drives E side)

## FlexBex extension — opcode 0x0B

Looking at `flexbex_ibex_decoder.v`:

```verilog
7'h0b: begin
    regfile_we = 1'b1;
    eFPGA_operator_o = instr_rdata_i[13:12];   // op[1:0]
    eFPGA_delay_o    = instr_rdata_i[28:25];   // delay[3:0]
    eFPGA_int_en     = 1'b1;                   // trigger eFPGA FSM
end
```

Encoding (R-type-ish):

```
 31     29 28 25 24    20 19    15 14 13  12 11  7 6      0
┌────────┬─────┬────────┬────────┬──┬─────┬─────┬────────┐
│  rsv   │delay│   rs2  │   rs1  │ ?│ op  │  rd │  0x0B  │
└────────┴─────┴────────┴────────┴──┴─────┴─────┴────────┘
```

| Field | Meaning |
|---|---|
| `op` (bits 13:12) | 00 = result_a, 01 = result_b, 10 = result_c, 11 = config write |
| `delay` (bits 28:25) | Cycles to wait before capture; 15 = wait for `eFPGA_fpga_done` |

For our user_design `top.v`:
- W side (ibex_top): result_a = XOR, result_b = AND, result_c = OR
- E side (flexbex): result_a = ADD, result_b = SUB, result_c = constant `0xDEADBEEF`

## Operand routing

`flexbex_ibex_id_stage.v`:

```verilog
assign eFPGA_operand_a_o = regfile_data_ra_id;   // = rs1 register value
assign eFPGA_operand_b_o = regfile_data_rb_id;   // = rs2 register value
```

These flow into the SoC's `eFPGA_CPU_top.v` and end up wired to W_OPA[34:3]/W_OPB[31:0] (for ibex_top, core 1) or E_OPA[34:3]/E_OPB[31:0] (for flexbex, core 2). The fabric computes the user_design's logic, returns 3× 32-bit results.

## Result writeback

`flexbex_ibex_ex_block.v`:

```verilog
assign regfile_wdata_ex_o = (multdiv_en ? multdiv_result :
                             (eFPGA_en_i ? eFPGA_result :
                                           alu_result));
```

If an eFPGA op is in progress, its result (from the FSM) wins over the ALU output for that cycle's regfile write.

## eFPGA FSM (`flexbex_ibex_eFPGA.v`)

Tiny 2-bit FSM:

```
state 0 (idle):
   if (en_i) → state 1; if op==11 also assert write_strobe
state 1 (counting):
   count++; if count==delay (or fpga_done if delay==15) → state 2
   capture endresult based on operator
state 2 (done):
   ready_o = 1; → state 0
```

The FSM holds the operands stable on `eFPGA_operand_a/b_o` for `delay` cycles. The fabric is combinational, so its output is also stable. After `delay` cycles, the FSM captures `result_a/b/c` into `endresult_o`, which then flows into the ex_block's mux above.

## Files

| File | Role |
|---|---|
| **`flexbex_ibex_core.v`** | Top of FlexBex (Core 2). Instantiates id_stage, ex_block, etc. |
| **`flexbex_ibex_decoder.v`** | RISC-V + custom 0x0B decoder. |
| **`flexbex_ibex_eFPGA.v`** | The eFPGA accelerator FSM. |
| **`flexbex_ibex_id_stage.v`** | ID stage with eFPGA hooks (operand_a/b ← regfile reads). |
| **`flexbex_ibex_ex_block.v`** | Execute stage with regfile_wdata mux. |
| **`flexbex_ibex_alu.v`** | Standard ALU. |
| **`flexbex_ibex_compressed_decoder.v`** | C-extension decoder. |
| **`flexbex_ibex_controller.v`** | Pipeline controller. |
| **`flexbex_ibex_cs_registers.v`** | CSR file. |
| **`flexbex_ibex_fetch_fifo.v`** | Instruction fetch FIFO. |
| **`flexbex_ibex_if_stage.v`** | Instruction fetch stage. |
| **`flexbex_ibex_int_controller.v`** | Interrupt controller. |
| **`flexbex_ibex_load_store_unit.v`** | LSU. |
| **`flexbex_ibex_multdiv_fast.v`** | Multiplier/divider. |
| **`flexbex_ibex_prefetch_buffer.v`** | Prefetch buffer. |
| **`flexbex_ibex_register_file.v`** | 32-entry GPR file. |
| **`flexbex_prim_clock_gating.v`** | Clock gating cell. |
| **`ibex_*.v`, `ibex_aes_sbox.v`** | Vanilla Ibex modules used by Core 1 (ibex_top). |

## See also

- [../README.md](../README.md) — SoC RTL overview
- [../../Test/README.md](../../Test/README.md) — how the testbench drives the eFPGA opcode
- [flexbex_ibex_eFPGA.v](flexbex_ibex_eFPGA.v) — the accelerator FSM (~66 lines, a good read)
- [flexbex_ibex_decoder.v](flexbex_ibex_decoder.v) — opcode 0x0B decoding
