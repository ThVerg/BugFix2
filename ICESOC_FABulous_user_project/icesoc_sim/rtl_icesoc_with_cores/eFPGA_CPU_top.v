// SPDX-FileCopyrightText: 
// 2021 Nguyen Dao
// 2021 Andrew Attwood
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
`ifndef USEeFPGA
  `define USEeFPGA 1
`endif

`default_nettype none

module eFPGA_CPU_top (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    input wire resetn, //this was added only for the Config module because it has a resetn input 
    // Wishbone Slave ports (WB MI A)
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire wbs_stb_i,
    input wire wbs_cyc_i,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output logic wbs_ack_o,
    output logic [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    output logic [2:0] la_data_out,
    input wire [3:0] la_data_in,

    // IOs
    input wire [37:0] io_in, //CLK: [2:0] eFPGA: [12:3]
    output logic [37:0] io_out, //CLK: [2:0] eFPGA: [12:3]
    output logic [37:0] io_oeb, //CLK: [2:0] eFPGA: [12:3]

    // Independent clock (on independent integer divider)
    input wire user_clock2
);

localparam include_eFPGA    = `USEeFPGA;
localparam NumberOfRows     = 14;
localparam NumberOfCols     = 15;
localparam FrameBitsPerRow  = 32;
localparam MaxFramesPerCol  = 20;
localparam desync_flag      = 20;
localparam FrameSelectWidth =  5;
localparam RowSelectWidth   =  5;

assign io_oeb[ 7:0] =  8'b00000000; //CLK and configuration
assign io_oeb[12:8] =  5'b11100; //CPU

wire [1:0]  clk_sel = {io_in[2],io_in[1]};
wire external_clock = io_in[0];
// This clock can go to the CPU (connects to the fabric LUT output flops
wire            CLK = clk_sel[0] ? (clk_sel[1] ? wb_clk_i : user_clock2) : external_clock;

// To CPU
wire [36-1:0] W_OPA; //from RISCV
wire [36-1:0] W_OPB; //from RISCV
wire [36-1:0] W_RES0; //to RISCV
wire [36-1:0] W_RES1; //to RISCV
wire [36-1:0] W_RES2; //to RISCV

wire [36-1:0] E_OPA; //from RISCV
wire [36-1:0] E_OPB; //from RISCV
wire [36-1:0] E_RES0; //to RISCV
wire [36-1:0] E_RES1; //to RISCV
wire [36-1:0] E_RES2; //to RISCV

// CPU configuration port
wire [31:0] eFPGA_operand_a_1_o;
wire [31:0] SelfWriteData; // configuration data write port
wire        SelfWriteStrobe; // must decode address and write enable
assign W_OPA[34:3]   = eFPGA_operand_a_1_o;
assign SelfWriteData = eFPGA_operand_a_1_o;

reg debug_req_1;
reg fetch_enable_1;
reg debug_req_2;
reg fetch_enable_2;

always @(*) begin
	if(io_in[3] == 1'b1 )begin
		debug_req_1 =  la_data_in[0];
		fetch_enable_1 = la_data_in[1];
		debug_req_2 = la_data_in[2];
		fetch_enable_2 = la_data_in[3];
	end 
	else begin
		debug_req_1 = io_in[4];
		fetch_enable_1 = io_in[5];
		debug_req_2 = io_in[6];
		fetch_enable_2 = io_in[7];
	end
end 

//CPU instantiation
icesoc_top   icesoc_top_i (
    //core 1
    .debug_req_1_i(debug_req_1),       //todo needs LA in PIN
    .fetch_enable_1_i(fetch_enable_1), //todo needs LA in PIN
    .irq_ack_1_o(W_OPA[0]),
    .irq_1_i(W_RES1[33]),
    .irq_id_1_i({W_RES1[32],W_RES0[35:32]}),
    .irq_id_1_o(W_OPA[2:1]),
    .eFPGA_operand_a_1_o(eFPGA_operand_a_1_o),
    .eFPGA_operand_b_1_o(W_OPB[31:0]),
    .eFPGA_result_a_1_i(W_RES0[31:0]),
    .eFPGA_result_b_1_i(W_RES1[31:0]),
    .eFPGA_result_c_1_i(W_RES2[31:0]),
    .eFPGA_write_strobe_1_o(SelfWriteStrobe),//todo write strobe connection
    .eFPGA_fpga_done_1_i(W_RES1[34]), 
    .eFPGA_delay_1_o(W_OPB[33:32]),
    .eFPGA_en_1_o(W_OPA[35]),
    .eFPGA_operator_1_o(W_OPB[35:34]),

    //Wishbone to carvel
    .wb_clk_i(CLK), 
    .wb_rst_i(wb_rst_i),
    .wbs_stb_i(wbs_stb_i),
    .wbs_cyc_i(wbs_cyc_i),
    .wbs_we_i(wbs_we_i),
    .wbs_sel_i(wbs_sel_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_ack_o(wbs_ack_o),
    .wbs_dat_o(wbs_dat_o),

    //core 2
    .debug_req_2_i(debug_req_2),       //todo needs LA in PIN
    .fetch_enable_2_i(fetch_enable_2), //todo needs LA in PIN
    .irq_ack_2_o(E_OPA[0]), 
    .irq_2_i(E_RES1[33]),
    .irq_id_2_i({E_RES1[32],E_RES0[35:32]}),
    .irq_id_2_o(E_OPA[2:1]),
    .eFPGA_operand_a_2_o(E_OPA[34:3]),
    .eFPGA_operand_b_2_o(E_OPB[31:0]),
    .eFPGA_result_a_2_i(E_RES0[31:0]),
    .eFPGA_result_b_2_i(E_RES1[31:0]),
    .eFPGA_result_c_2_i(E_RES2[31:0]),
    .eFPGA_write_strobe_2_o(io_out[16]),
    .eFPGA_fpga_done_2_i(E_RES1[34]),
    .eFPGA_delay_2_o(E_OPB[33:32]),
    .eFPGA_en_2_o(E_OPA[35]),
    .eFPGA_operator_2_o(E_OPB[35:34]),

    //uart pins to USER area off chip IO
    .rxd_uart(io_in[8]),
    .txd_uart(io_out[10]),
    .rxd_uart_to_mem(io_in[9]),
    .txd_uart_to_mem(io_out[11]),
    .error_uart_to_mem(io_out[12])
);
generate
    if (include_eFPGA == 0) begin : gen_eFPGA_tieoff
        assign la_data_out[2:0] = 3'b000;
        assign io_out[6]        = 1'b0;
        assign io_out[26:17]    = 10'd0;
        assign io_oeb[26:17]    = 10'd0; //eFPGA IO pins

        assign W_RES0           = 36'd0; //to RISCV
        assign W_RES1           = 36'd0; //to RISCV
        assign W_RES2           = 36'd0; //to RISCV

        assign E_RES0           = 36'd0; //to RISCV
        assign E_RES1           = 36'd0; //to RISCV
        assign E_RES2           = 36'd0; //to RISCV
        wire [36-1:0] unused0   = W_OPA; //from RISCV
        wire [36-1:0] unused1   = W_OPB; //from RISCV
        wire [36-1:0] unused2   = E_OPA; //from RISCV
        wire [36-1:0] unused3   = E_OPB; //from RISCV
        wire [31  :0] unused4   = SelfWriteData;
    end else begin                : gen_eFPGA
        // UART configuration port
        wire Rx;
        wire ComActive;
        wire ReceiveLED;

        // BitBang configuration port
        wire s_clk;
        wire s_data;

        //BlockRAM ports
        wire [80-1:0] RAM2FAB_D;
        wire [80-1:0] FAB2RAM_D;
        wire [40-1:0] FAB2RAM_A;
        wire [20-1:0] FAB2RAM_C;
        wire [20-1:0] Config_accessC;

        // External USER ports
        //inout [16-1:0] PAD; // these are for Dirk and go to the pad ring
        wire [10-1:0] I_top;
        wire [10-1:0] T_top;
        wire [10-1:0] O_top;
        wire [20-1:0] A_config_C;
        wire [20-1:0] B_config_C;

        // Signal declarations
        wire [(NumberOfRows*FrameBitsPerRow)-1:0] FrameRegister;
        wire [(MaxFramesPerCol*NumberOfCols)-1:0] FrameSelect;
        wire [(FrameBitsPerRow*(NumberOfRows+2))-1:0] FrameData;

        wire [FrameBitsPerRow-1:0] FrameAddressRegister;
        wire LongFrameStrobe;
        wire [31:0] LocalWriteData;
        wire LocalWriteStrobe;
        wire [RowSelectWidth-1:0] RowSelect;

        assign s_clk            = io_in[3];
        assign s_data           = io_in[4];
        assign Rx               = io_in[5];
        assign io_out[6]        = ReceiveLED;
        assign la_data_out[2:0] = {ReceiveLED, Rx, ComActive};

        assign O_top = io_in[26:17];
        assign io_out[26:17] = I_top;
        assign io_oeb[26:17] = T_top; //eFPGA IO pins

        wire resetn_local;
        assign resetn_local = resetn;

        eFPGA_top eFPGA_top_i (
        // #(
        //     .include_eFPGA(1),
        //     .NumberOfRows(14),
        //     .NumberOfCols(15),
        //     .FrameBitsPerRow(32),
        //     .MaxFramesPerCol(20),
        //     .desync_flag(20),
        //     .FrameSelectWidth(5),
        //     .RowSelectWidth(5)
        // )
       // (
            //External IO port
            .A_config_C(A_config_C),
            .B_config_C(B_config_C),
            .Config_accessC(Config_accessC),
            .I_top(I_top),
            .O_top(O_top),
            .OPA_I({W_OPA, E_OPA}),
            .OPB_I({W_OPB, E_OPB}),
            .RES0_O({W_RES0, E_RES0}),
            .RES1_O({W_RES1, E_RES1}),
            .RES2_O({W_RES2, E_RES2}),
            // .W_OPA(W_OPA),
            // .W_OPB(W_OPB),
            // .W_RES0(W_RES0),
            // .W_RES1(W_RES1),
            // .W_RES2(W_RES2),

            // .E_OPA(E_OPA),
            // .E_OPB(E_OPB),
            // .E_RES0(E_RES0),
            // .E_RES1(E_RES1),
            // .E_RES2(E_RES2),
            .T_top(T_top),
            //Config related ports
            .CLK(CLK),
            .resetn(), //this does not exist in the original rtl
            .SelfWriteStrobe(SelfWriteStrobe),
            .SelfWriteData(SelfWriteData),
            .Rx(Rx),
            .ComActive(ComActive),
            .ReceiveLED(ReceiveLED),
            .s_clk(s_clk),
            .s_data(s_data)
        );

    end
endgenerate

endmodule
`default_nettype wire
