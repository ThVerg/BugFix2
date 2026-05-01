module top(input wire clk, input wire [35:0] W_OPA, W_OPB, E_OPA, E_OPB, output wire [35:0] W_RES0, W_RES1, W_RES2, E_RES0, E_RES1, E_RES2);
	
    assign W_RES0 = W_OPA ^ W_OPB; //A xor B bitwise;
    assign W_RES1 = W_OPA & W_OPB; //A and B bitwise
    assign W_RES2 = W_OPA | W_OPB; //A or B bitwise
    
    assign E_RES0 = E_OPA + E_OPB;
    assign E_RES1 = E_OPA - E_OPB;
    assign E_RES2 = 32'hDEADBEEF;

endmodule

/*
module top(input wire clk, input wire [9:0] io_in, output wire [9:0] io_out, io_oeb);
    wire rst = io_in[0];
    wire en = io_in[1];
    reg [15:0] ctr;

    always @(posedge clk)
        if (en)
            if (rst)
                ctr <= 0;
            else
                ctr <= ctr + 1'b1;
        else
            ctr <= ctr;

    // assign io_out =  ctr[15:8];
    assign io_out =  ctr[9:0];
    assign io_oeb = 10'h1;
endmodule
*/