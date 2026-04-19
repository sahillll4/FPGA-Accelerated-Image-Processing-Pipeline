// ============================================================
//  tb_top.v  —  Testbench for the full pipeline (top.v)
//
//  Project : FPGA Image Processing Pipeline
//  Tool    : Vivado 2025.2 / XSim
//
//  What this does:
//    Streams a tiny 8x8 synthetic image through all 5 stages.
//    The image has a bright horizontal stripe in the middle
//    so we know where edges should appear.
//
//  Image pattern (8x8, row by row):
//    Rows 0-2 :  all pixels = 20   (dark top)
//    Rows 3-4 :  all pixels = 200  (bright stripe)
//    Rows 5-7 :  all pixels = 20   (dark bottom)
//
//  Expected behaviour:
//    Edges should appear at the top and bottom of the bright
//    stripe (rows 2-3 and rows 4-5 boundaries).
//    Interior of the stripe and dark regions → magnitude = 0.
// ============================================================

`timescale 1ns / 1ps

module tb_top;

    localparam DATA_WIDTH   = 8;
    localparam IMAGE_WIDTH  = 8;
    localparam IMAGE_HEIGHT = 8;
    localparam CLK_PERIOD   = 10;

    // ----------------------------------------------------------
    //  Signals
    // ----------------------------------------------------------
    reg                  clk, rst_n;
    reg                  pixel_in_valid;
    reg  [DATA_WIDTH-1:0] pixel_in;
    reg  [DATA_WIDTH-1:0] nms_threshold;
    reg  [DATA_WIDTH-1:0] feature_threshold;

    wire [DATA_WIDTH-1:0] edge_out;
    wire                  edge_out_valid;
    wire                  feature_flag;
    wire [15:0]           feature_count;
    wire [9:0]            feature_x;
    wire [8:0]            feature_y;

    // ----------------------------------------------------------
    //  DUT
    // ----------------------------------------------------------
    top #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .pixel_in_valid   (pixel_in_valid),
        .pixel_in         (pixel_in),
        .nms_threshold    (nms_threshold),
        .feature_threshold(feature_threshold),
        .edge_out         (edge_out),
        .edge_out_valid   (edge_out_valid),
        .feature_flag     (feature_flag),
        .feature_count    (feature_count),
        .feature_x        (feature_x),
        .feature_y        (feature_y)
    );

    // ----------------------------------------------------------
    //  Clock
    // ----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ----------------------------------------------------------
    //  Monitor — print every output pixel
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (edge_out_valid) begin
            if (edge_out > 0)
                $display("EDGE at (%0d,%0d) strength=%0d  features_so_far=%0d",
                    feature_x, feature_y, edge_out, feature_count);
        end
        if (feature_flag)
            $display("*** FEATURE POINT at (%0d,%0d) ***", feature_x, feature_y);
    end

    // ----------------------------------------------------------
    //  Task: send one pixel
    // ----------------------------------------------------------
    task send_pixel;
        input [DATA_WIDTH-1:0] val;
        begin
            @(negedge clk);
            pixel_in_valid = 1;
            pixel_in       = val;
        end
    endtask

    // ----------------------------------------------------------
    //  Task: send one complete row
    // ----------------------------------------------------------
    task send_row;
        input [DATA_WIDTH-1:0] val;
        integer i;
        begin
            for (i = 0; i < IMAGE_WIDTH; i = i+1)
                send_pixel(val);
        end
    endtask

    // ----------------------------------------------------------
    //  Main stimulus
    // ----------------------------------------------------------
    integer row;
    initial begin
        rst_n             = 0;
        pixel_in_valid    = 0;
        pixel_in          = 0;
        nms_threshold     = 8'd30;   // suppress weak edges
        feature_threshold = 8'd80;   // strong edges become features

        // Reset for 4 cycles
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1;

        $display("=== Streaming 8x8 test image ===");
        $display("Rows 0-2: dark (20)  Rows 3-4: bright (200)  Rows 5-7: dark (20)");
        $display("Expect edges at the stripe boundaries");

        // Stream the image row by row
        for (row = 0; row < IMAGE_HEIGHT; row = row+1) begin
            if (row >= 3 && row <= 4)
                send_row(200);   // bright stripe
            else
                send_row(20);    // dark region
        end

        // Wait for pipeline to drain (pipeline depth = ~7 stages)
        @(negedge clk); pixel_in_valid = 0;
        repeat(20) @(posedge clk);

        $display("=== Simulation complete ===");
        $display("Total feature points detected: %0d", feature_count);
        $finish;
    end

endmodule
