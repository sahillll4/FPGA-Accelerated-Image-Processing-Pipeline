// ============================================================
//  top.v
//  Top-level pipeline — wires all 5 stages together
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2
//
//  Data flow:
//    pixel_in (serial stream)
//      → line_buffer_1    → 3x3 raw window
//      → gaussian_filter  → blurred pixel (1 value)
//      → line_buffer_2    → 3x3 blurred window
//      → sobel_core       → magnitude + direction
//      → line_buffer_3    → 3x3 magnitude window
//      → nonmax_suppress  → thinned edge pixel
//      → feature_extractor→ feature_flag + feature_count
//
//  Note on three line buffers:
//    lb1 converts raw pixel stream → 3x3 window for Gaussian.
//    After Gaussian outputs one blurred pixel per clock, lb2
//    rebuilds a 3x3 window of blurred pixels for Sobel.
//    After Sobel outputs magnitude per clock, lb3 rebuilds
//    a 3x3 magnitude window for non-max suppression (which
//    needs to compare the centre pixel to its neighbours).
// ============================================================

module top #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_WIDTH  = 320,
    parameter IMAGE_HEIGHT = 240
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Pixel input (from AXI stream wrapper)
    input  wire                   pixel_in_valid,
    input  wire [DATA_WIDTH-1:0]  pixel_in,

    // Thresholds (set via AXI-Lite registers)
    input  wire [DATA_WIDTH-1:0]  nms_threshold,      // non-max suppression noise floor
    input  wire [DATA_WIDTH-1:0]  feature_threshold,  // feature detection threshold

    // Edge map output (thinned edge pixel, 1 per clock)
    output wire [DATA_WIDTH-1:0]  edge_out,
    output wire                   edge_out_valid,

    // Feature outputs
    output wire                   feature_flag,
    output wire [15:0]            feature_count,
    output wire [9:0]             feature_x,
    output wire [8:0]             feature_y
);

    // -----------------------------------------------------------------
    //  Stage 1 : Line buffer 1 — raw pixel stream → 3x3 raw window
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] lb1_p00, lb1_p01, lb1_p02;
    wire [DATA_WIDTH-1:0] lb1_p10, lb1_p11, lb1_p12;
    wire [DATA_WIDTH-1:0] lb1_p20, lb1_p21, lb1_p22;
    wire                  lb1_valid;

    line_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH)
    ) lb1 (
        .clk         (clk),
        .rst_n       (rst_n),
        .pixel_valid (pixel_in_valid),
        .pixel_in    (pixel_in),
        .p00(lb1_p00), .p01(lb1_p01), .p02(lb1_p02),
        .p10(lb1_p10), .p11(lb1_p11), .p12(lb1_p12),
        .p20(lb1_p20), .p21(lb1_p21), .p22(lb1_p22),
        .window_valid(lb1_valid)
    );

    // -----------------------------------------------------------------
    //  Stage 2 : Gaussian filter — 3x3 raw window → 1 blurred pixel
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] gauss_pixel;
    wire                  gauss_valid;

    gaussian_filter #(
        .DATA_WIDTH (DATA_WIDTH)
    ) gauss (
        .clk          (clk),
        .rst_n        (rst_n),
        .window_valid (lb1_valid),
        .p00(lb1_p00), .p01(lb1_p01), .p02(lb1_p02),
        .p10(lb1_p10), .p11(lb1_p11), .p12(lb1_p12),
        .p20(lb1_p20), .p21(lb1_p21), .p22(lb1_p22),
        .blurred_pixel(gauss_pixel),
        .pixel_valid  (gauss_valid)
    );

    // -----------------------------------------------------------------
    //  Stage 3 : Line buffer 2 — blurred pixel stream → 3x3 blurred window
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] lb2_p00, lb2_p01, lb2_p02;
    wire [DATA_WIDTH-1:0] lb2_p10, lb2_p11, lb2_p12;
    wire [DATA_WIDTH-1:0] lb2_p20, lb2_p21, lb2_p22;
    wire                  lb2_valid;

    line_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH)
    ) lb2 (
        .clk         (clk),
        .rst_n       (rst_n),
        .pixel_valid (gauss_valid),
        .pixel_in    (gauss_pixel),
        .p00(lb2_p00), .p01(lb2_p01), .p02(lb2_p02),
        .p10(lb2_p10), .p11(lb2_p11), .p12(lb2_p12),
        .p20(lb2_p20), .p21(lb2_p21), .p22(lb2_p22),
        .window_valid(lb2_valid)
    );

    // -----------------------------------------------------------------
    //  Stage 4 : Sobel core — 3x3 blurred window → magnitude + direction
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] sobel_mag;
    wire [1:0]            sobel_dir;
    wire                  sobel_valid;

    sobel_core #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sobel (
        .clk          (clk),
        .rst_n        (rst_n),
        .window_valid (lb2_valid),
        .p00(lb2_p00), .p01(lb2_p01), .p02(lb2_p02),
        .p10(lb2_p10), .p11(lb2_p11), .p12(lb2_p12),
        .p20(lb2_p20), .p21(lb2_p21), .p22(lb2_p22),
        .magnitude  (sobel_mag),
        .direction  (sobel_dir),
        .edge_valid (sobel_valid)
    );

    // -----------------------------------------------------------------
    //  Stage 5 : Line buffer 3 — magnitude stream → 3x3 magnitude window
    //  Note: direction of the centre pixel (p11) is what NMS needs.
    //  We delay sobel_dir by the same number of cycles lb3 introduces
    //  so they stay aligned. lb3 has 1 cycle latency, so we register
    //  sobel_dir once.
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] lb3_p00, lb3_p01, lb3_p02;
    wire [DATA_WIDTH-1:0] lb3_p10, lb3_p11, lb3_p12;
    wire [DATA_WIDTH-1:0] lb3_p20, lb3_p21, lb3_p22;
    wire                  lb3_valid;

    line_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH)
    ) lb3 (
        .clk         (clk),
        .rst_n       (rst_n),
        .pixel_valid (sobel_valid),
        .pixel_in    (sobel_mag),
        .p00(lb3_p00), .p01(lb3_p01), .p02(lb3_p02),
        .p10(lb3_p10), .p11(lb3_p11), .p12(lb3_p12),
        .p20(lb3_p20), .p21(lb3_p21), .p22(lb3_p22),
        .window_valid(lb3_valid)
    );

    // Direction delay register — align sobel_dir with lb3 window
    reg [1:0] sobel_dir_d;
    always @(posedge clk) begin
        if (!rst_n) sobel_dir_d <= 2'd0;
        else        sobel_dir_d <= sobel_dir;
    end

    // -----------------------------------------------------------------
    //  Stage 6 : Non-max suppression — thin edges to 1px wide
    // -----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] nms_out;
    wire                  nms_valid;

    nonmax_suppress #(
        .DATA_WIDTH (DATA_WIDTH)
    ) nms (
        .clk        (clk),
        .rst_n      (rst_n),
        .edge_valid (lb3_valid),
        .p00(lb3_p00), .p01(lb3_p01), .p02(lb3_p02),
        .p10(lb3_p10), .p11(lb3_p11), .p12(lb3_p12),
        .p20(lb3_p20), .p21(lb3_p21), .p22(lb3_p22),
        .direction  (sobel_dir_d),
        .threshold  (nms_threshold),
        .edge_out   (nms_out),
        .out_valid  (nms_valid)
    );

    // -----------------------------------------------------------------
    //  Stage 7 : Feature extractor — detect strong edge points
    // -----------------------------------------------------------------
    feature_extractor #(
        .DATA_WIDTH   (DATA_WIDTH),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .COUNT_WIDTH  (16)
    ) feat (
        .clk              (clk),
        .rst_n            (rst_n),
        .pixel_valid      (nms_valid),
        .edge_pixel       (nms_out),
        .strong_threshold (feature_threshold),
        .feature_flag     (feature_flag),
        .feature_count    (feature_count),
        .pixel_x          (feature_x),
        .pixel_y          (feature_y),
        .out_valid        (edge_out_valid)
    );

    // Edge output is the NMS result (the processed edge map)
    assign edge_out = nms_out;

endmodule
