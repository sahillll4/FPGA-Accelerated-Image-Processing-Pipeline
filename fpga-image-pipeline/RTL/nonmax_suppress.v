`timescale 1ns / 1ps
// ============================================================
//  nonmax_suppress.v
//  Non-maximum suppression - thins edges to 1 pixel wide
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2 / XSim
//
//  What it does:
//    After Sobel, edges are thick blobs (3-5 pixels wide).
//    This module looks at each pixel's gradient direction and
//    checks if it is the STRONGEST pixel along that direction.
//    If not, it suppresses (zeroes) the pixel.
//    Result: crisp, 1-pixel-wide edges.
//
//  How it works:
//    It receives the 3x3 window of Sobel magnitudes along with
//    the center pixel's gradient direction. It then compares
//    the center magnitude to its two directional neighbours:
//
//    Direction 0 (horizontal) → compare left (p10) vs right (p12)
//    Direction 1 (45°)        → compare top-left (p00) vs bot-right (p22)
//    Direction 2 (vertical)   → compare top (p01) vs bottom (p21)
//    Direction 3 (135°)       → compare top-right (p02) vs bot-left (p20)
//
//  Latency    : 1 clock cycle
//  Throughput : 1 pixel/clock
// ============================================================
 
module nonmax_suppress #(
    parameter DATA_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    edge_valid,
 
    // 3x3 window of Sobel MAGNITUDES (center = current pixel)
    input  wire [DATA_WIDTH-1:0]   p00, p01, p02,
    input  wire [DATA_WIDTH-1:0]   p10, p11, p12,
    input  wire [DATA_WIDTH-1:0]   p20, p21, p22,
 
    // Gradient direction of center pixel (from sobel_core)
    input  wire [1:0]              direction,
 
    // Threshold - pixels below this are suppressed regardless
    input  wire [DATA_WIDTH-1:0]   threshold,
 
    output reg  [DATA_WIDTH-1:0]   edge_out,     // thinned edge pixel
    output reg                     out_valid
);
 
    // -----------------------------------------------------------------
    //  Select the two neighbours along the gradient direction
    // -----------------------------------------------------------------
    reg [DATA_WIDTH-1:0] neighbour_a;
    reg [DATA_WIDTH-1:0] neighbour_b;
 
    always @(*) begin
        case (direction)
            2'd0: begin neighbour_a = p10; neighbour_b = p12; end  // horizontal
            2'd1: begin neighbour_a = p00; neighbour_b = p22; end  // 45°
            2'd2: begin neighbour_a = p01; neighbour_b = p21; end  // vertical
            2'd3: begin neighbour_a = p02; neighbour_b = p20; end  // 135°
            default: begin neighbour_a = 0; neighbour_b = 0; end
        endcase
    end
 
    // -----------------------------------------------------------------
    //  Center pixel is a local maximum if it is >= both neighbours
    //  AND above the threshold.
    //  If not a maximum → suppress to 0.
    // -----------------------------------------------------------------
    wire is_maximum = (p11 >= neighbour_a) && (p11 >= neighbour_b)
                   && (p11 >= threshold);
 
    // -----------------------------------------------------------------
    //  Registered output
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            edge_out  <= 0;
            out_valid <= 0;
        end else begin
            edge_out  <= is_maximum ? p11 : 8'd0;
            out_valid <= edge_valid;
        end
    end
 
endmodule
