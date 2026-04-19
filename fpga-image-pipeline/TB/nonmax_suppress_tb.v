`timescale 1ns / 1ps
// ============================================================
//  tb_nonmax_suppress.v - Simple testbench for nonmax_suppress
//
//  Project : FPGA Image Processing Pipeline
//  Tool    : Vivado 2025.2 / XSim
//
//  Test cases:
//    1. Center is the strongest → should PASS THROUGH
//    2. Center is NOT the strongest → should be SUPPRESSED (0)
//    3. Center is strong but below threshold → SUPPRESSED
// ============================================================
 
`timescale 1ns / 1ps
 
module tb_nonmax_suppress;
 
    localparam DATA_WIDTH = 8;
    localparam CLK_PERIOD = 10;
 
    // ----------------------------------------------------------
    //  Signals
    // ----------------------------------------------------------
    reg                   clk, rst_n, edge_valid;
    reg  [DATA_WIDTH-1:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    reg  [1:0]            direction;
    reg  [DATA_WIDTH-1:0] threshold;
    wire [DATA_WIDTH-1:0] edge_out;
    wire                  out_valid;
 
    // ----------------------------------------------------------
    //  DUT
    // ----------------------------------------------------------
    nonmax_suppress #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .edge_valid(edge_valid),
        .p00(p00),.p01(p01),.p02(p02),
        .p10(p10),.p11(p11),.p12(p12),
        .p20(p20),.p21(p21),.p22(p22),
        .direction(direction), .threshold(threshold),
        .edge_out(edge_out), .out_valid(out_valid)
    );
 
    // ----------------------------------------------------------
    //  Clock
    // ----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
 
    // ----------------------------------------------------------
    //  Task: apply inputs and show result after 1 cycle
    // ----------------------------------------------------------
    task apply_test;
        input [7:0] a00,a01,a02,a10,a11,a12,a20,a21,a22;
        input [1:0] dir;
        input [7:0] thresh;
        input [63:0] test_name; // just for display
        begin
            @(negedge clk);
            edge_valid=1;
            p00=a00;p01=a01;p02=a02;
            p10=a10;p11=a11;p12=a12;
            p20=a20;p21=a21;p22=a22;
            direction=dir; threshold=thresh;
            @(posedge clk); #1;
            $display("  Center=%0d  Neighbours=(%0d,%0d)  Dir=%0d  Thresh=%0d  Output=%0d  %s",
                a11,
                dir==0?a10: dir==1?a00: dir==2?a01:a02,
                dir==0?a12: dir==1?a22: dir==2?a21:a20,
                dir, thresh,
                edge_out,
                edge_out > 0 ? "KEPT" : "SUPPRESSED");
        end
    endtask
 
    // ----------------------------------------------------------
    //  Main test
    // ----------------------------------------------------------
    initial begin
        rst_n=0; edge_valid=0; direction=0; threshold=20;
        {p00,p01,p02,p10,p11,p12,p20,p21,p22}=0;
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n=1;
 
        // Test 1: Center (150) > both neighbours (80,90) → KEPT
        // Direction=horizontal: compare p10 vs p12
        $display("--- Test 1: Center is local max (expect KEPT) ---");
        apply_test( 50, 50, 50,
                    80,150, 90,
                    50, 50, 50,
                    2'd0, 8'd20, "T1");
 
        // Test 2: Center (80) < right neighbour (200) → SUPPRESSED
        $display("--- Test 2: Center is NOT local max (expect SUPPRESSED) ---");
        apply_test( 50, 50, 50,
                    50, 80,200,
                    50, 50, 50,
                    2'd0, 8'd20, "T2");
 
        // Test 3: Center (150) is max but below threshold → SUPPRESSED
        $display("--- Test 3: Below threshold (expect SUPPRESSED) ---");
        apply_test( 10, 10, 10,
                    10,150, 10,
                    10, 10, 10,
                    2'd0, 8'd200, "T3");
 
        // Test 4: Vertical direction - center vs top and bottom
        // center=180, top(p01)=100, bottom(p21)=90 → KEPT
        $display("--- Test 4: Vertical direction, center is max (expect KEPT) ---");
        apply_test( 50,100, 50,
                    50,180, 50,
                    50, 90, 50,
                    2'd2, 8'd20, "T4");
 
        @(negedge clk); edge_valid=0;
        repeat(3) @(posedge clk);
        $display("Simulation done!");
        $finish;
    end
 
endmodule