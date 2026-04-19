`timescale 1ns / 1ps
// ============================================================
//  sobel_core.v
//  Sobel edge detector
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2 / XSim
//
//  What it does:
//    Applies two 3x3 Sobel kernels to the blurred pixel window.
//    Gx detects horizontal edges, Gy detects vertical edges.
//    Magnitude = |Gx| + |Gy|  (avoids expensive square root)
//    Direction is encoded as 4 values (0, 45, 90, 135 degrees)
//    for use by the non-max suppression stage.
//
//  Sobel kernels:
//
//    Gx:              Gy:
//    [-1  0 +1]       [+1 +2 +1]
//    [-2  0 +2]       [ 0  0  0]
//    [-1  0 +1]       [-1 -2 -1]
//
//  Latency    : 1 clock cycle
//  Throughput : 1 pixel/clock
// ============================================================
 
module sobel_core #(
    parameter DATA_WIDTH = 8
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      window_valid,
 
    // 3x3 window of BLURRED pixels (from a second line_buffer stage)
    input  wire [DATA_WIDTH-1:0]     p00, p01, p02,
    input  wire [DATA_WIDTH-1:0]     p10, p11, p12,
    input  wire [DATA_WIDTH-1:0]     p20, p21, p22,
 
    output reg  [DATA_WIDTH-1:0]     magnitude,    // edge strength
    output reg  [1:0]                direction,    // 0=0° 1=45° 2=90° 3=135°
    output reg                       edge_valid
);
 
    // -----------------------------------------------------------------
    //  Signed extension for Sobel arithmetic (pixels are unsigned,
    //  Sobel involves subtraction so we need signed intermediate values)
    // -----------------------------------------------------------------
    wire signed [9:0] s00 = {2'b00, p00};
    wire signed [9:0] s01 = {2'b00, p01};
    wire signed [9:0] s02 = {2'b00, p02};
    wire signed [9:0] s10 = {2'b00, p10};
    wire signed [9:0] s12 = {2'b00, p12};
    wire signed [9:0] s20 = {2'b00, p20};
    wire signed [9:0] s21 = {2'b00, p21};
    wire signed [9:0] s22 = {2'b00, p22};
 
    // -----------------------------------------------------------------
    //  Gx = right column - left column (weighted)
    //  Gx = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20)
    // -----------------------------------------------------------------
    wire signed [10:0] Gx = (s02 + (s12 <<< 1) + s22)
                           - (s00 + (s10 <<< 1) + s20);
 
    // -----------------------------------------------------------------
    //  Gy = top row - bottom row (weighted)
    //  Gy = (p00 + 2*p01 + p02) - (p20 + 2*p21 + p22)
    // -----------------------------------------------------------------
    wire signed [10:0] Gy = (s00 + (s01 <<< 1) + s02)
                           - (s20 + (s21 <<< 1) + s22);
 
    // -----------------------------------------------------------------
    //  Absolute values
    // -----------------------------------------------------------------
    wire [10:0] abs_Gx = Gx[10] ? (~Gx + 1'b1) : Gx;
    wire [10:0] abs_Gy = Gy[10] ? (~Gy + 1'b1) : Gy;
 
    // -----------------------------------------------------------------
    //  Magnitude approximation: |Gx| + |Gy|, clamped to 8 bits
    // -----------------------------------------------------------------
    wire [11:0] mag_sum = abs_Gx + abs_Gy;
    wire [7:0]  mag_clamped = (mag_sum > 255) ? 8'd255 : mag_sum[7:0];
 
    // -----------------------------------------------------------------
    //  Gradient direction (4 sectors, for non-max suppression)
    //    0 = horizontal  (0°)
    //    1 = diagonal    (45°)
    //    2 = vertical    (90°)
    //    3 = diagonal    (135°)
    // -----------------------------------------------------------------
    wire [1:0] grad_dir;
    assign grad_dir =
        (abs_Gx > (abs_Gy << 1))                     ? 2'd0 :  // mostly horizontal
        (abs_Gy > (abs_Gx << 1))                     ? 2'd2 :  // mostly vertical
        ((Gx[10] ^ Gy[10]) == 0)                     ? 2'd1 :  // same sign → 45°
                                                        2'd3 ;  // opposite sign → 135°
 
    // -----------------------------------------------------------------
    //  Registered output
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            magnitude  <= 0;
            direction  <= 0;
            edge_valid <= 0;
        end else begin
            magnitude  <= mag_clamped;
            direction  <= grad_dir;
            edge_valid <= window_valid;
        end
    end
 
endmodule
 
