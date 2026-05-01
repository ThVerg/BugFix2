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

        //repeat (20) @(posedge CLK);
        //#2500;
        //write bitstream to SelfWriteData
        //write bitstream to Rx (UART config port)
        for (j = 0; j < MAX_BITBYTES; j = j + 1) begin
            //send_byte(bitstream[j], Rx);
            Rx = 1'b0;
            #BIT_PERIOD_CONFIG;
            for (i = 0; i < 8; i = i + 1) begin
                Rx = bitstream[j][i];
                dummy_signal_debug = ~dummy_signal_debug;
                #BIT_PERIOD_CONFIG;
            end
            Rx = 1'b1;
            #BIT_PERIOD_CONFIG;
        end
        

`endif
        repeat (100) @(posedge CLK);
        reset = 1'b1; //reset to start the core
        repeat (100) @(posedge CLK);
        reset = 1'b0;
        repeat (100) @(posedge CLK);
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

        #100000;

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
