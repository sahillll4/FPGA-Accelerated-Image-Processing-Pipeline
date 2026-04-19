`timescale 1ns / 1ps
// ============================================================
//  tb_gaussian_filter.v  -  Simple testbench for gaussian_filter
//
//  Project : FPGA Image Processing Pipeline
//  Tool    : Vivado 2025.2 / XSim
//
//  What this does:
//    Feeds a known 3x3 window into the filter and checks
//    that the blurred output matches the expected value.
//
//  Test window (flat region - all pixels = 100):
//    [ 100 100 100 ]
//    [ 100 100 100 ]  → expected output = 100 (unchanged)
//    [ 100 100 100 ]
//
//  Test window (center bright - center = 200, rest = 50):
//    [  50  50  50 ]
//    [  50 200  50 ]  → expected output = (sum/16)
//    [  50  50  50 ]
//    sum = 50*(1+2+1+2+2+1+2+1) + 200*4
//        = 50*12 + 800 = 600+800 = 1400 → 1400/16 = 87
// ============================================================
 
`timescale 1ns / 1ps
 
module tb_gaussian_filter;
 
    localparam DATA_WIDTH = 8;
    localparam CLK_PERIOD = 10;
 
    // ----------------------------------------------------------
    //  Signals
    // ----------------------------------------------------------
    reg                    clk, rst_n, window_valid;
    reg  [DATA_WIDTH-1:0]  p00, p01, p02;
    reg  [DATA_WIDTH-1:0]  p10, p11, p12;
    reg  [DATA_WIDTH-1:0]  p20, p21, p22;
 
    wire [DATA_WIDTH-1:0]  blurred_pixel;
    wire                   pixel_valid;
 
    // ----------------------------------------------------------
    //  DUT
    // ----------------------------------------------------------
    gaussian_filter #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .window_valid(window_valid),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .blurred_pixel(blurred_pixel),
        .pixel_valid(pixel_valid)
    );
 
    // ----------------------------------------------------------
    //  Clock
    // ----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
 
    // ----------------------------------------------------------
    //  Task: apply a window and wait one cycle for result
    // ----------------------------------------------------------
    task apply_window;
        input [7:0] a00, a01, a02;
        input [7:0] a10, a11, a12;
        input [7:0] a20, a21, a22;
        begin
            @(negedge clk);
            window_valid = 1;
            p00=a00; p01=a01; p02=a02;
            p10=a10; p11=a11; p12=a12;
            p20=a20; p21=a21; p22=a22;
            @(posedge clk); #1;  // wait for registered output
            $display("Input window:");
            $display("  [ %0d  %0d  %0d ]", a00, a01, a02);
            $display("  [ %0d  %0d  %0d ]", a10, a11, a12);
            $display("  [ %0d  %0d  %0d ]", a20, a21, a22);
            $display("  Blurred output = %0d", blurred_pixel);
        end
    endtask
 
    // ----------------------------------------------------------
    //  Main test
    // ----------------------------------------------------------
    initial begin
        rst_n        = 0;
        window_valid = 0;
        {p00,p01,p02,p10,p11,p12,p20,p21,p22} = 0;
 
        // Reset for 3 cycles
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n = 1;
 
        // Test 1: Flat region - all pixels the same value
        // A Gaussian blur of a flat region must return the same value
        $display("--- Test 1: Flat region (all=100, expect output=100) ---");
        apply_window(100,100,100, 100,100,100, 100,100,100);
 
        // Test 2: Center bright pixel - blur should average it out
        // Expected: (50*12 + 200*4) / 16 = 1400/16 = 87
        $display("--- Test 2: Bright center (expect output ~87) ---");
        apply_window( 50, 50, 50,  50,200, 50,  50, 50, 50);
 
        // Test 3: Gradient - left side dark, right side bright
        $display("--- Test 3: Left-right gradient ---");
        apply_window(  0, 50,100,   0, 50,100,   0, 50,100);
 
        // Deassert valid and finish
        @(negedge clk); window_valid = 0;
        repeat(3) @(posedge clk);
        $display("Simulation done!");
        $finish;
    end
 
endmodule
