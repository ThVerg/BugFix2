module top(
    input wire clk,
    input wire [35:0] W_OPA, W_OPB, E_OPA, E_OPB,
    input wire [9:0] io_in,
    output wire [35:0] W_RES0, W_RES1, W_RES2, E_RES0, E_RES1, E_RES2,
    output wire [9:0] io_out, io_oeb
);

    assign W_RES0 = W_OPA ^ W_OPB; //A xor B bitwise;
    assign W_RES1 = W_OPA & W_OPB; //A and B bitwise
    assign W_RES2 = W_OPA | W_OPB; //A or B bitwise

    assign E_RES0 = E_OPA + E_OPB;
    assign E_RES1 = E_OPA - E_OPB;
    assign E_RES2 = 32'hDEADBEEF;


    wire rst = io_in[0];
    wire en = io_in[1];
    reg [31:0] ctr;

    always @(posedge clk)
        if (en)
            if (rst)
                ctr <= 0;
            else
                ctr <= ctr + 1'b1;
        else
            ctr <= ctr;

    // NOTE: choose this depending if you're running a simulation or on an
    // actual chip
  
    // assign io_out[9:2] =  ctr[25:18];
    assign io_out[9:2] =  ctr[7:0];

    assign io_oeb = 10'b11_1111_1100;

    // Avoid mismatches in the simulation
    assign io_out[1:0] = 2'h0;

endmodule
