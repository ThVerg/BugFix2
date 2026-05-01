`timescale 1ps/1ps
module top_tb;
    wire [9:0] I_top;
    wire [9:0] T_top;
    reg [9:0] O_top = 0;

    reg [71:0] OPA;
    reg [71:0] OPB;
    wire [71:0] RES0;
    wire [71:0] RES1;
    wire [71:0] RES2;

    wire [19:0] A_cfg, B_cfg;

    reg CLK = 1'b0;
    reg resetn = 1'b1;
    reg SelfWriteStrobe = 1'b0;
    reg [31:0] SelfWriteData = 1'b0;
    reg Rx = 1'b1;
    wire ComActive;
    wire ReceiveLED;
    reg s_clk = 1'b0;
    reg s_data = 1'b0;

    // Instantiate both the fabric and the reference DUT
    eFPGA_top eFPGA_top_i (
        .I_top(I_top),
        .T_top(T_top),
        .O_top(O_top),
        .W_OPA(OPA[35:0]),
        .W_OPB(OPB[35:0]),
        .W_RES0(RES0[35:0]),
        .W_RES1(RES1[35:0]),
        .W_RES2(RES2[35:0]),

        .E_OPA(OPA[71:36]),
        .E_OPB(OPB[71:36]),
        .E_RES0(RES0[71:36]),
        .E_RES1(RES1[71:36]),
        .E_RES2(RES2[71:36]),
        .A_config_C(A_cfg), .B_config_C(B_cfg),
        .CLK(CLK), .resetn(resetn),
        .SelfWriteStrobe(SelfWriteStrobe), .SelfWriteData(SelfWriteData),
        .Rx(Rx),
        .ComActive(ComActive),
        .ReceiveLED(ReceiveLED),
        .s_clk(s_clk),
        .s_data(s_data)
    );


    wire [9:0] I_top_gold, oeb_gold, T_top_gold;
    wire [71:0] RES0_gold, RES1_gold, RES2_gold;


    //maybe the order of w and e is different, try if it works
    top dut_i (
        .clk(CLK),
        .W_OPA(OPA[35:0]),
        .W_OPB(OPB[35:0]),
        .E_OPA(OPA[71:36]),
        .E_OPB(OPB[71:36]),
        .W_RES0(RES0_gold[35:0]),
        .W_RES1(RES1_gold[35:0]),
        .W_RES2(RES2_gold[35:0]),
        .E_RES0(RES0_gold[71:36]),
        .E_RES1(RES1_gold[71:36]),
        .E_RES2(RES2_gold[71:36]),
        .io_out(I_top_gold),
        .io_oeb(oeb_gold),
        .io_in(O_top)
    );

    assign T_top_gold = ~oeb_gold;

    localparam MAX_BITBYTES = 20000;
    reg [7:0] bitstream[0:MAX_BITBYTES-1];

    always #5000 CLK = (CLK === 1'b0);

    integer i;
    integer fd;
    reg have_errors = 1'b0;

    reg [2047:0] bitstream_hex_arg; // 256 bytes for characters
    reg [2047:0] output_waveform_arg; // 256 bytes for characters

    initial begin

        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, top_tb);
            $display("Output waveform set to %s", output_waveform_arg);
        end

`ifndef EMULATION

        if ($value$plusargs("bitstream_hex=%s", bitstream_hex_arg)) begin
            fd = $fopen(bitstream_hex_arg, "r");
            if (fd != 0) begin
                $readmemh(bitstream_hex_arg, bitstream);
                $display("Read bitstream hex from %s", bitstream_hex_arg);
            end else begin
                $display("\nFailed to open the bitstream file %s", bitstream_hex_arg);
                $fatal;
            end

        end else begin
            $display("Error: No bitstream provided as $plusargs bitstream_hex.");
            $fatal;
        end


        #100;
        resetn = 1'b0;
        #10000;
        resetn = 1'b1;
        #10000;
        repeat (20) @(posedge CLK);
        #2500;
        for (i = 0; i < MAX_BITBYTES; i = i + 4) begin
            SelfWriteData <= {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            repeat (2) @(posedge CLK);
            SelfWriteStrobe <= 1'b1;
            @(posedge CLK);
            SelfWriteStrobe <= 1'b0;
            repeat (2) @(posedge CLK);
        end
`endif
        repeat (100) @(posedge CLK);
        // Enable and reset the counter
        O_top = 10'b00_0000_0011;
        OPA = 72'h000000001FFFFFFFFF;
        OPB = 72'hAAAAAAAAA555555555;
        repeat (5) @(posedge CLK);
        // Deassert reset while keeping the counter enabled
        O_top = 10'b00_0000_0010;
        for (i = 0; i < 100; i = i + 1) begin
            @(negedge CLK);
            $display("Clock Cycle %d", i );


            $display("W_IOs:");
            $display("  fabric(I_top) = 0x%X gold = 0x%X, fabric(T_top) = 0x%X gold = 0x%X\n", I_top, I_top_gold, T_top, T_top_gold);
            if (I_top !== I_top_gold)
                have_errors = 1'b1;
            if (T_top !== T_top_gold)
                have_errors = 1'b1;

            $display("\n-------------------------------------------------------------\n");
        end

        $display("W_CPU_IOs:");
        $display("  Inputs:");
        $display("  fabric(W_OPA) = 0x%X, fabric(W_OPB) = 0x%X", OPA[35:0], OPB[35:0]);
        $display("  Outputs:");
        $display("  fabric(W_RES0) = 0x%X gold = 0x%X, fabric(W_RES1) = 0x%X gold = 0x%X, fabric(W_RES2) = 0x%X gold = 0x%X\n", RES0[35:0], RES0_gold[35:0], RES1[35:0], RES1_gold[35:0], RES2[35:0], RES2_gold[35:0]);

        $display("E_CPU_IOs:");
        $display("  Inputs:");
        $display("  fabric(E_OPA) = 0x%X, fabric(E_OPB) = 0x%X", OPA[71:36], OPB[71:36]);
        $display("  Outputs:");
        $display("  fabric(E_RES0) = 0x%X gold = 0x%X, fabric(E_RES1) = 0x%X gold = 0x%X, fabric(E_RES2) = 0x%X gold = 0x%X\n", RES0[71:36], RES0_gold[71:36], RES1[71:36], RES1_gold[71:36], RES2[71:36], RES2_gold[71:36]);

        if (RES0 !== RES0_gold)
            have_errors = 1'b1;
        if (RES1 !== RES1_gold)
            have_errors = 1'b1;
        if (RES2 !== RES2_gold)
            have_errors = 1'b1;

        if (have_errors)
            $fatal;
        else
            $finish;
    end

endmodule
