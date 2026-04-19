`timescale 1ns / 1ps

// ============================================================
//  line_buffer.v
//  3-row line buffer and 3x3 sliding window generator
//
//  Project : FPGA-Accelerated Image Processing Pipeline
//  Board   : PYNQ Z2 (Xilinx Zynq XC7Z020)
//  Tool    : Vivado 2022.x / XSim
//
//  Description:
//    Accepts a stream of grayscale pixels row by row.
//    Stores pixel history in two line buffers (Vivado will
//    infer these as BRAMs during synthesis).
//    Once 2 complete rows are buffered, outputs a valid
//    3x3 neighbourhood window every clock cycle at
//    1 pixel/clock throughput.
//
//  Window layout (p_row_col):
//    p00  p01  p02   <- oldest row (top)
//    p10  p11  p12   <- middle row
//    p20  p21  p22   <- newest row (bottom)
//
//  Latency  : 1 clock cycle (registered outputs)
//  Throughput: 1 pixel/clock when pixel_valid = 1
// ============================================================
 
module line_buffer #(
    parameter DATA_WIDTH  = 8,    // Pixel bit-width (8-bit grayscale)
    parameter IMAGE_WIDTH = 320   // Number of pixels per row
)(
    input  wire                   clk,          // System clock
    input  wire                   rst_n,        // Active-low synchronous reset
    input  wire                   pixel_valid,  // High when pixel_in is valid
    input  wire [DATA_WIDTH-1:0]  pixel_in,     // Incoming pixel value
 
    // --- 3x3 window outputs ---
    output reg  [DATA_WIDTH-1:0]  p00, p01, p02,  // Top row
    output reg  [DATA_WIDTH-1:0]  p10, p11, p12,  // Middle row
    output reg  [DATA_WIDTH-1:0]  p20, p21, p22,  // Bottom row
 
    output reg                    window_valid     // High when window is valid
);
 
    // -----------------------------------------------------------------
    //  Local parameters
    // -----------------------------------------------------------------
    localparam COL_BITS = $clog2(IMAGE_WIDTH);
 
    // -----------------------------------------------------------------
    //  Line buffers
    //  buf0 : pixel data from 2 rows ago  (top row of window)
    //  buf1 : pixel data from 1 row ago   (middle row of window)
    //  Vivado synthesises these as Block RAMs (18K BRAM primitives).
    // -----------------------------------------------------------------
    reg [DATA_WIDTH-1:0] buf0 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] buf1 [0:IMAGE_WIDTH-1];
 
    // -----------------------------------------------------------------
    //  Position tracking
    // -----------------------------------------------------------------
    reg [COL_BITS-1:0] col_cnt;      // Current column index
    reg [1:0]          rows_filled;  // Number of completed rows (caps at 2)
 
    // -----------------------------------------------------------------
    //  Column shift registers - 2-deep history per row
    //  sr_X_1 : pixel from 1 column back
    //  sr_X_2 : pixel from 2 columns back
    // -----------------------------------------------------------------
    reg [DATA_WIDTH-1:0] sr0_1, sr0_2;  // History for buf0 output
    reg [DATA_WIDTH-1:0] sr1_1, sr1_2;  // History for buf1 output
    reg [DATA_WIDTH-1:0] sr2_1, sr2_2;  // History for pixel_in
 
    // -----------------------------------------------------------------
    //  Combinatorial buffer reads
    //  (Vivado treats these as distributed RAM read ports in simulation)
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] buf0_rd = buf0[col_cnt];
    wire [DATA_WIDTH-1:0] buf1_rd = buf1[col_cnt];
 
    // -----------------------------------------------------------------
    //  Main pipeline - single always block
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            // --- Synchronous reset ---
            col_cnt      <= {COL_BITS{1'b0}};
            rows_filled  <= 2'b00;
            window_valid <= 1'b0;
            sr0_1 <= 0;  sr0_2 <= 0;
            sr1_1 <= 0;  sr1_2 <= 0;
            sr2_1 <= 0;  sr2_2 <= 0;
            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;
 
        end else if (pixel_valid) begin
 
            // -------------------------------------------------------
            //  Stage 1 : Update line buffers
            //  Shift pipeline: buf0 <- buf1 <- pixel_in
            //  (All RHS values captured before any update - NBA rule)
            // -------------------------------------------------------
            buf0[col_cnt] <= buf1_rd;    // Oldest row takes previous middle
            buf1[col_cnt] <= pixel_in;   // Middle row takes new pixel
 
            // -------------------------------------------------------
            //  Stage 2 : Shift column history registers
            // -------------------------------------------------------
            sr0_2 <= sr0_1;  sr0_1 <= buf0_rd;   // Oldest row history
            sr1_2 <= sr1_1;  sr1_1 <= buf1_rd;   // Middle row history
            sr2_2 <= sr2_1;  sr2_1 <= pixel_in;  // Newest row history
 
            // -------------------------------------------------------
            //  Stage 3 : Latch 3x3 window outputs
            //  All RHS are the PRE-update values (NBA semantics).
            //  Correct window for current col_cnt:
            //    col-2  = sr_2  (2 clocks ago)
            //    col-1  = sr_1  (1 clock ago)
            //    col    = buf_rd / pixel_in (current)
            // -------------------------------------------------------
            p00 <= sr0_2;   p01 <= sr0_1;   p02 <= buf0_rd;
            p10 <= sr1_2;   p11 <= sr1_1;   p12 <= buf1_rd;
            p20 <= sr2_2;   p21 <= sr2_1;   p22 <= pixel_in;
 
            // -------------------------------------------------------
            //  Stage 4 : Update column counter and row fill tracker
            // -------------------------------------------------------
            if (col_cnt == IMAGE_WIDTH - 1) begin
                col_cnt <= {COL_BITS{1'b0}};
                if (rows_filled < 2'b10)
                    rows_filled <= rows_filled + 1'b1;
            end else begin
                col_cnt <= col_cnt + 1'b1;
            end
 
            // -------------------------------------------------------
            //  Stage 5 : Window valid flag
            //  Conditions:
            //    - At least 2 complete rows received (rows_filled == 2)
            //    - At least 3 pixels into the current row (col_cnt >= 2)
            //      so the 2-deep shift registers are fully loaded
            // -------------------------------------------------------
            window_valid <= (rows_filled == 2'b10) && (col_cnt >= {{(COL_BITS-2){1'b0}}, 2'd2});
 
        end else begin
            // Deassert valid when no pixel is arriving (backpressure)
            window_valid <= 1'b0;
        end
    end
 
endmodule
