 // NumberOfConfigBits: 0
module E_CPU_IO_bot_switch_matrix
    (
        input  N1END0,
        input  N1END1,
        input  N1END2,
        input  N1END3,
        input  N2MID0,
        input  N2MID1,
        input  N2MID2,
        input  N2MID3,
        input  N2MID4,
        input  N2MID5,
        input  N2MID6,
        input  N2MID7,
        input  N2END0,
        input  N2END1,
        input  N2END2,
        input  N2END3,
        input  N2END4,
        input  N2END5,
        input  N2END6,
        input  N2END7,
        input  N4END0,
        input  N4END1,
        input  N4END2,
        input  N4END3,
        input  N4END4,
        input  N4END5,
        input  N4END6,
        input  N4END7,
        input  N4END8,
        input  N4END9,
        input  N4END10,
        input  N4END11,
        input  N4END12,
        input  N4END13,
        input  N4END14,
        input  N4END15,
        input  NN4END0,
        input  NN4END1,
        input  NN4END2,
        input  NN4END3,
        input  NN4END4,
        input  NN4END5,
        input  NN4END6,
        input  NN4END7,
        input  NN4END8,
        input  NN4END9,
        input  NN4END10,
        input  NN4END11,
        input  NN4END12,
        input  NN4END13,
        input  NN4END14,
        input  NN4END15,
        input  Ci0,
        input  E1END0,
        input  E1END1,
        input  E1END2,
        input  E1END3,
        input  E2MID0,
        input  E2MID1,
        input  E2MID2,
        input  E2MID3,
        input  E2MID4,
        input  E2MID5,
        input  E2MID6,
        input  E2MID7,
        input  E2END0,
        input  E2END1,
        input  E2END2,
        input  E2END3,
        input  E2END4,
        input  E2END5,
        input  E2END6,
        input  E2END7,
        input  EE4END0,
        input  EE4END1,
        input  EE4END2,
        input  EE4END3,
        input  EE4END4,
        input  EE4END5,
        input  EE4END6,
        input  EE4END7,
        input  EE4END8,
        input  EE4END9,
        input  EE4END10,
        input  EE4END11,
        input  EE4END12,
        input  EE4END13,
        input  EE4END14,
        input  EE4END15,
        input  E6END0,
        input  E6END1,
        input  E6END2,
        input  E6END3,
        input  E6END4,
        input  E6END5,
        input  E6END6,
        input  E6END7,
        input  E6END8,
        input  E6END9,
        input  E6END10,
        input  E6END11,
        input  OPA_O0,
        input  OPA_O1,
        input  OPA_O2,
        input  OPA_O3,
        input  OPB_O0,
        input  OPB_O1,
        input  OPB_O2,
        input  OPB_O3,
        output  W1BEG0,
        output  W1BEG1,
        output  W1BEG2,
        output  W1BEG3,
        output  W2BEG0,
        output  W2BEG1,
        output  W2BEG2,
        output  W2BEG3,
        output  W2BEG4,
        output  W2BEG5,
        output  W2BEG6,
        output  W2BEG7,
        output  W2BEGb0,
        output  W2BEGb1,
        output  W2BEGb2,
        output  W2BEGb3,
        output  W2BEGb4,
        output  W2BEGb5,
        output  W2BEGb6,
        output  W2BEGb7,
        output  W6BEG0,
        output  W6BEG1,
        output  W6BEG2,
        output  W6BEG3,
        output  W6BEG4,
        output  W6BEG5,
        output  W6BEG6,
        output  W6BEG7,
        output  W6BEG8,
        output  W6BEG9,
        output  W6BEG10,
        output  W6BEG11,
        output  S1BEG0,
        output  S1BEG1,
        output  S1BEG2,
        output  S1BEG3,
        output  S2BEG0,
        output  S2BEG1,
        output  S2BEG2,
        output  S2BEG3,
        output  S2BEG4,
        output  S2BEG5,
        output  S2BEG6,
        output  S2BEG7,
        output  S2BEGb0,
        output  S2BEGb1,
        output  S2BEGb2,
        output  S2BEGb3,
        output  S2BEGb4,
        output  S2BEGb5,
        output  S2BEGb6,
        output  S2BEGb7,
        output  S4BEG0,
        output  S4BEG1,
        output  S4BEG2,
        output  S4BEG3,
        output  S4BEG4,
        output  S4BEG5,
        output  S4BEG6,
        output  S4BEG7,
        output  S4BEG8,
        output  S4BEG9,
        output  S4BEG10,
        output  S4BEG11,
        output  S4BEG12,
        output  S4BEG13,
        output  S4BEG14,
        output  S4BEG15,
        output  SS4BEG0,
        output  SS4BEG1,
        output  SS4BEG2,
        output  SS4BEG3,
        output  SS4BEG4,
        output  SS4BEG5,
        output  SS4BEG6,
        output  SS4BEG7,
        output  SS4BEG8,
        output  SS4BEG9,
        output  SS4BEG10,
        output  SS4BEG11,
        output  SS4BEG12,
        output  SS4BEG13,
        output  SS4BEG14,
        output  SS4BEG15,
        output  RES0_I0,
        output  RES0_I1,
        output  RES0_I2,
        output  RES0_I3,
        output  RES1_I0,
        output  RES1_I1,
        output  RES1_I2,
        output  RES1_I3,
        output  RES2_I0,
        output  RES2_I1,
        output  RES2_I2,
        output  RES2_I3
 //global
);
parameter GND0 = 1'b0;
parameter GND = 1'b0;
parameter VCC0 = 1'b1;
parameter VCC = 1'b1;
parameter VDD0 = 1'b1;
parameter VDD = 1'b1;

 //The configuration bits (if any) are just a long shift register
 //This shift register is padded to an even number of flops/latches
 //switch matrix multiplexer W1BEG0 MUX-1
assign W1BEG0 = E1END3;

 //switch matrix multiplexer W1BEG1 MUX-1
assign W1BEG1 = E1END2;

 //switch matrix multiplexer W1BEG2 MUX-1
assign W1BEG2 = E1END1;

 //switch matrix multiplexer W1BEG3 MUX-1
assign W1BEG3 = E1END0;

 //switch matrix multiplexer W2BEG0 MUX-1
assign W2BEG0 = OPB_O0;

 //switch matrix multiplexer W2BEG1 MUX-1
assign W2BEG1 = E2MID6;

 //switch matrix multiplexer W2BEG2 MUX-1
assign W2BEG2 = E2MID5;

 //switch matrix multiplexer W2BEG3 MUX-1
assign W2BEG3 = OPB_O1;

 //switch matrix multiplexer W2BEG4 MUX-1
assign W2BEG4 = OPB_O2;

 //switch matrix multiplexer W2BEG5 MUX-1
assign W2BEG5 = E2MID2;

 //switch matrix multiplexer W2BEG6 MUX-1
assign W2BEG6 = E2MID1;

 //switch matrix multiplexer W2BEG7 MUX-1
assign W2BEG7 = OPB_O3;

 //switch matrix multiplexer W2BEGb0 MUX-1
assign W2BEGb0 = OPA_O0;

 //switch matrix multiplexer W2BEGb1 MUX-1
assign W2BEGb1 = E2END6;

 //switch matrix multiplexer W2BEGb2 MUX-1
assign W2BEGb2 = E2END5;

 //switch matrix multiplexer W2BEGb3 MUX-1
assign W2BEGb3 = OPA_O1;

 //switch matrix multiplexer W2BEGb4 MUX-1
assign W2BEGb4 = OPA_O2;

 //switch matrix multiplexer W2BEGb5 MUX-1
assign W2BEGb5 = E2END2;

 //switch matrix multiplexer W2BEGb6 MUX-1
assign W2BEGb6 = E2END1;

 //switch matrix multiplexer W2BEGb7 MUX-1
assign W2BEGb7 = OPA_O3;

 //switch matrix multiplexer W6BEG0 MUX-1
assign W6BEG0 = OPA_O0;

 //switch matrix multiplexer W6BEG1 MUX-1
assign W6BEG1 = OPA_O1;

 //switch matrix multiplexer W6BEG2 MUX-1
assign W6BEG2 = OPB_O0;

 //switch matrix multiplexer W6BEG3 MUX-1
assign W6BEG3 = OPB_O1;

 //switch matrix multiplexer W6BEG4 MUX-1
assign W6BEG4 = GND0;

 //switch matrix multiplexer W6BEG5 MUX-1
assign W6BEG5 = GND0;

 //switch matrix multiplexer W6BEG6 MUX-1
assign W6BEG6 = OPA_O2;

 //switch matrix multiplexer W6BEG7 MUX-1
assign W6BEG7 = OPA_O3;

 //switch matrix multiplexer W6BEG8 MUX-1
assign W6BEG8 = OPB_O2;

 //switch matrix multiplexer W6BEG9 MUX-1
assign W6BEG9 = OPB_O3;

 //switch matrix multiplexer W6BEG10 MUX-1
assign W6BEG10 = GND0;

 //switch matrix multiplexer W6BEG11 MUX-1
assign W6BEG11 = GND0;

 //switch matrix multiplexer S1BEG0 MUX-1
assign S1BEG0 = N1END3;

 //switch matrix multiplexer S1BEG1 MUX-1
assign S1BEG1 = N1END2;

 //switch matrix multiplexer S1BEG2 MUX-1
assign S1BEG2 = N1END1;

 //switch matrix multiplexer S1BEG3 MUX-1
assign S1BEG3 = N1END0;

 //switch matrix multiplexer S2BEG0 MUX-1
assign S2BEG0 = N2MID7;

 //switch matrix multiplexer S2BEG1 MUX-1
assign S2BEG1 = N2MID6;

 //switch matrix multiplexer S2BEG2 MUX-1
assign S2BEG2 = N2MID5;

 //switch matrix multiplexer S2BEG3 MUX-1
assign S2BEG3 = N2MID4;

 //switch matrix multiplexer S2BEG4 MUX-1
assign S2BEG4 = N2MID3;

 //switch matrix multiplexer S2BEG5 MUX-1
assign S2BEG5 = N2MID2;

 //switch matrix multiplexer S2BEG6 MUX-1
assign S2BEG6 = N2MID1;

 //switch matrix multiplexer S2BEG7 MUX-1
assign S2BEG7 = N2MID0;

 //switch matrix multiplexer S2BEGb0 MUX-1
assign S2BEGb0 = N2END7;

 //switch matrix multiplexer S2BEGb1 MUX-1
assign S2BEGb1 = N2END6;

 //switch matrix multiplexer S2BEGb2 MUX-1
assign S2BEGb2 = N2END5;

 //switch matrix multiplexer S2BEGb3 MUX-1
assign S2BEGb3 = N2END4;

 //switch matrix multiplexer S2BEGb4 MUX-1
assign S2BEGb4 = N2END3;

 //switch matrix multiplexer S2BEGb5 MUX-1
assign S2BEGb5 = N2END2;

 //switch matrix multiplexer S2BEGb6 MUX-1
assign S2BEGb6 = N2END1;

 //switch matrix multiplexer S2BEGb7 MUX-1
assign S2BEGb7 = N2END0;

 //switch matrix multiplexer S4BEG0 MUX-1
assign S4BEG0 = N4END15;

 //switch matrix multiplexer S4BEG1 MUX-1
assign S4BEG1 = N4END14;

 //switch matrix multiplexer S4BEG2 MUX-1
assign S4BEG2 = N4END13;

 //switch matrix multiplexer S4BEG3 MUX-1
assign S4BEG3 = N4END12;

 //switch matrix multiplexer S4BEG4 MUX-1
assign S4BEG4 = N4END11;

 //switch matrix multiplexer S4BEG5 MUX-1
assign S4BEG5 = N4END10;

 //switch matrix multiplexer S4BEG6 MUX-1
assign S4BEG6 = N4END9;

 //switch matrix multiplexer S4BEG7 MUX-1
assign S4BEG7 = N4END8;

 //switch matrix multiplexer S4BEG8 MUX-1
assign S4BEG8 = N4END7;

 //switch matrix multiplexer S4BEG9 MUX-1
assign S4BEG9 = N4END6;

 //switch matrix multiplexer S4BEG10 MUX-1
assign S4BEG10 = N4END5;

 //switch matrix multiplexer S4BEG11 MUX-1
assign S4BEG11 = N4END4;

 //switch matrix multiplexer S4BEG12 MUX-1
assign S4BEG12 = N4END3;

 //switch matrix multiplexer S4BEG13 MUX-1
assign S4BEG13 = N4END2;

 //switch matrix multiplexer S4BEG14 MUX-1
assign S4BEG14 = N4END1;

 //switch matrix multiplexer S4BEG15 MUX-1
assign S4BEG15 = N4END0;

 //switch matrix multiplexer SS4BEG0 MUX-1
assign SS4BEG0 = NN4END15;

 //switch matrix multiplexer SS4BEG1 MUX-1
assign SS4BEG1 = NN4END14;

 //switch matrix multiplexer SS4BEG2 MUX-1
assign SS4BEG2 = NN4END13;

 //switch matrix multiplexer SS4BEG3 MUX-1
assign SS4BEG3 = NN4END12;

 //switch matrix multiplexer SS4BEG4 MUX-1
assign SS4BEG4 = NN4END11;

 //switch matrix multiplexer SS4BEG5 MUX-1
assign SS4BEG5 = NN4END10;

 //switch matrix multiplexer SS4BEG6 MUX-1
assign SS4BEG6 = NN4END9;

 //switch matrix multiplexer SS4BEG7 MUX-1
assign SS4BEG7 = NN4END8;

 //switch matrix multiplexer SS4BEG8 MUX-1
assign SS4BEG8 = NN4END7;

 //switch matrix multiplexer SS4BEG9 MUX-1
assign SS4BEG9 = NN4END6;

 //switch matrix multiplexer SS4BEG10 MUX-1
assign SS4BEG10 = NN4END5;

 //switch matrix multiplexer SS4BEG11 MUX-1
assign SS4BEG11 = NN4END4;

 //switch matrix multiplexer SS4BEG12 MUX-1
assign SS4BEG12 = NN4END3;

 //switch matrix multiplexer SS4BEG13 MUX-1
assign SS4BEG13 = NN4END2;

 //switch matrix multiplexer SS4BEG14 MUX-1
assign SS4BEG14 = NN4END1;

 //switch matrix multiplexer SS4BEG15 MUX-1
assign SS4BEG15 = NN4END0;

 //switch matrix multiplexer RES0_I0 MUX-1
assign RES0_I0 = E6END0;

 //switch matrix multiplexer RES0_I1 MUX-1
assign RES0_I1 = E6END1;

 //switch matrix multiplexer RES0_I2 MUX-1
assign RES0_I2 = E6END2;

 //switch matrix multiplexer RES0_I3 MUX-1
assign RES0_I3 = E6END3;

 //switch matrix multiplexer RES1_I0 MUX-1
assign RES1_I0 = E6END4;

 //switch matrix multiplexer RES1_I1 MUX-1
assign RES1_I1 = E6END5;

 //switch matrix multiplexer RES1_I2 MUX-1
assign RES1_I2 = E6END6;

 //switch matrix multiplexer RES1_I3 MUX-1
assign RES1_I3 = E6END7;

 //switch matrix multiplexer RES2_I0 MUX-1
assign RES2_I0 = E6END8;

 //switch matrix multiplexer RES2_I1 MUX-1
assign RES2_I1 = E6END9;

 //switch matrix multiplexer RES2_I2 MUX-1
assign RES2_I2 = E6END10;

 //switch matrix multiplexer RES2_I3 MUX-1
assign RES2_I3 = E6END11;

endmodule