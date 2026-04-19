// ============================================================
//  gaussian_filter.v
//  3x3 Gaussian blur filter
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2 / XSim
//
//  What it does:
//    Takes the 3x3 pixel window from line_buffer and applies
//    a Gaussian blur using integer approximation of the kernel:
//
//      [ 1  2  1 ]
//      [ 2  4  2 ]  divided by 16 (right shift by 4)
//      [ 1  2  1 ]
//
//    This smooths out noise before edge detection.
//    Output is a single blurred pixel every clock cycle.
//
//  Latency    : 1 clock cycle (registered output)
//  Throughput : 1 pixel/clock
// ============================================================
 
module gaussian_filter #(
    parameter DATA_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    window_valid,   // from line_buffer
 
    // 3x3 window inputs (from line_buffer)
    input  wire [DATA_WIDTH-1:0]   p00, p01, p02,
    input  wire [DATA_WIDTH-1:0]   p10, p11, p12,
    input  wire [DATA_WIDTH-1:0]   p20, p21, p22,
 
    output reg  [DATA_WIDTH-1:0]   blurred_pixel,  // smoothed output
    output reg                     pixel_valid      // high when output is valid
);
 
    // -----------------------------------------------------------------
    //  Gaussian kernel weights:
    //    corners = 1, edges = 2, center = 4
    //    Total sum = 16, so we divide by 16 (>> 4)
    //
    //  We use 12-bit accumulator to avoid overflow before the divide.
    //  Max value: 255 * (1+2+1+2+4+2+1+2+1) = 255 * 16 = 4080 → fits in 12 bits
    // -----------------------------------------------------------------
    wire [11:0] weighted_sum;
 
    assign weighted_sum =
        ( p00 + (p01 << 1) + p02          // row 0: 1*p00 + 2*p01 + 1*p02
        + (p10 << 1) + (p11 << 2) + (p12 << 1)  // row 1: 2*p10 + 4*p11 + 2*p12
        + p20 + (p21 << 1) + p22 );       // row 2: 1*p20 + 2*p21 + 1*p22
 
    // -----------------------------------------------------------------
    //  Registered output - divide by 16 using arithmetic right shift
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            blurred_pixel <= 0;
            pixel_valid   <= 0;
        end else begin
            blurred_pixel <= weighted_sum[11:4];  // divide by 16
            pixel_valid   <= window_valid;
        end
    end
 
endmodule