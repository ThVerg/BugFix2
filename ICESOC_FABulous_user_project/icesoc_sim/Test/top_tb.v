`timescale 1ps/1ps
module top_tb;
    wire [9:0] I_top;
    wire [9:0] T_top;
    reg [9:0] O_top;

    // reg [71:0] OPA;
    // reg [71:0] OPB;
    // wire [71:0] RES0;
    // wire [71:0] RES1;
    // wire [71:0] RES2;

    wire [19:0] A_cfg, B_cfg;

    reg CLK = 1'b0;
    reg reset = 1'b0;
    //reg SelfWriteStrobe = 1'b0;  //these are connected to the cores
    //reg [31:0] SelfWriteData = 1'b0; //these are connected to the cores
    reg Rx = 1'b1;
    wire ComActive;
    wire ReceiveLED;
    reg s_clk = 1'b0;
    reg s_data = 1'b0;


    logic wbs_stb_i; //unmapped for now
    logic wbs_cyc_i; //unmapped for now
    logic wbs_we_i; //unmapped for now
    logic [3:0] wbs_sel_i; //unmapped for now
    logic [31:0] wbs_dat_i; //unmapped for now
    logic [31:0] wbs_adr_i; //unmapped for now
    logic wbs_ack_o; //unmapped for now
    logic [31:0] wbs_dat_o; //unmapped for now
    logic [2:0] la_data_out; //unmapped for now
    logic [3:0] la_data_in; //unmapped for now
    logic [37:0] io_in;
    reg [37:0] io_out;
    logic [37:0] io_oeb; //unmapped for now
    logic dummy_signal_debug=1'b0;
    //logic dummy_signal2 = 1'b1;

    //logic rx_config; //send bitstream in through this 
    reg rxd_uart_to_mem; //send data to write to sram in through this
    logic txd_uart; //the core writes to this uart
    
    //assign io_in[5] = rx_config;
    assign io_in[9] = rxd_uart_to_mem;
    assign txd_uart = io_out[10];

    assign io_in[3] = s_clk;
    assign io_in[4] = s_data;
    assign io_in[5] = Rx;
    assign ReceiveLED = io_out[6];
    //assign la_data_out[2:0] = {ReceiveLED, Rx, ComActive};

    assign O_top = io_in[26:17];
    assign I_top = io_out[26:17];
    assign T_top = io_oeb[26:17]; //eFPGA IO pins
    
    //inputs to chip
    assign io_in[0] = CLK;
    assign io_in[1] = 1'b1; //to select wb_clk_i as input clk
    assign io_in[2] = 1'b1; //to select wb_clk_i as input clk
    //assign io_in[3] = 1'b0;
    //assign io_in[4] = 1'b0; //debug_req_1 = 0
    //assign io_in[5] = 1'b1; //fetch_enable_1 = 1
    assign io_in[6] = 1'b0; //debug_req_2 = 0
    assign io_in[7] = 1'b1; //fetch_enable_2 = 1
    //assign io_in[8] = 1'b0; //icesoc_top.rxd_uart=0
    //assign io_in[9] = 1'b1; //icesoc_top.rxd_uart_to_mem=1 (UART: inactive at 1)


    // Instantiate both the fabric and the reference DUT
    eFPGA_CPU_top eFPGA_CPU_top_i(
    `ifdef USE_POWER_PINS
        .vccd1(),	// User area 1 1.8V supply
        .vssd1(),	// User area 1 digital ground
    `endif
        //.resetn(resetn_config), //this was added only for the Config module because it has a resetn input
        .wb_clk_i(CLK),
        .wb_rst_i(reset),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        .la_data_out(la_data_out),
        .la_data_in(la_data_in),
        .io_in(io_in),
        .io_out(io_out),
        .io_oeb(io_oeb),
        .user_clock2(CLK)
    );

    localparam CLK_PER = 10000; //10000ps = 10ns 
    localparam MAX_BITBYTES = 20000;
    localparam NUM_INSTR = 6; //nr of instructions to be written to sram 
    localparam MEM_BYTES = NUM_INSTR * 7; //7 bytes written per instruction (uart to mem write_cmd, address etc))
    //localparam BIT_PERIOD = 8000;
    localparam BIT_PERIOD_UART_TO_MEM = 12 * CLK_PER;
    localparam BIT_PERIOD_CONFIG = 10 * CLK_PER;

    always #(CLK_PER/2) CLK = (CLK === 1'b0);

    integer i,j,k;
    integer fd;
    reg have_errors = 1'b0;

    reg [7:0] bitstream[0:MAX_BITBYTES-1];
    reg [7:0] memory[0:MEM_BYTES-1];
    reg [2047:0] bitstream_hex_arg; // 256 bytes for characters
    reg [2047:0] output_waveform_arg; // 256 bytes for characters
    reg [2047:0] mem_hex_arg;
    integer bitstream_bytes;

    // ============================================================
    // Functional verification — continuous fabric-level check.
    // After the bitstream loads, the fabric implements the user_design
    // top.v's combinational logic. We can verify on every clock edge
    // that the fabric outputs match the gold computation:
    //   W_RES0 == W_OPA ^ W_OPB     (XOR)
    //   W_RES1 == W_OPA & W_OPB     (AND)
    //   W_RES2 == W_OPA | W_OPB     (OR)
    //   E_RES0 == E_OPA + E_OPB     (ADD, 36-bit)
    //   E_RES1 == E_OPA - E_OPB     (SUB)
    //   E_RES2 == 36'h0_DEADBEEF    (constant)
    // The W_/E_ wires live inside eFPGA_CPU_top.v, between the CPU
    // cores' eFPGA hooks and the eFPGA fabric itself.
    // ============================================================
    integer total_checks    = 0;
    integer total_match     = 0;
    integer total_fail      = 0;
    integer total_skipped   = 0;  // skipped because inputs contained X/Z
    integer printed_samples = 0;
    reg     verify_active   = 1'b0;

    wire [35:0] chk_W_OPA  = eFPGA_CPU_top_i.W_OPA;
    wire [35:0] chk_W_OPB  = eFPGA_CPU_top_i.W_OPB;
    wire [35:0] chk_W_RES0 = eFPGA_CPU_top_i.W_RES0;
    wire [35:0] chk_W_RES1 = eFPGA_CPU_top_i.W_RES1;
    wire [35:0] chk_W_RES2 = eFPGA_CPU_top_i.W_RES2;
    wire [35:0] chk_E_OPA  = eFPGA_CPU_top_i.E_OPA;
    wire [35:0] chk_E_OPB  = eFPGA_CPU_top_i.E_OPB;
    wire [35:0] chk_E_RES0 = eFPGA_CPU_top_i.E_RES0;
    wire [35:0] chk_E_RES1 = eFPGA_CPU_top_i.E_RES1;
    wire [35:0] chk_E_RES2 = eFPGA_CPU_top_i.E_RES2;

    reg [35:0] exp_W_RES0, exp_W_RES1, exp_W_RES2;
    reg [35:0] exp_E_RES0, exp_E_RES1, exp_E_RES2;

    // Verification is now driven from the initial block (procedural stress
    // patterns) — no always-block needed. The CPU drives X on some control
    // signals during sim (no real firmware running), so we bypass the CPU
    // entirely and feed the fabric deterministic patterns through
    // eFPGA_CPU_top_i.gen_eFPGA.tb_drive_ops/tb_W_OPA/etc.

    initial begin

        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, top_tb);
            /*for (i = 0; i < MEM_BYTES; i = i + 1)
                $dumpvars(0, top_tb.memory[i]);
            for (i = 0; i < MAX_BITBYTES; i = i + 1)
                $dumpvars(0, top_tb.bitstream[i]);*/
            for (i = 0; i < 1024; i = i + 1)
                $dumpvars(0, top_tb.eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[i]);
            //$dumpvars(0, top_tb.eFPGA_CPU_top_i.icesoc_top_i.uart_to_mem_i.tx_byte_i);

            $display("Output waveform set to %s", output_waveform_arg);
        end

`ifndef EMULATION
        //the bitstream for configuration of the efpga is loaded into bitstream
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
        //the data to be written through uart to mem to initialize sram (including write command etc) is loaded into memory
        if ($value$plusargs("mem_hex=%s", mem_hex_arg)) begin
            fd = $fopen(mem_hex_arg, "r");
            if (fd != 0) begin
                $readmemh(mem_hex_arg, memory);
                $display("Read memory hex from %s", mem_hex_arg);
            end else begin
                $display("\nFailed to open the mem file %s", mem_hex_arg);
                $fatal;
            end

        end else begin
            $display("Error: No memory hex file provided as $plusargs mem_hex.");
            $fatal;
        end

        // Determine the actual bitstream length (skip trailing zero bytes
        // that makehex.py pads up to MAX_BITBYTES). Same trick as in the
        // bare-fabric testbench — strobing those zero words past the real
        // bitstream end can corrupt the config FSM.
        bitstream_bytes = MAX_BITBYTES;
        for (i = MAX_BITBYTES - 1; i >= 0; i = i - 1) begin
            if (bitstream[i] !== 8'h00) begin
                bitstream_bytes = ((i + 1) + 3) & ~3;
                i = -1;
            end
        end
        $display("Bitstream effective length: %0d bytes (of %0d max)", bitstream_bytes, MAX_BITBYTES);


        repeat (100) @(posedge CLK);
        reset = 1'b1;
        repeat (100) @(posedge CLK);
        reset = 1'b0;
        repeat (100) @(posedge CLK);

        //write memory contents to rxd_uart_to_mem 
        for (k = 0; k < MEM_BYTES; k = k + 1) begin
            //send_byte(memory[k], rxd_uart_to_mem);
            rxd_uart_to_mem = 1'b0;
            #BIT_PERIOD_UART_TO_MEM;
            rxd_uart_to_mem = 1'b0; //send second start bit because of weird uart
            #BIT_PERIOD_UART_TO_MEM;
            //because of the blocking assignments in the uart mem module that have been changed to non-blocking assignments, 9 bytes are sent every time (two stop bits are sent)
            for (i = 0; i < 8; i = i + 1) begin
                rxd_uart_to_mem = memory[k][i];
                dummy_signal_debug = ~dummy_signal_debug;
                #BIT_PERIOD_UART_TO_MEM;
            end
            rxd_uart_to_mem = 1'b1;
            #BIT_PERIOD_UART_TO_MEM;
            #(2*BIT_PERIOD_UART_TO_MEM); //wait between the bytes to avoid conflicts with the tx part
        end

        reset = 1'b1;
        repeat (100) @(posedge CLK);
        reset = 1'b0;
        repeat (100) @(posedge CLK);

        // Fast bitstream load via the eFPGA_CPU_top.v testbench override
        // (tb_sw_force / tb_sw_data / tb_sw_strobe). Mirrors the bare-fabric
        // SelfWrite sequence: settle data → pulse strobe → repeat. Skips
        // the UART entirely (~20s sim time → ~250us).
        // tb_sw_force stays HIGH for the rest of the run to mask the CPU's
        // eFPGA_write_strobe_1_o output — otherwise any later CPU strobe
        // pulse would re-write fabric config with garbage operand_a data.
        $display("Loading bitstream via SelfWrite override (%0d bytes)", bitstream_bytes);
        eFPGA_CPU_top_i.tb_sw_force = 1'b1;
        for (j = 0; j < bitstream_bytes; j = j + 4) begin
            eFPGA_CPU_top_i.tb_sw_data = {bitstream[j], bitstream[j+1], bitstream[j+2], bitstream[j+3]};
            repeat (2) @(posedge CLK);
            eFPGA_CPU_top_i.tb_sw_strobe = 1'b1;
            @(posedge CLK);
            eFPGA_CPU_top_i.tb_sw_strobe = 1'b0;
            repeat (2) @(posedge CLK);
        end
        // KEEP tb_sw_force = 1, tb_sw_strobe = 0, tb_sw_data = 0 — masks
        // the CPU strobe so fabric config is preserved.
        eFPGA_CPU_top_i.tb_sw_data   = 32'h0;
        eFPGA_CPU_top_i.tb_sw_strobe = 1'b0;
        $display("Bitstream load complete; CPU write_strobe masked for verification");
        repeat (50) @(posedge CLK);

`endif
        repeat (100) @(posedge CLK);
        reset = 1'b1; //reset to start the core
        repeat (100) @(posedge CLK);
        reset = 1'b0;
        repeat (100) @(posedge CLK);

        // ============================================================
        // Stress patterns — drive operands directly through the fabric
        // (bypassing the CPU) and verify against gold. Mirrors the
        // bare-fabric stress test, but the data path now goes through
        // eFPGA_CPU_top → interleave → fabric → de-interleave →
        // eFPGA_CPU_top, exercising the FULL SoC interconnect.
        // ============================================================
        eFPGA_CPU_top_i.gen_eFPGA.tb_drive_ops = 1'b1;
        $display("\n=== STRESS PATTERNS through SoC data path ===");
        begin : stress_phase
            integer pat;
            integer pat_errors;
            integer total_failed_patterns = 0;
            integer total_bit_errors = 0;
            integer total_patterns = 16;
            reg [35:0] pat_W_OPA, pat_W_OPB, pat_E_OPA, pat_E_OPB;
            reg [35:0] gold_W_RES0, gold_W_RES1, gold_W_RES2;
            reg [35:0] gold_E_RES0, gold_E_RES1, gold_E_RES2;

            for (pat = 0; pat < total_patterns; pat = pat + 1) begin
                // Same patterns as bare-fabric stress (first 16 of OPA, but
                // since icesoc top has only W_/E_ each 36 bits, split here).
                case (pat)
                    0:  begin pat_W_OPA = 36'h1_FFFF_FFFF; pat_W_OPB = 36'h5_5555_5555;
                              pat_E_OPA = 36'h0_0000_0001; pat_E_OPB = 36'hA_AAAA_AAAA; end
                    1:  begin pat_W_OPA = 0; pat_W_OPB = 0; pat_E_OPA = 0; pat_E_OPB = 0; end
                    2:  begin pat_W_OPA = 36'hF_FFFF_FFFF; pat_W_OPB = 36'hF_FFFF_FFFF;
                              pat_E_OPA = 36'hF_FFFF_FFFF; pat_E_OPB = 36'hF_FFFF_FFFF; end
                    3:  begin pat_W_OPA = 36'h1_2345_6789; pat_W_OPB = 36'h8_7654_3210;
                              pat_E_OPA = 36'hA_BCDE_F012; pat_E_OPB = 36'h0_FEDC_BA98; end
                    4:  begin pat_W_OPA = 36'h0_F0F0_F0F0; pat_W_OPB = 36'hF_0F0F_0F0F;
                              pat_E_OPA = 36'h0_F0F0_F0F0; pat_E_OPB = 36'hF_0F0F_0F0F; end
                    5:  begin pat_W_OPA = 36'h5_5555_5555; pat_W_OPB = 36'hA_AAAA_AAAA;
                              pat_E_OPA = 36'h5_5555_5555; pat_E_OPB = 36'hA_AAAA_AAAA; end
                    6:  begin pat_W_OPA = 36'h0_0100_0000; pat_W_OPB = 36'h0_0000_0100;
                              pat_E_OPA = 36'h0_0000_0001; pat_E_OPB = 36'h0_0100_0000; end
                    7:  begin pat_W_OPA = 36'hD_EADB_EEFD; pat_W_OPB = 36'hC_AFEB_ABEC;
                              pat_E_OPA = 36'h1_2345_6789; pat_E_OPB = 36'h9_ABCD_EF01; end
                    8:  begin pat_W_OPA = 36'h8_0000_0000; pat_W_OPB = 36'h0_0000_0001;
                              pat_E_OPA = 36'h0_8000_0000; pat_E_OPB = 36'h0_0000_0001; end
                    9:  begin pat_W_OPA = 36'h1_3579_BDF0; pat_W_OPB = 36'h2_468A_CE13;
                              pat_E_OPA = 36'h0_2468_ACE1; pat_E_OPB = 36'h3_579B_DF02; end
                    10: begin pat_W_OPA = 36'hF_EDCB_A987; pat_W_OPB = 36'h0_F1E2_D3C4;
                              pat_E_OPA = 36'h6_5432_10FF; pat_E_OPB = 36'hB_5A69_7887; end
                    11: begin pat_W_OPA = 36'h1_1111_1111; pat_W_OPB = 36'h2_2222_2222;
                              pat_E_OPA = 36'h3_3333_3333; pat_E_OPB = 36'h4_4444_4444; end
                    12: begin pat_W_OPA = 36'h7_FFFF_FFFF; pat_W_OPB = 36'h8_0000_0000;
                              pat_E_OPA = 36'h0_8000_0000; pat_E_OPB = 36'hF_FFFF_FFFF; end
                    13: begin pat_W_OPA = 36'h0_AAAA_AAAA; pat_W_OPB = 36'hB_5555_5555;
                              pat_E_OPA = 36'h0_F0F0_F0F0; pat_E_OPB = 36'hF_0F0F_0F0F; end
                    14: begin pat_W_OPA = 36'h0_03FF_FC00; pat_W_OPB = 36'hF_FC00_3FF0;
                              pat_E_OPA = 36'h0_0C00_FF00; pat_E_OPB = 36'h3_FFC0_0FF0; end
                    15: begin pat_W_OPA = 36'hA_BCDE_F012; pat_W_OPB = 36'h3_4567_89AB;
                              pat_E_OPA = 36'h9_8765_4321; pat_E_OPB = 36'h0_FEDC_BA98; end
                endcase

                eFPGA_CPU_top_i.gen_eFPGA.tb_W_OPA = pat_W_OPA;
                eFPGA_CPU_top_i.gen_eFPGA.tb_W_OPB = pat_W_OPB;
                eFPGA_CPU_top_i.gen_eFPGA.tb_E_OPA = pat_E_OPA;
                eFPGA_CPU_top_i.gen_eFPGA.tb_E_OPB = pat_E_OPB;
                repeat (5) @(posedge CLK);

                gold_W_RES0 = pat_W_OPA ^ pat_W_OPB;
                gold_W_RES1 = pat_W_OPA & pat_W_OPB;
                gold_W_RES2 = pat_W_OPA | pat_W_OPB;
                gold_E_RES0 = pat_E_OPA + pat_E_OPB;
                gold_E_RES1 = pat_E_OPA - pat_E_OPB;
                gold_E_RES2 = 36'h0_DEAD_BEEF;

                pat_errors = 0;
                if (chk_W_RES0 !== gold_W_RES0) pat_errors = pat_errors + 1;
                if (chk_W_RES1 !== gold_W_RES1) pat_errors = pat_errors + 1;
                if (chk_W_RES2 !== gold_W_RES2) pat_errors = pat_errors + 1;
                if (chk_E_RES0 !== gold_E_RES0) pat_errors = pat_errors + 1;
                if (chk_E_RES1 !== gold_E_RES1) pat_errors = pat_errors + 1;
                if (chk_E_RES2 !== gold_E_RES2) pat_errors = pat_errors + 1;
                total_bit_errors = total_bit_errors + pat_errors;

                if (pat_errors == 0) begin
                    $display("PATTERN %2d PASS  W_OPA=0x%h W_OPB=0x%h  E_OPA=0x%h E_OPB=0x%h",
                             pat, pat_W_OPA, pat_W_OPB, pat_E_OPA, pat_E_OPB);
                end else begin
                    total_failed_patterns = total_failed_patterns + 1;
                    have_errors = 1'b1;
                    $display("PATTERN %2d FAIL (%0d mismatches)", pat, pat_errors);
                    $display("           W_OPA=0x%h W_OPB=0x%h  E_OPA=0x%h E_OPB=0x%h",
                             pat_W_OPA, pat_W_OPB, pat_E_OPA, pat_E_OPB);
                    if (chk_W_RES0 !== gold_W_RES0)
                        $display("           W_RES0 fab=0x%h gold=0x%h  (XOR)", chk_W_RES0, gold_W_RES0);
                    if (chk_W_RES1 !== gold_W_RES1)
                        $display("           W_RES1 fab=0x%h gold=0x%h  (AND)", chk_W_RES1, gold_W_RES1);
                    if (chk_W_RES2 !== gold_W_RES2)
                        $display("           W_RES2 fab=0x%h gold=0x%h  (OR)",  chk_W_RES2, gold_W_RES2);
                    if (chk_E_RES0 !== gold_E_RES0)
                        $display("           E_RES0 fab=0x%h gold=0x%h  (ADD)", chk_E_RES0, gold_E_RES0);
                    if (chk_E_RES1 !== gold_E_RES1)
                        $display("           E_RES1 fab=0x%h gold=0x%h  (SUB)", chk_E_RES1, gold_E_RES1);
                    if (chk_E_RES2 !== gold_E_RES2)
                        $display("           E_RES2 fab=0x%h gold=0x%h  (DEADBEEF)", chk_E_RES2, gold_E_RES2);
                end
            end
            $display("\n=== STRESS SUMMARY ===");
            $display("  Patterns: %0d/%0d passed", total_patterns - total_failed_patterns, total_patterns);
            $display("  Total mismatches: %0d", total_bit_errors);
        end

        // ============================================================
        // Randomized stress phase — 200 random (W_OPA, W_OPB, E_OPA, E_OPB)
        // 4-tuples through the SoC's data path. Stress the interleave
        // mapping under random input bit patterns.
        // ============================================================
        begin : soc_rand_stress
            integer rpat;
            integer rand_total = 200;
            integer rand_failed = 0;
            integer rand_total_bit_errors = 0;
            integer rand_pat_errors;
            reg [35:0] rW_OPA, rW_OPB, rE_OPA, rE_OPB;
            reg [35:0] gold_a0, gold_a1, gold_a2, gold_b0, gold_b1, gold_b2;

            $display("\n=== SoC RANDOMIZED STRESS (200 patterns) ===");
            for (rpat = 0; rpat < rand_total; rpat = rpat + 1) begin
                rW_OPA = {$random, $random}; rW_OPB = {$random, $random};
                rE_OPA = {$random, $random}; rE_OPB = {$random, $random};
                eFPGA_CPU_top_i.gen_eFPGA.tb_W_OPA = rW_OPA;
                eFPGA_CPU_top_i.gen_eFPGA.tb_W_OPB = rW_OPB;
                eFPGA_CPU_top_i.gen_eFPGA.tb_E_OPA = rE_OPA;
                eFPGA_CPU_top_i.gen_eFPGA.tb_E_OPB = rE_OPB;
                repeat (5) @(posedge CLK);

                gold_a0 = rW_OPA ^ rW_OPB;
                gold_a1 = rW_OPA & rW_OPB;
                gold_a2 = rW_OPA | rW_OPB;
                gold_b0 = rE_OPA + rE_OPB;
                gold_b1 = rE_OPA - rE_OPB;
                gold_b2 = 36'h0_DEAD_BEEF;

                rand_pat_errors = 0;
                if (chk_W_RES0 !== gold_a0) rand_pat_errors = rand_pat_errors + 1;
                if (chk_W_RES1 !== gold_a1) rand_pat_errors = rand_pat_errors + 1;
                if (chk_W_RES2 !== gold_a2) rand_pat_errors = rand_pat_errors + 1;
                if (chk_E_RES0 !== gold_b0) rand_pat_errors = rand_pat_errors + 1;
                if (chk_E_RES1 !== gold_b1) rand_pat_errors = rand_pat_errors + 1;
                if (chk_E_RES2 !== gold_b2) rand_pat_errors = rand_pat_errors + 1;

                rand_total_bit_errors = rand_total_bit_errors + rand_pat_errors;
                if (rand_pat_errors != 0) begin
                    rand_failed = rand_failed + 1;
                    have_errors = 1'b1;
                    if (rand_failed <= 3) begin
                        $display("RAND %0d FAIL: W_OPA=0x%h W_OPB=0x%h E_OPA=0x%h E_OPB=0x%h",
                                 rpat, rW_OPA, rW_OPB, rE_OPA, rE_OPB);
                    end
                end
            end
            $display("=== SoC RANDOMIZED SUMMARY ===");
            $display("  Patterns: %0d/%0d passed (%0d failed)",
                     rand_total - rand_failed, rand_total, rand_failed);
            $display("  Total mismatches: %0d", rand_total_bit_errors);
        end

        eFPGA_CPU_top_i.gen_eFPGA.tb_drive_ops = 1'b0;

        // ============================================================
        // Phase 3: tiny RISC-V firmware test
        // Force a 4-instruction program into SRAM[0..3], reset the CPU,
        // wait for it to execute, and check the sentinel.
        //   0:  lui  x1, 0xDEADC          → x1 = 0xDEADC000
        //   4:  addi x1, x1, -273         → x1 = 0xDEADBEEF
        //   8:  sw   x1, 0x100(x0)        → SRAM[word 0x40] = 0xDEADBEEF
        //  12:  jal  x0, 0                → infinite loop
        // ============================================================
        $display("\n=== CPU FIRMWARE TEST ===");
        // Hold CPU in reset while loading the program
        reset = 1'b1;
        repeat (5) @(posedge CLK);
        // FlexBex eFPGA-accelerated test: have FlexBex (core 2) execute a
        // custom eFPGA instruction (opcode 0x0B) that reads E_RES2 from the
        // fabric (which computes 32'hDEADBEEF — the constant in top.v) and
        // store the result through the data path. End-to-end CPU↔fabric
        // round-trip via the actual FlexBex custom-instruction pipeline.
        //
        // Encoding of opcode 0x0B (eFPGA instr):
        //   [28:25]=delay  [24:20]=rs2  [19:15]=rs1  [13:12]=op
        //   [11:7]=rd      [6:0]=0x0b
        //
        //   PC 0x80: addi x1, x0, 0x100    -> x1 = 0x100   (operand_a, irrelevant)
        //   PC 0x84: addi x2, x0, 0x55     -> x2 = 0x55    (operand_b, irrelevant)
        //   PC 0x88: efpga x5, x1, x2, op=10 (result_c), delay=2  -> x5 = 0xDEADBEEF
        //   PC 0x8c: sw   x5, 0x100(x0)    -> mem[0x100] = 0xDEADBEEF
        //   PC 0x90: jal  x0, 0            -> infinite loop
        //
        // ibex_top (core 1) sees opcode 0x0B as illegal → traps and goes
        // wandering. As long as it doesn't overwrite mem[0x100], FlexBex's
        // store reaches the sentinel.
        // Multi-instruction firmware test, two phases:
        //   Phase A: 3 back-to-back ops with operator=2 (result_c, constant
        //            0xDEADBEEF). Verifies CPU pipeline + register writeback
        //            to x5/x6/x7 + sw to mem[0x100/0x104/0x108].
        //   Phase B: 2 ops with operator=0 (result_a = E_OPA + E_OPB) — first
        //            with both operands zero, second with non-zero operands.
        //            Verifies operand_a/operand_b actually flow through the
        //            fabric (not a stuck constant) and the result depends on
        //            register inputs.
        //            mem[0x10C] = result of (rs1=0, rs2=0)         → should be ~0 (just irq bits)
        //            mem[0x110] = result of (rs1=0x10000000, rs2=0x555) → 0x80000555 (assuming irq=0)
        //
        // Bit-level math behind the expected values:
        //   E_OPA[35]    = eFPGA_en (1 during op)
        //   E_OPA[34:3]  = rs1[31:0]   (CPU operand_a)
        //   E_OPA[2:0]   = {irq_id_2_o[1:0], irq_ack_2_o}  (typically 0)
        //   E_OPB[31:0]  = rs2[31:0]   (CPU operand_b)
        //   E_OPB[33:32] = eFPGA_delay[1:0]
        //   E_OPB[35:34] = eFPGA_operator
        //   result_a[31:0] = (E_OPA + E_OPB)[31:0]
        //                  = ((rs1[28:0] << 3) | irq) + rs2[31:0]    (mod 2^32)
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h080] = 32'h00000093; // addi x1, x0, 0
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h084] = 32'h00000113; // addi x2, x0, 0
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h088] = 32'h0420A28B; // efpga x5, x1, x2, op=2, delay=2
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h08c] = 32'h10502023; // sw x5, 0x100(x0)
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h090] = 32'h0420A30B; // efpga x6, x1, x2, op=2, delay=2
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h094] = 32'h10602223; // sw x6, 0x104(x0)
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h098] = 32'h0420A38B; // efpga x7, x1, x2, op=2, delay=2
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h09c] = 32'h10702423; // sw x7, 0x108(x0)
        // --- Phase B: operand-dependent eFPGA ops (op=0 = ADD via E_RES0) ---
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0a0] = 32'h0420850B; // efpga x10, x1, x2, op=0, delay=2  (zeros)
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0a4] = 32'h10A02623; // sw x10, 0x10C(x0)
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0a8] = 32'h100000B7; // lui  x1, 0x10000      ; x1 = 0x10000000
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0ac] = 32'h55500113; // addi x2, x0, 0x555   ; x2 = 0x555
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0b0] = 32'h0420858B; // efpga x11, x1, x2, op=0, delay=2
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0b4] = 32'h10B02823; // sw x11, 0x110(x0)
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h0b8] = 32'h0000006F; // jal x0, 0  (loop)
        // Clear all sentinel slots
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h100] = 32'h0;
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h104] = 32'h0;
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h108] = 32'h0;
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h10C] = 32'hAAAAAAAA; // pre-stamped; CPU should overwrite
        eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h110] = 32'hAAAAAAAA;
        $display("Test program loaded into SRAM[0..3], sentinel slot SRAM[0x40] cleared");

        // Release reset, let CPUs execute
        repeat (5) @(posedge CLK);
        reset = 1'b0;
        $display("Reset released — running CPUs for 1000 cycles");
        // Run for enough cycles for the multi-instruction program to complete
        // (3 eFPGA ops + 3 stores + jal loop ~= 50 cycles per iteration; 1000
        // gives plenty of margin even with FlexBex's eFPGA FSM delays).
        repeat (1000) @(posedge CLK);

        // Check all 3 sentinels — each must hold 0xDEADBEEF (eFPGA result_c)
        begin : firmware_check
            integer fw_pass = 0;
            if (eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h100] === 32'hDEADBEEF) begin
                $display("FIRMWARE pass 1: SRAM[0x100] = 0xDEADBEEF (efpga -> x5 -> sw)");
                fw_pass = fw_pass + 1;
            end else begin
                $display("FIRMWARE fail 1: SRAM[0x100] = 0x%h",
                         eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h100]);
                have_errors = 1'b1;
            end
            if (eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h104] === 32'hDEADBEEF) begin
                $display("FIRMWARE pass 2: SRAM[0x104] = 0xDEADBEEF (efpga -> x6 -> sw)");
                fw_pass = fw_pass + 1;
            end else begin
                $display("FIRMWARE fail 2: SRAM[0x104] = 0x%h",
                         eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h104]);
                have_errors = 1'b1;
            end
            if (eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h108] === 32'hDEADBEEF) begin
                $display("FIRMWARE pass 3: SRAM[0x108] = 0xDEADBEEF (efpga -> x7 -> sw)");
                fw_pass = fw_pass + 1;
            end else begin
                $display("FIRMWARE fail 3: SRAM[0x108] = 0x%h",
                         eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h108]);
                have_errors = 1'b1;
            end
            $display("=== CPU FIRMWARE Phase A: %0d/3 constant-result sentinels match ===", fw_pass);

            // ---- Phase B: operand-dependent ADD via op=0 ----
            begin : phase_b_check
                reg [31:0] r0c, r10;
                r0c = eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h10C];
                r10 = eFPGA_CPU_top_i.icesoc_top_i.sram_1_i.mem[32'h110];
                $display("FIRMWARE Phase B: SRAM[0x10C] = 0x%h  (expected ~0; rs1=0,rs2=0)", r0c);
                $display("FIRMWARE Phase B: SRAM[0x110] = 0x%h  (expected 0x80000555; rs1=0x10000000,rs2=0x555)", r10);

                // Soft assertions — verify operand-flow:
                //   1) Phase B's operand-dependent results are NOT 0xDEADBEEF
                //      (would mean the CPU somehow returned the constant op=2 path)
                //   2) The two phase-B results DIFFER (proves operands actually
                //      reach the fabric and influence the output)
                //   3) The non-zero-operand result has bit 31 set (since rs1=0x10000000
                //      shifts to bit 31 of E_OPA, dominating the sum)
                if (r0c === 32'hDEADBEEF || r10 === 32'hDEADBEEF) begin
                    $display("FIRMWARE Phase B FAIL: operand-dependent op returned constant 0xDEADBEEF — operand_a/b not flowing through fabric");
                    have_errors = 1'b1;
                end else if (r0c === r10) begin
                    $display("FIRMWARE Phase B FAIL: zero-operand and non-zero-operand ops gave same result 0x%h — operand flow broken", r0c);
                    have_errors = 1'b1;
                end else if (r10[31] !== 1'b1) begin
                    $display("FIRMWARE Phase B FAIL: non-zero-operand result 0x%h doesn't have expected bit 31 set", r10);
                    have_errors = 1'b1;
                end else begin
                    $display("FIRMWARE Phase B PASS: operands flow through fabric end-to-end");
                end
            end
        end
        // Enable and reset the counter
        //O_top = 28'b0000_0000_0000_0000_0000_0000_0011;
        //OPA = 72'h000000001FFFFFFFFF;
        //OPB = 72'hAAAAAAAAA555555555;
        //repeat (5) @(posedge CLK);
        // Deassert reset while keeping the counter enabled
        //O_top = 28'b0000_0000_0000_0000_0000_0000_0010;
        //for (i = 0; i < 100; i = i + 1) begin
            //@(negedge CLK);
            // $display("fabric(W_OPA) = 0x%X, fabric(W_OPB) = 0x%X", OPA[35:0], OPB[35:0]);
            // $display("fabric(W_RES0) = 0x%X gold = 0x%X, fabric(W_RES1) = 0x%X gold = 0x%X, fabric(W_RES2) = 0x%X gold = 0x%X", RES0[35:0], RES0_gold[35:0], RES1[35:0], RES1_gold[35:0], RES2[35:0], RES2_gold[35:0]);
            // $display("-------------------------------------------------------------");
            // $display("fabric(E_OPA) = 0x%X, fabric(E_OPB) = 0x%X", OPA[71:36], OPB[71:36]);
            // $display("fabric(E_RES0) = 0x%X gold = 0x%X, fabric(E_RES1) = 0x%X gold = 0x%X, fabric(E_RES2) = 0x%X gold = 0x%X", RES0[71:36], RES0_gold[71:36], RES1[71:36], RES1_gold[71:36], RES2[71:36], RES2_gold[71:36]);
            // $display("-------------------------------------------------------------");
            // $display("-------------------------------------------------------------");
            // if (RES0 !== RES0_gold)
            //     have_errors = 1'b1;
            // if (RES1 !== RES1_gold)
            //     have_errors = 1'b1;
            // if (RES2 !== RES2_gold)
            //     have_errors = 1'b1;
        //end

        // (verification done inline above)

        if (have_errors)
            $fatal;
        else
            $finish;
    end

    // task send_byte;
    //     input [7:0] cur_byte;
    //     integer i;
    //     begin
    //         tx = 1'b0;
    //         dummy_signal2 = 1'b0;
    //         #BIT_PERIOD;
    //         for (i = 0; i < 8; i = i + 1) begin
    //             tx = cur_byte[i];
    //             dummy_signal_debug = ~dummy_signal_debug;
    //             dummy_signal2 = cur_byte[i];
    //             #BIT_PERIOD;
    //         end
    //         tx = 1'b1;
    //         dummy_signal2 = 1'b1;
    //         #BIT_PERIOD;
    //     end
    // endtask

endmodule
