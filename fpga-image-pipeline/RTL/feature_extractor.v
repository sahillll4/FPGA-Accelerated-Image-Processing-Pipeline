`timescale 1ns / 1ps
// ============================================================
//  feature_extractor.v
//  Simple feature point detector
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2 / XSim
//
//  What it does:
//    Scans the thinned edge map (output of nonmax_suppress).
//    Any pixel above the strong_threshold is marked as a
//    feature point (a significant edge location).
//    It outputs:
//      - feature_flag : 1 if current pixel is a feature point
//      - feature_count: running total of feature points found
//      - pixel_x, pixel_y: coordinates of current pixel
//
//  This is the final stage before results go back to Python.
// ============================================================
 
module feature_extractor #(
    parameter DATA_WIDTH  = 8,
    parameter IMAGE_WIDTH = 320,
    parameter IMAGE_HEIGHT= 240,
    parameter COUNT_WIDTH = 16   // supports up to 65535 features
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    pixel_valid,
    input  wire [DATA_WIDTH-1:0]   edge_pixel,        // from nonmax_suppress
    input  wire [DATA_WIDTH-1:0]   strong_threshold,  // feature detection threshold
 
    output reg                     feature_flag,   // 1 = this pixel is a feature
    output reg  [COUNT_WIDTH-1:0]  feature_count,  // total features so far
    output reg  [9:0]              pixel_x,        // current pixel X coordinate
    output reg  [8:0]              pixel_y,        // current pixel Y coordinate
    output reg                     out_valid
);
 
    // -----------------------------------------------------------------
    //  Pixel coordinate tracking
    // -----------------------------------------------------------------
    reg [9:0] col_cnt;
    reg [8:0] row_cnt;
 
    always @(posedge clk) begin
        if (!rst_n) begin
            col_cnt       <= 0;
            row_cnt       <= 0;
            feature_flag  <= 0;
            feature_count <= 0;
            pixel_x       <= 0;
            pixel_y       <= 0;
            out_valid     <= 0;
 
        end else if (pixel_valid) begin
 
            // Detect feature: edge pixel above strong threshold
            if (edge_pixel >= strong_threshold) begin
                feature_flag  <= 1;
                feature_count <= feature_count + 1;
            end else begin
                feature_flag  <= 0;
            end
 
            // Output coordinates of current pixel
            pixel_x   <= col_cnt;
            pixel_y   <= row_cnt;
            out_valid <= 1;
 
            // Advance column and row counters
            if (col_cnt == IMAGE_WIDTH - 1) begin
                col_cnt <= 0;
                if (row_cnt == IMAGE_HEIGHT - 1)
                    row_cnt <= 0;       // frame complete, wrap
                else
                    row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
 
        end else begin
            out_valid    <= 0;
            feature_flag <= 0;
        end
    end
 
endmodule
