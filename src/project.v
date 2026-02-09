/*
 * Copyright (c) 2026 Tobias Senti
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module shift_register #(
    parameter Width = 8
) (
    input wire clk_i,
    input wire rst_ni,

    input  wire enable_i,
    input  wire data_i,
    output wire data_o
);

  wire clk_en;

  wire [Width-1:0] data_d;
  reg  [Width-1:0] data_q;

  // Shift the register to the right and insert new data at the leftmost bit
  assign data_d[0] = data_i;
  assign data_d[Width-1:1] = data_q[Width-2:0];

  // Clock Gate to save area
  // `ifndef RTL_TEST
  //   sg13g2_lgcp_1 i_clk_gate (
  //     .CLK ( clk_i    ),
  //     .GATE( enable_i ),
  //     .GCLK( clk_en   )
  //   );
  // `else
  //   assign clk_en = enable_i ? clk_i : 1'b0;
  // `endif

  always @(posedge clk_en or negedge rst_ni) begin
    if (!rst_ni) data_q <= 0;
    else if (enable_i) data_q <= data_d;
    // else data_q <= data_d;
  end

  assign data_o = data_q[Width-1];
endmodule

module tt_um_themightyduckofdoom_bitserial_collatz_checker (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  assign uo_out[7:1] = 0;

  assign uio_out = 0;
  assign uio_oe  = 0;

  localparam MainRegWidth = 144;

  shift_register #(
    .Width( MainRegWidth )
  ) i_main_reg (
    .clk_i ( clk   ),
    .rst_ni( rst_n ),

    .enable_i( ui_in [0] ),
    .data_i  ( ui_in [1] ),
    .data_o  ( uo_out[0] )
  );

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
