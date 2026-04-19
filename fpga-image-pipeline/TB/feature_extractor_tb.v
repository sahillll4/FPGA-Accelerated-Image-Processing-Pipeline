`timescale 1ns / 1ps
// ============================================================
//  tb_feature_extractor.v - Testbench for feature_extractor
//
//  Project : FPGA Image Processing Pipeline
//  Tool    : Vivado 2025.2 / XSim
//
//  What this does:
//    Sends a stream of edge pixels (simulating one row of the
//    edge map) and checks that the module correctly flags pixels
//    above the threshold as feature points, and counts them.
//
//  Test pixel stream (1 row of 8 pixels):
//    Values:  0, 10, 255, 0, 200, 0, 0, 180
//    Threshold = 150
//    Expected features: pixels at index 2 (255), 4 (200), 7 (180)
//    Expected feature_count at end = 3
// ============================================================
 
`timescale 1ns / 1ps
 
module tb_feature_extractor;
 
    localparam DATA_WIDTH   = 8;
    localparam IMAGE_WIDTH  = 8;   // tiny image for easy simulation
    localparam IMAGE_HEIGHT = 4;
    localparam COUNT_WIDTH  = 16;
    localparam CLK_PERIOD   = 10;
 
    // ----------------------------------------------------------
    //  Signals
    // ----------------------------------------------------------
    reg                    clk, rst_n, pixel_valid;
    reg  [DATA_WIDTH-1:0]  edge_pixel;
    reg  [DATA_WIDTH-1:0]  strong_threshold;
 
    wire                   feature_flag;
    wire [COUNT_WIDTH-1:0] feature_count;
    wire [9:0]             pixel_x;
    wire [8:0]             pixel_y;
    wire                   out_valid;
 
    // ----------------------------------------------------------
    //  DUT
    // ----------------------------------------------------------
    feature_extractor #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .COUNT_WIDTH (COUNT_WIDTH)
    ) dut (
        .clk(clk), .rst_n(rst_n), .pixel_valid(pixel_valid),
        .edge_pixel(edge_pixel),
        .strong_threshold(strong_threshold),
        .feature_flag(feature_flag),
        .feature_count(feature_count),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .out_valid(out_valid)
    );
 
    // ----------------------------------------------------------
    //  Clock
    // ----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
 
    // ----------------------------------------------------------
    //  Task: send one edge pixel
    // ----------------------------------------------------------
    task send_edge_pixel;
        input [DATA_WIDTH-1:0] val;
        begin
            @(negedge clk);
            pixel_valid = 1;
            edge_pixel  = val;
            @(posedge clk); #1;
            $display("  Pixel(%0d,%0d)=%-4d  feature_flag=%0d  feature_count=%0d %s",
                pixel_x, pixel_y, val,
                feature_flag, feature_count,
                feature_flag ? "<-- FEATURE DETECTED" : "");
        end
    endtask
 
    // ----------------------------------------------------------
    //  Main test
    // ----------------------------------------------------------
    initial begin
        rst_n            = 0;
        pixel_valid      = 0;
        edge_pixel       = 0;
        strong_threshold = 150;  // anything >= 150 is a feature
 
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n = 1;
 
        $display("--- Streaming 8 edge pixels, threshold=150 ---");
        $display("    Expect features at values: 255, 200, 180");
 
        send_edge_pixel(  0);   // not a feature
        send_edge_pixel( 10);   // not a feature
        send_edge_pixel(255);   // FEATURE (255 >= 150)
        send_edge_pixel(  0);   // not a feature
        send_edge_pixel(200);   // FEATURE (200 >= 150)
        send_edge_pixel(  0);   // not a feature
        send_edge_pixel(  0);   // not a feature
        send_edge_pixel(180);   // FEATURE (180 >= 150)
 
        @(negedge clk); pixel_valid = 0;
        repeat(2) @(posedge clk);
 
        $display("--- Final feature_count = %0d (expect 3) ---", feature_count);
        if (feature_count == 3)
            $display("PASS: Correct feature count!");
        else
            $display("FAIL: Expected 3, got %0d", feature_count);
 
        $display("Simulation done!");
        $finish;
    end
 
endmodule
 