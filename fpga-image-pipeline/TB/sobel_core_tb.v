`timescale 1ns / 1ps
// ============================================================
//  tb_sobel_core.v  -  Simple testbench for sobel_core
//
//  Project : FPGA Image Processing Pipeline
//  Tool    : Vivado 2025.2 / XSim
//
//  Test cases:
//    1. Flat region  → magnitude should be 0  (no edge)
//    2. Vertical edge (bright left / dark right) → strong Gx
//    3. Horizontal edge (bright top / dark bottom) → strong Gy
//    4. Diagonal edge → both Gx and Gy non-zero
// ============================================================
 
`timescale 1ns / 1ps
 
module tb_sobel_core;
 
    localparam DATA_WIDTH = 8;
    localparam CLK_PERIOD = 10;
 
    // ----------------------------------------------------------
    //  Signals
    // ----------------------------------------------------------
    reg                   clk, rst_n, window_valid;
    reg  [DATA_WIDTH-1:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    wire [DATA_WIDTH-1:0] magnitude;
    wire [1:0]            direction;
    wire                  edge_valid;
 
    // ----------------------------------------------------------
    //  DUT
    // ----------------------------------------------------------
    sobel_core #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .window_valid(window_valid),
        .p00(p00),.p01(p01),.p02(p02),
        .p10(p10),.p11(p11),.p12(p12),
        .p20(p20),.p21(p21),.p22(p22),
        .magnitude(magnitude), .direction(direction),
        .edge_valid(edge_valid)
    );
 
    // ----------------------------------------------------------
    //  Clock
    // ----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
 
    // ----------------------------------------------------------
    //  Task: apply window, wait one cycle, print result
    // ----------------------------------------------------------
    task apply_window;
        input [7:0] a00,a01,a02,a10,a11,a12,a20,a21,a22;
        begin
            @(negedge clk);
            window_valid=1;
            p00=a00;p01=a01;p02=a02;
            p10=a10;p11=a11;p12=a12;
            p20=a20;p21=a21;p22=a22;
            @(posedge clk); #1;
            $display("  Magnitude=%0d  Direction=%0d (%s)",
                magnitude, direction,
                direction==0 ? "Horizontal" :
                direction==1 ? "Diagonal45" :
                direction==2 ? "Vertical"   : "Diagonal135");
        end
    endtask
 
    // ----------------------------------------------------------
    //  Main test
    // ----------------------------------------------------------
    initial begin
        rst_n=0; window_valid=0;
        {p00,p01,p02,p10,p11,p12,p20,p21,p22}=0;
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n=1;
 
        // Test 1: No edge - flat region, all pixels the same
        // Expected: magnitude = 0
        $display("--- Test 1: Flat region (expect magnitude=0) ---");
        apply_window(100,100,100, 100,100,100, 100,100,100);
 
        // Test 2: Vertical edge - left=0, right=255
        // Strong Gx, weak Gy → direction = Horizontal (0)
        $display("--- Test 2: Vertical edge (expect high magnitude, Horizontal) ---");
        apply_window(  0,0,255,  0,0,255,  0,0,255);
 
        // Test 3: Horizontal edge - top=255, bottom=0
        // Weak Gx, strong Gy → direction = Vertical (2)
        $display("--- Test 3: Horizontal edge (expect high magnitude, Vertical) ---");
        apply_window(255,255,255,  128,128,128,  0,0,0);
 
        // Test 4: Diagonal edge - bright top-left, dark bottom-right
        // Both Gx and Gy active → direction = Diagonal (1 or 3)
        $display("--- Test 4: Diagonal edge (expect Diagonal direction) ---");
        apply_window(200,150,100,  150,100,50,  100,50,0);
 
        @(negedge clk); window_valid=0;
        repeat(3) @(posedge clk);
        $display("Simulation done!");
        $finish;
    end
 
endmodule
 