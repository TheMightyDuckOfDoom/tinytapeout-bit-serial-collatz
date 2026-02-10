/*
 * Copyright (c) 2026 Tobias Senti
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/// Shift register with parallel load and output
// Used for the main register and the step counter
module shift_register #(
    parameter integer Width = 8
) (
    input wire clk_i,
    input wire rst_ni,

    input wire shift_enable_i,
    input wire data_i,

    input wire parallel_load_i,
    input wire [Width-1:0] parallel_data_i,

    output wire data_o,
    output wire [Width-1:0] parallel_data_o
);
  wire [Width-1:0] data_d;
  reg  [Width-1:0] data_q;

  // Shift the register to the right and insert new data at the leftmost bit
  assign data_d[Width-1] = data_i;
  assign data_d[Width-2:0] = data_q[Width-1:1];

  `ifndef DISABLE_CLOCK_GATING
    // verilator lint_off MODMISSING
    wire clk_en;
    wire comb_enable = shift_enable_i | parallel_load_i;

    // Clock Gate to save area
    sg13g2_lgcp_1 i_clk_gate (
      .CLK ( clk_i       ),
      .GATE( comb_enable ),
      .GCLK( clk_en      )
    );

    // Here we should use a scan flip-flop
    for (genvar i = 0; i < Width; i++) begin
      sg13g2_sdfrbpq_1 i_ff (
        .D  ( parallel_data_i[i] ),
        .SCD( data_d[i]          ),
        .SCE( shift_enable_i     ),
        .CLK( clk_en             ),
        .Q  ( data_q[i]          )
      );
    end
    // verilator lint_on MODMISSING
  `else
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) data_q <= 0;
      else if (shift_enable_i) data_q <= data_d;
      else if (parallel_load_i) data_q <= parallel_data_i;
    end
  `endif

  assign data_o          = data_q[0];
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

  // Parameters for the design, affect resource usage and maximum input size
  localparam integer MainRegWidth = 448;
  localparam integer StepCounterWidth = 16;

  // Bit position counter
  localparam integer CounterWidth = $clog2(MainRegWidth) + 1;

  // State machine states
  localparam reg [1:0] StateIdle = 0;
  localparam reg [1:0] StateOdd = 1;
  localparam reg [1:0] StateCheck = 2; // Check and even state

  // Finished flag
  reg finished_q, finished_d;

  // Overflow flag
  reg overflow_q, overflow_d;

  // Data into the main register
  reg sr_data_in, sr_data_out;

  // Shift enable for the main register
  reg sr_enable;

  // Step counter
  reg step_shift_enable, step_parallel_load;
  reg [StepCounterWidth-1:0] steps_d, steps_q;

  // Carry bit for the addition in the odd case
  reg carry_q, carry_d, previous_bit_q, previous_bit_d;

  // Bit counter to keep track of how many bits have been processed
  reg [CounterWidth-1:0] bit_counter_q, bit_counter_d;

  // Current state: idle, processing even, or processing odd
  reg [1:0] state_q, state_d;

  reg [1:0] one_count_q, one_count_d;

  // State machine combinational logic
  always @(*) begin
    // Default: do nothing
    state_d        = state_q;
    carry_d        = carry_q;
    previous_bit_d = previous_bit_q;
    bit_counter_d  = bit_counter_q;
    steps_d        = steps_q;
    one_count_d    = one_count_q;
    finished_d     = finished_q;
    overflow_d     = overflow_q;

    // Idle state: can shift data externally
    sr_data_in = ui_in[0];
    sr_enable  = ui_in[1];

    // Keep step counter stable
    step_shift_enable  = 1'b0;
    step_parallel_load = 1'b0;

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

        // Reset finished and overflow flag
        finished_d = 1'b0;
        overflow_d = 1'b0;

        // Reset bit counter when starting a new number
        bit_counter_d = 'd0;
        one_count_d = 'd0;

        // Go into check state
        state_d = StateCheck;
      end
    end
    // Check all bits and count the number of ones
    StateCheck: begin
      if (bit_counter_q < MainRegWidth[CounterWidth-1:0]) begin
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
        if (((one_count_q == 2'd1) && (sr_data_out)) || one_count_q == 2'd0) begin
          // Exactly one '1' bit and the lsb is 1 -> main register is 1 -> we are finished
          // Or number of ones is 0 -> main register is 0 -> we are finished
          state_d = StateIdle;
          finished_d = 1'b1;
        end else begin
          // Increment step counter
          step_parallel_load = 1'b1;
          steps_d            = steps_q + 'd1;
          if (steps_d == '0) overflow_d = 1'b1; // Check for overflow

          // Continue processing:
          if (sr_data_out) begin
            // Odd case -> go into odd state to perform 3n+1
            bit_counter_d = 'd0;
            carry_d = 1'b1; // Start with carry for the +1 in 3n+1
            previous_bit_d = 1'b0; // Previous bit for the n << 1 part of 3n+1

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
      if (bit_counter_q < MainRegWidth[CounterWidth-1:0]) begin
        // Shift the main register
        sr_enable = 1'b1;

        sr_data_in     = sr_data_out ^ carry_q ^ previous_bit_q;
        carry_d        = (sr_data_out & previous_bit_q)
          | (carry_q & (sr_data_out ^ previous_bit_q));
        previous_bit_d = sr_data_out;

        // Check for overflow: if we have a carry out of the most significant bit, we have an overflow
        if ((bit_counter_q == (MainRegWidth[CounterWidth-1:0] - 'd1)) && carry_d) begin
          overflow_d = 1'b1; // sticky bit
        end

        // Increment bit counter
        bit_counter_d = bit_counter_q + 'd1;
      end else begin
        // Finished processing odd case -> go back to check state to determine if we are finished or need to continue
        state_d = StateCheck;
        bit_counter_d = 'd0;
        one_count_d = 'd0;
      end
    end
    default: state_d = StateIdle;
    endcase
  end

  assign uo_out[0] = sr_data_out;
  assign uo_out[2] = finished_q;
  assign uo_out[3] = overflow_q;

  // Main shift register to hold the current value of n
  shift_register #(
    .Width( MainRegWidth )
  ) i_main_reg (
    .clk_i ( clk   ),
    .rst_ni( rst_n ),

    .shift_enable_i( sr_enable  ),
    .data_i        ( sr_data_in ),

    .parallel_load_i( 1'b0 ),
    .parallel_data_i( '0   ),

    .data_o( sr_data_out ),

    /* verilator lint_off PINCONNECTEMPTY */
    .parallel_data_o( /* unused */ )
      /* verilator lint_on PINCONNECTEMPTY */
  );

  // Step counter shift register (for counting the number of steps taken)
  shift_register #(
    .Width( StepCounterWidth )
  ) i_step_counter (
    .clk_i ( clk   ),
    .rst_ni( rst_n ),

    .shift_enable_i( step_shift_enable ),
    .data_i        ( 1'b0              ),

    .parallel_load_i( step_parallel_load ),
    .parallel_data_i( steps_d ),

    .parallel_data_o( steps_q   ),
    .data_o         ( uo_out[1] )
  );

  // Sequential Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q        <= StateIdle;
      carry_q        <= 'd0;
      previous_bit_q <= 1'b0;
      bit_counter_q  <= 'd0;
      one_count_q    <= 'd0;
      finished_q     <= 1'b0;
      overflow_q     <= 1'b0;
    end else begin
      state_q        <= state_d;
      carry_q        <= carry_d;
      previous_bit_q <= previous_bit_d;
      bit_counter_q  <= bit_counter_d;
      one_count_q    <= one_count_d;
      finished_q     <= finished_d;
      overflow_q     <= overflow_d;
    end
  end

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

  assign uo_out[7:4] = 0;
  assign uio_out = 0;
  assign uio_oe  = 0;

endmodule
