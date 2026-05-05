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

    // Bridge from this testbench's logical W/E split (OPA[35:0] = W half,
    // OPA[71:36] = E half) to the current eFPGA_top port signature, which
    // exposes a single 72-bit OPA_I/OPB_I/RES{0,1,2}_O bus with W (column
    // X=3) and E (column X=11) bits interleaved per fabric row Y. Inside
    // each 4-bit BEL slot the pin order is bit-reversed relative to the
    // user_design vector — see Tile X3Y9.OPA in top_wrapper.v
    // (.O0=W_OPA[3], .O1=W_OPA[2], .O2=W_OPA[1], .O3=W_OPA[0]).
    wire [71:0] OPA_I_bus, OPB_I_bus;
    wire [71:0] RES0_O_bus, RES1_O_bus, RES2_O_bus;
    wire [19:0] Config_accessC; // unused output exposed by current eFPGA_top

    genvar gi;
    generate
        for (gi = 0; gi < 9; gi = gi + 1) begin : eFPGA_io_map
            // W column (X=3): fabric bits gi*8 + 0..3
            assign OPA_I_bus[gi*8 +: 4] = {OPA[gi*4], OPA[gi*4+1], OPA[gi*4+2], OPA[gi*4+3]};
            assign OPB_I_bus[gi*8 +: 4] = {OPB[gi*4], OPB[gi*4+1], OPB[gi*4+2], OPB[gi*4+3]};
            assign RES0[gi*4 +: 4] = {RES0_O_bus[gi*8], RES0_O_bus[gi*8+1], RES0_O_bus[gi*8+2], RES0_O_bus[gi*8+3]};
            assign RES1[gi*4 +: 4] = {RES1_O_bus[gi*8], RES1_O_bus[gi*8+1], RES1_O_bus[gi*8+2], RES1_O_bus[gi*8+3]};
            assign RES2[gi*4 +: 4] = {RES2_O_bus[gi*8], RES2_O_bus[gi*8+1], RES2_O_bus[gi*8+2], RES2_O_bus[gi*8+3]};
            // E column (X=11): fabric bits gi*8 + 4..7
            assign OPA_I_bus[gi*8+4 +: 4] = {OPA[36+gi*4], OPA[36+gi*4+1], OPA[36+gi*4+2], OPA[36+gi*4+3]};
            assign OPB_I_bus[gi*8+4 +: 4] = {OPB[36+gi*4], OPB[36+gi*4+1], OPB[36+gi*4+2], OPB[36+gi*4+3]};
            assign RES0[36+gi*4 +: 4] = {RES0_O_bus[gi*8+4], RES0_O_bus[gi*8+5], RES0_O_bus[gi*8+6], RES0_O_bus[gi*8+7]};
            assign RES1[36+gi*4 +: 4] = {RES1_O_bus[gi*8+4], RES1_O_bus[gi*8+5], RES1_O_bus[gi*8+6], RES1_O_bus[gi*8+7]};
            assign RES2[36+gi*4 +: 4] = {RES2_O_bus[gi*8+4], RES2_O_bus[gi*8+5], RES2_O_bus[gi*8+6], RES2_O_bus[gi*8+7]};
        end
    endgenerate

    // Instantiate the fabric and the reference DUT
    eFPGA_top eFPGA_top_i (
        .I_top(I_top),
        .T_top(T_top),
        .O_top(O_top),
        .OPA_I(OPA_I_bus),
        .OPB_I(OPB_I_bus),
        .RES0_O(RES0_O_bus),
        .RES1_O(RES1_O_bus),
        .RES2_O(RES2_O_bus),
        .A_config_C(A_cfg),
        .B_config_C(B_cfg),
        .Config_accessC(Config_accessC),
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
    integer bitstream_bytes;

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

        // Find the actual bitstream length: scan from the top down for the
        // first non-zero byte. makehex.py zero-pads up to MAX_BITBYTES, but
        // strobing those trailing zero words past the real bitstream end
        // appears to wrap the config FSM and re-program the first-loaded
        // tiles (the top of the CPU_IO stem) with zeros.
        bitstream_bytes = MAX_BITBYTES;
        for (i = MAX_BITBYTES - 1; i >= 0; i = i - 1) begin
            if (bitstream[i] !== 8'h00) begin
                bitstream_bytes = ((i + 1) + 3) & ~3; // round up to multiple of 4
                i = -1; // exit
            end
        end
        $display("Bitstream effective length: %0d bytes (of %0d max)", bitstream_bytes, MAX_BITBYTES);

        #100;
        resetn = 1'b0;
        #10000;
        resetn = 1'b1;
        #10000;
        repeat (20) @(posedge CLK);
        #2500;
        for (i = 0; i < bitstream_bytes; i = i + 4) begin
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
        // Deassert reset while keeping the counter enabled — counter phase exercises
        // the W_IO bidirectional pads + LUT4AB DFF chains for the 32-bit ctr.
        O_top = 10'b00_0000_0010;
        begin : counter_phase
            integer ctr_errors = 0;
            for (i = 0; i < 100; i = i + 1) begin
                @(negedge CLK);
                if (I_top !== I_top_gold || T_top !== T_top_gold) begin
                    ctr_errors = ctr_errors + 1;
                    $display("CTR cycle %0d FAIL: I_top fab=0x%X gold=0x%X  T_top fab=0x%X gold=0x%X",
                             i, I_top, I_top_gold, T_top, T_top_gold);
                    have_errors = 1'b1;
                end
            end
            if (ctr_errors == 0)
                $display("COUNTER: 100/100 cycles match (I_top=0x%X, T_top=0x%X)", I_top, T_top);
            else
                $display("COUNTER: %0d/100 cycles FAILED", ctr_errors);
        end

        // ============================================================
        // RegFile warm-up — the design infers a 32x4 RegFile (placed on
        // the RegFile tile). The fabric BEL and the gold sim model both
        // power up unwritten entries differently (BEL=0, sim=X), so we
        // walk every address 0..31 and write 0 to it before the stress
        // patterns to bring both into the same known state.
        // ============================================================
        begin : regfile_warmup
            integer addr;
            // OPA[3:0] = write data = 0; OPB[12:8] = write address
            // OPA[12:8] and OPB[17:13] = read addresses (irrelevant during warmup)
            OPA = 72'h0;
            for (addr = 0; addr < 32; addr = addr + 1) begin
                OPB = {54'h0, addr[4:0], 13'h0};  // OPB[17:13]=addr also (harmless)
                OPB[12:8] = addr[4:0];
                @(posedge CLK);
                @(posedge CLK);
            end
            $display("RegFile warmup complete (wrote 0 to all 32 entries)");
        end

        // ============================================================
        // Stress patterns — exercise the full 36-bit datapath through
        // every CPU_IO BEL row across XOR/AND/OR/rotate (W) and
        // ADD/SUB/MUL (E). Each pattern is held for several cycles so
        // combinational results settle through the fabric routing.
        // ============================================================
        begin : stress_phase
            integer pat;
            integer pat_errors;
            integer total_failed_patterns = 0;
            integer total_bit_errors = 0;
            integer total_patterns = 16;
            reg [71:0] pat_OPA, pat_OPB;

            $display("\n=== STRESS PATTERNS ===");
            for (pat = 0; pat < total_patterns; pat = pat + 1) begin
                case (pat)
                    0:  begin pat_OPA = 72'h000000001FFFFFFFFF; pat_OPB = 72'hAAAAAAAAA555555555; end
                    1:  begin pat_OPA = 72'h000000000000000000; pat_OPB = 72'h000000000000000000; end
                    2:  begin pat_OPA = 72'hFFFFFFFFFFFFFFFFFF; pat_OPB = 72'hFFFFFFFFFFFFFFFFFF; end
                    3:  begin pat_OPA = 72'h123456789ABCDEF012; pat_OPB = 72'h876543210FEDCBA987; end
                    4:  begin pat_OPA = 72'h0F0F0F0F0F0F0F0F0F; pat_OPB = 72'hF0F0F0F0F0F0F0F0F0; end
                    5:  begin pat_OPA = 72'h555555555555555555; pat_OPB = 72'hAAAAAAAAAAAAAAAAAA; end
                    6:  begin pat_OPA = 72'h001000000000000001; pat_OPB = 72'h000000001001000000; end
                    7:  begin pat_OPA = 72'hDEADBEEFDEADBEEFDE; pat_OPB = 72'hCAFEBABECAFEBABECA; end
                    8:  begin pat_OPA = 72'h800000000800000000; pat_OPB = 72'h000000001000000001; end // single high bits
                    9:  begin pat_OPA = 72'h13579BDF02468ACE13; pat_OPB = 72'h2468ACE13579BDF024; end
                    10: begin pat_OPA = 72'hFEDCBA9876543210FF; pat_OPB = 72'h0F1E2D3C4B5A697887; end
                    11: begin pat_OPA = 72'h111111111222222222; pat_OPB = 72'h333333333444444444; end
                    12: begin pat_OPA = 72'h7FFFFFFFF800000000; pat_OPB = 72'h800000000FFFFFFFFF; end // sign boundaries
                    13: begin pat_OPA = 72'h0AAAAAAAAB55555555; pat_OPB = 72'h0F0F0F0F0F0F0F0F0F; end
                    14: begin pat_OPA = 72'h003FFFC00FFC003FF0; pat_OPB = 72'h00C00FF003FFC00FF0; end // mid bits
                    15: begin pat_OPA = 72'hABCDEF0123456789AB; pat_OPB = 72'h9876543210FEDCBA98; end
                endcase
                OPA = pat_OPA;
                OPB = pat_OPB;
                repeat (5) @(posedge CLK);

                pat_errors = 0;
                if (RES0[35:0]  !== RES0_gold[35:0])  pat_errors = pat_errors + 1;
                if (RES1[35:0]  !== RES1_gold[35:0])  pat_errors = pat_errors + 1;
                if (RES2[35:0]  !== RES2_gold[35:0])  pat_errors = pat_errors + 1;
                if (RES0[71:36] !== RES0_gold[71:36]) pat_errors = pat_errors + 1;
                if (RES1[71:36] !== RES1_gold[71:36]) pat_errors = pat_errors + 1;
                if (RES2[71:36] !== RES2_gold[71:36]) pat_errors = pat_errors + 1;

                total_bit_errors = total_bit_errors + pat_errors;
                if (pat_errors == 0) begin
                    $display("PATTERN %2d PASS  OPA=0x%h OPB=0x%h", pat, OPA, OPB);
                end else begin
                    total_failed_patterns = total_failed_patterns + 1;
                    have_errors = 1'b1;
                    $display("PATTERN %2d FAIL (%0d mismatches)", pat, pat_errors);
                    $display("           OPA=0x%h OPB=0x%h", OPA, OPB);
                    if (RES0[35:0] !== RES0_gold[35:0])
                        $display("           W_RES0  fab=0x%9h gold=0x%9h  (XOR)",     RES0[35:0],  RES0_gold[35:0]);
                    if (RES1[35:0] !== RES1_gold[35:0])
                        $display("           W_RES1  fab=0x%9h gold=0x%9h  (AND)",     RES1[35:0],  RES1_gold[35:0]);
                    if (RES2[35:0] !== RES2_gold[35:0])
                        $display("           W_RES2  fab=0x%9h gold=0x%9h  (OR^rol1)", RES2[35:0],  RES2_gold[35:0]);
                    if (RES0[71:36] !== RES0_gold[71:36])
                        $display("           E_RES0  fab=0x%9h gold=0x%9h  (ADD)",     RES0[71:36], RES0_gold[71:36]);
                    if (RES1[71:36] !== RES1_gold[71:36])
                        $display("           E_RES1  fab=0x%9h gold=0x%9h  (SUB)",     RES1[71:36], RES1_gold[71:36]);
                    if (RES2[71:36] !== RES2_gold[71:36])
                        $display("           E_RES2  fab=0x%9h gold=0x%9h  (MUL18x18)", RES2[71:36], RES2_gold[71:36]);
                end
            end

            $display("\n=== STRESS SUMMARY ===");
            $display("  Patterns:     %0d/%0d passed (%0d failed)",
                     total_patterns - total_failed_patterns, total_patterns, total_failed_patterns);
            $display("  Bit-checks:   %0d total compares per pattern, %0d total mismatches",
                     6, total_bit_errors);
        end

        // ============================================================
        // Randomized stress phase — 200 random (OPA, OPB) pairs through
        // every CPU_IO BEL row. Catches edge cases the hand-crafted
        // patterns miss (specific bit patterns in arithmetic carry chains
        // and the regfile address space).
        // ============================================================
        begin : rand_stress
            integer rpat;
            integer rand_total = 200;
            integer rand_failed_patterns = 0;
            integer rand_total_bit_errors = 0;
            integer rand_pat_errors;
            // Pre-warmup the regfile by walking all 32 addresses with random data
            // (so the regfile-output bits in W_RES2[35:32] match between fab+gold).
            $display("\n=== RANDOMIZED STRESS (200 patterns) ===");
            for (rpat = 0; rpat < 32; rpat = rpat + 1) begin
                OPA = {$random, $random, $random}; // 96-bit fill, truncated to 72
                OPB = {$random, $random, $random};
                OPB[12:8] = rpat[4:0]; // walk regfile addrs 0..31 in OPB[12:8]
                @(posedge CLK);
                @(posedge CLK);
            end
            // Now run randomized patterns. The regfile state evolves with each
            // pattern's OPA[3:0] write to OPB[12:8]; that's still synced between
            // gold (dut_i) and fabric since both run the same `top` module.
            for (rpat = 0; rpat < rand_total; rpat = rpat + 1) begin
                OPA = {$random, $random, $random};
                OPB = {$random, $random, $random};
                repeat (5) @(posedge CLK);

                rand_pat_errors = 0;
                if (RES0[35:0]  !== RES0_gold[35:0])  rand_pat_errors = rand_pat_errors + 1;
                if (RES1[35:0]  !== RES1_gold[35:0])  rand_pat_errors = rand_pat_errors + 1;
                if (RES2[35:0]  !== RES2_gold[35:0])  rand_pat_errors = rand_pat_errors + 1;
                if (RES0[71:36] !== RES0_gold[71:36]) rand_pat_errors = rand_pat_errors + 1;
                if (RES1[71:36] !== RES1_gold[71:36]) rand_pat_errors = rand_pat_errors + 1;
                if (RES2[71:36] !== RES2_gold[71:36]) rand_pat_errors = rand_pat_errors + 1;

                rand_total_bit_errors = rand_total_bit_errors + rand_pat_errors;
                if (rand_pat_errors != 0) begin
                    rand_failed_patterns = rand_failed_patterns + 1;
                    have_errors = 1'b1;
                    if (rand_failed_patterns <= 3) begin
                        $display("RAND PATTERN %0d FAIL (%0d mismatches) OPA=0x%h OPB=0x%h",
                                 rpat, rand_pat_errors, OPA, OPB);
                    end
                end
            end
            $display("=== RANDOMIZED STRESS SUMMARY ===");
            $display("  Patterns:     %0d/%0d passed (%0d failed)",
                     rand_total - rand_failed_patterns, rand_total, rand_failed_patterns);
            $display("  Total bit mismatches: %0d", rand_total_bit_errors);
        end

        if (have_errors)
            $fatal;
        else
            $finish;
    end

endmodule
