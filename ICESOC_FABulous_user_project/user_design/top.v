// Stress design — exercises:
//   LUT4AB         — XOR/AND/OR/rotate/ADD/SUB/MUL8x8/counter logic
//   W_CPU_IO + bot — OPA/OPB inputs, RES outputs (W column, all 36 bits)
//   E_CPU_IO + bot — OPA/OPB inputs, RES outputs (E column, all 36 bits)
//   W_IO           — io_in/io_out/io_oeb (10 pads)
//   RegFile        — 32x4 register file inferred from the reg array
//   N_term/S_term  — exercised passively (every routed wire crosses these terminators)
//
// DSP (MULADD) and BRAM are NOT exercised here:
// - DSP MULADD would need explicit instantiation, but the synth-side prims.v
//   uses .CLK + parameters while the hardware MULADD.v uses .UserCLK +
//   .ConfigBits, so the same module name has incompatible signatures for
//   yosys vs. iverilog. The 8x8 LUT multiplier below stresses LUT carry
//   chains instead.
// - BRAM (RAM_IO column) needs top_wrapper.v changes to expose the
//   FAB2RAM_*/RAM2FAB_* pads as user_design ports.

module top(
    input wire clk,
    input wire [35:0] W_OPA, W_OPB, E_OPA, E_OPB,
    input wire [9:0] io_in,
    output wire [35:0] W_RES0, W_RES1, W_RES2, E_RES0, E_RES1, E_RES2,
    output wire [9:0] io_out, io_oeb
);

    // ============ W side: bitwise + RegFile ============
    assign W_RES0 = W_OPA ^ W_OPB;
    assign W_RES1 = W_OPA & W_OPB;

    // 32-entry x 4-bit register file (1 sync write + 2 async reads).
    // synth_fabulous infers this as $__REGFILE_AA_ → RegFile_32x4 BEL.
    reg [3:0] regfile [0:31];
    wire [4:0] rf_w_addr = W_OPB[12:8];
    wire [3:0] rf_w_data = W_OPA[3:0];
    always @(posedge clk) regfile[rf_w_addr] <= rf_w_data;
    // No `initial` block — it would prevent yosys from inferring RegFile_32x4
    // and force a LUT-based mux instead. The testbench warm-up phase walks
    // through every address before the stress patterns to bring both gold and
    // fabric into a known state.

    wire [4:0] rf_a_addr = W_OPA[12:8];
    wire [4:0] rf_b_addr = W_OPB[17:13];
    wire [3:0] rf_a_data = regfile[rf_a_addr];
    wire [3:0] rf_b_data = regfile[rf_b_addr];

    assign W_RES2[31:0]  = (W_OPA[31:0] | W_OPB[31:0]) ^ {W_OPA[30:0], W_OPA[31]};
    assign W_RES2[35:32] = rf_a_data ^ rf_b_data;

    // ============ E side: arithmetic + DSP MULADD ============
    assign E_RES0 = E_OPA + E_OPB;
    assign E_RES1 = E_OPA - E_OPB;

    // 8x8 unsigned multiply on LUTs (16-bit product, zero-padded to 36).
    assign E_RES2 = {20'b0, E_OPA[7:0] * E_OPB[7:0]};

    // ============ Sequential counter ============
    wire rst = io_in[0];
    wire en  = io_in[1];
    reg [31:0] ctr;
    always @(posedge clk) begin
        if (en) begin
            if (rst) ctr <= 32'h0;
            else     ctr <= ctr + 1'b1;
        end
    end

    assign io_out[9:2] = ctr[7:0];
    assign io_oeb      = 10'b11_1111_1100;
    assign io_out[1:0] = 2'h0;

endmodule
