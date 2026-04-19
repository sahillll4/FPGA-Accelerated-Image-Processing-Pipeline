// ============================================================
//  tb_line_buffer.v  -  Simple testbench for line_buffer
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2 / XSim
//
//  What this testbench does:
//    1. Resets the module
//    2. Sends 3 rows of pixels (a tiny 5-wide image)
//    3. Watches the 3x3 window output appear
//
//  Test image (3 rows x 5 cols):
//    Row 0 :  1  2  3  4  5
//    Row 1 : 11 12 13 14 15
//    Row 2 : 21 22 23 24 25
//
//  Expected first valid window:
//    [  1   2   3 ]
//    [ 11  12  13 ]
//    [ 21  22  23 ]
// ============================================================
 
`timescale 1ns / 1ps
 
module tb_line_buffer;
 
    // ----------------------------------------------------------
    //  Parameters
    // ----------------------------------------------------------
    localparam DATA_WIDTH  = 8;   // 8-bit pixels
    localparam IMAGE_WIDTH = 5;   // 5 pixels wide (small = easy to read)
    localparam CLK_PERIOD  = 10;  // 10ns clock = 100 MHz
 
    // ----------------------------------------------------------
    //  Signals
    // ----------------------------------------------------------
    reg                   clk;
    reg                   rst_n;
    reg                   pixel_valid;
    reg  [DATA_WIDTH-1:0] pixel_in;
 
    wire [DATA_WIDTH-1:0] p00, p01, p02;  // Top row of window
    wire [DATA_WIDTH-1:0] p10, p11, p12;  // Middle row
    wire [DATA_WIDTH-1:0] p20, p21, p22;  // Bottom row
    wire                  window_valid;
 
    // ----------------------------------------------------------
    //  Connect the module we are testing (DUT = Device Under Test)
    // ----------------------------------------------------------
    line_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .pixel_valid (pixel_valid),
        .pixel_in    (pixel_in),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .window_valid(window_valid)
    );
 
    // ----------------------------------------------------------
    //  Clock: toggles every 5ns → 10ns period = 100 MHz
    // ----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;
 
    // ----------------------------------------------------------
    //  Helper task: send one pixel on the next falling edge
    // ----------------------------------------------------------
    task send_pixel;
        input [DATA_WIDTH-1:0] pix;
        begin
            @(negedge clk);       // wait for falling edge
            pixel_valid = 1;      // tell the module a pixel is ready
            pixel_in    = pix;    // put the pixel value on the wire
        end
    endtask
 
    // ----------------------------------------------------------
    //  Print every valid window to the Tcl Console
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (window_valid) begin
            $display("Valid window at T=%0t ns:", $time);
            $display("  [ %0d  %0d  %0d ]", p00, p01, p02);
            $display("  [ %0d  %0d  %0d ]", p10, p11, p12);
            $display("  [ %0d  %0d  %0d ]", p20, p21, p22);
        end
    end
 
    // ----------------------------------------------------------
    //  Main test sequence
    // ----------------------------------------------------------
    initial begin
 
        // Step 1: Initialise everything to 0
        rst_n       = 0;
        pixel_valid = 0;
        pixel_in    = 0;
 
        // Step 2: Hold reset for 3 clock cycles
        repeat(3) @(posedge clk);
 
        // Step 3: Release reset
        @(negedge clk);
        rst_n = 1;
 
        // Step 4: Send Row 0 (no windows expected yet)
        $display("Sending Row 0...");
        send_pixel(1);
        send_pixel(2);
        send_pixel(3);
        send_pixel(4);
        send_pixel(5);
 
        // Step 5: Send Row 1 (still no windows yet)
        $display("Sending Row 1...");
        send_pixel(11);
        send_pixel(12);
        send_pixel(13);
        send_pixel(14);
        send_pixel(15);
 
        // Step 6: Send Row 2 - window_valid goes HIGH from col 2 onwards
        $display("Sending Row 2 - watch window_valid go HIGH...");
        send_pixel(21);
        send_pixel(22);
        send_pixel(23);
        send_pixel(24);
        send_pixel(25);
 
        // Step 7: Wait a few cycles then finish
        repeat(5) @(posedge clk);
        $display("Simulation done!");
        $finish;
 
    end
 
endmodule