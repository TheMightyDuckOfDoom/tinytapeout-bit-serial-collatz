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

    input wire shift_up_i,
    input wire shift_enable_i,
    input wire data_i,

    input wire parallel_load_i,
    input wire [Width-1:0] parallel_data_i,

    output wire data_o,
    output wire [Width-1:0] parallel_data_o
);

  wire clk_en;

  reg  [Width-1:0] data_q, data_d;

  // Shift the register to the right and insert new data at the leftmost bit
  always @(*) begin
    if (shift_up_i) begin
      data_d[Width-2:0] = data_q[Width-1:1];
      data_d[Width-1]   = data_i;
    end
    else begin
      data_d[0] = data_i;
      data_d[Width-1:1] = data_q[Width-2:0];
    end
  end

  assign clk_en = clk_i;

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
    else if (shift_enable_i) data_q <= data_d;
    else if (parallel_load_i) data_q <= parallel_data_i;
    // else data_q <= data_d;
  end

  assign data_o          = data_q[Width-1];
  assign parallel_data_o = data_q;
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

  assign uo_out[7:2] = 0;

  assign uio_out = 0;
  assign uio_oe  = 0;

  localparam MainRegWidth = 144;
  localparam StepCounterWidth = 16;
  localparam CounterWidth = $clog2(MainRegWidth);
  localparam StateIdle = 0;
  localparam StateOdd = 1;
  localparam StateCheck = 2; // Check and even state
    
  // Finished flag
  reg finished_q, finished_d;

  // Data into the main register
  reg sr_data_in, sr_data_out;

  // Shift enable for the main register
  reg sr_enable, sr_shift_up;

  // Step counter
  reg step_shift_enable, step_parallel_load;
  reg [StepCounterWidth-1:0] steps_d, steps_q;

  // Carry bit for the addition in the odd case
  reg carry_q, carry_d;

  // Bit counter to keep track of how many bits have been processed
  reg [CounterWidth-1:0] bit_counter_q, bit_counter_d;

  // Current state: idle, processing even, or processing odd
  reg [1:0] state_q, state_d;

  reg [1:0] one_count_q, one_count_d;

  // State machine combinational logic
  always @(*) begin
    // Default: do nothing
    state_d       = state_q;
    carry_d       = carry_q;
    bit_counter_d = bit_counter_q;
    steps_d       = steps_q;
    one_count_d   = one_count_q;
    finished_d    = finished_q;
    
    // Idle state: can shift data externally
    sr_data_in = ui_in[0];
    sr_enable  = ui_in[1];

    step_shift_enable  = 1'b0;
    step_parallel_load = 1'b0;

    sr_shift_up = 1'b0;

    case(state_q)
    // Idle State: Start processing when ui_in[2] is high
    StateIdle: begin
      // Can read out the current value of the step counter in idle state
      step_shift_enable = ui_in[2];

      // Start processing when ui_in[3] is high
      if (ui_in[3]) begin
        // Reset step counter
        step_parallel_load = 1'b1;
        steps_d = 'd0;

        // Reset finished flag
        finished_d = 1'b0;

        // Reset bit counter when starting a new number
        bit_counter_d = 'd0;
        one_count_d = 'd0;

        // Go into check state
        state_d = StateCheck;
      end
    end
    // Check all bits and count the number of ones
    StateCheck: begin
      if (bit_counter_q < MainRegWidth) begin
        // Shift the main register to get the next bit
        sr_enable = 1'b1;
        sr_data_in = sr_data_out; // Shift in the current output bit to keep the value stable

        // Count the number of ones in the current number
        if (sr_data_out) begin
          // Saturating count
          if (one_count_q < 'd3) one_count_d = one_count_q + 2'd1;
        end

        // Increment bit counter
        bit_counter_d = bit_counter_q + 'd1;
      end else begin
        // All bits have been processed, determine if we are even or odd
        if ((one_count_q <= 2'd1)) begin
          // Number is 0 or exactly one '1' bit -> finished
          state_d = StateIdle;
          finished_d = 1'b1;
        end else begin
          // Increment step counter
          step_parallel_load = 1'b1;
          steps_d            = steps_q + 'd1;

          // Continue processing:
          if (sr_data_out) begin
            // Odd case -> go into odd state to perform 3n+1
            bit_counter_d = 'd0;
            carry_d = 1'b1; // Start with carry for the +1 in 3n+1 

            // Shift up once for the multiplication by 2 in 3n+1
            sr_shift_up = 1'b1;
            sr_data_in  = 1'b0;
            state_d = StateOdd;
          end else begin
            // Even case: divide by 2 -> shift once and check again
            sr_enable  = 1'b1;
            sr_data_in = 1'b0;

            // Go back to check state
            state_d = StateCheck;
            bit_counter_d = 'd0;
            one_count_d = 'd0;
          end
        end
      end
    end
    StateOdd: begin
      if (bit_counter_q < MainRegWidth) begin
        // Shift the main register
        sr_enable = 1'b1;

        sr_data_in = sr_data_out ^ carry_q; // Add carry for the +1 in 3n+1
        carry_d    = sr_data_out & carry_q; // Update carry for the next bit

        // Increment bit counter
        bit_counter_d = bit_counter_q + 'd1;
      end else begin
        // Finished processing odd case -> go back to check state to determine if we are finished or need to continue
        state_d = StateCheck;
        bit_counter_d = 'd0;
        one_count_d = 'd0;
      end
    end
    endcase
  end

  assign uo_out[0] = sr_data_out;

  // Main shift register to hold the current value of n
  shift_register #(
    .Width( MainRegWidth )
  ) i_main_reg (
    .clk_i ( clk   ),
    .rst_ni( rst_n ),

    .shift_up_i    ( sr_shift_up ),
    .shift_enable_i( sr_enable   ),
    .data_i        ( sr_data_in  ),

    .parallel_load_i( 1'b0 ),
    .parallel_data_i( 'd0  ),

    .data_o( sr_data_out ),
    .parallel_data_o( /* unused */ )
  );

  // Step counter shift register (for counting the number of steps taken)
  shift_register #(
    .Width( StepCounterWidth )
  ) i_step_counter (
    .clk_i ( clk   ),
    .rst_ni( rst_n ),

    .shift_up_i    ( 1'b0               ), // Always shift down for counting
    .shift_enable_i( step_shift_enable  ),
    .data_i        ( 1'b0               ),

    .parallel_load_i( step_parallel_load ),
    .parallel_data_i( steps_d ),

    .parallel_data_o( steps_q   ),
    .data_o         ( uo_out[1] )
  );

  // Sequential Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= StateIdle;
      carry_q       <= 'd0;
      bit_counter_q <= 'd0;
      one_count_q   <= 'd0;
      finished_q    <= 1'b0;
    end else begin
      state_q       <= state_d;
      carry_q       <= carry_d;
      bit_counter_q <= bit_counter_d;
      one_count_q   <= one_count_d;
      finished_q    <= finished_d;
    end
  end

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
