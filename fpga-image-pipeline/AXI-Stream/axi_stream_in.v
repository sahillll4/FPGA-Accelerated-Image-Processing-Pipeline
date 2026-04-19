// ============================================================
//  axi_stream_in.v
//  AXI4-Stream slave — receives pixel data from PYNQ DMA
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2
//
//  What it does:
//    Acts as an AXI4-Stream slave. The PYNQ DMA master sends
//    pixels over the stream bus. This module unpacks the data
//    and feeds pixels one at a time into the processing pipeline.
//
//  AXI4-Stream signals:
//    s_axis_tvalid : master has data ready
//    s_axis_tready : we are ready to accept (always 1 here)
//    s_axis_tdata  : the pixel data (32-bit bus, we use [7:0])
//    s_axis_tlast  : last pixel in the frame
//
//  We set tready = 1 always because our pipeline can accept
//  1 pixel per clock — it never needs to back-pressure the DMA.
// ============================================================

module axi_stream_in #(
    parameter DATA_WIDTH  = 8,
    parameter AXIS_WIDTH  = 32   // AXI-Stream bus width (DMA default)
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // AXI4-Stream slave interface (from DMA)
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire [AXIS_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tlast,

    // Output to pipeline
    output reg  [DATA_WIDTH-1:0]  pixel_out,
    output reg                    pixel_valid,
    output reg                    frame_done    // pulses when tlast received
);

    // Always ready — pipeline accepts 1 pixel/clock
    assign s_axis_tready = 1'b1;

    always @(posedge clk) begin
        if (!rst_n) begin
            pixel_out  <= 0;
            pixel_valid<= 0;
            frame_done <= 0;
        end else begin
            // Latch pixel when valid data arrives
            if (s_axis_tvalid) begin
                pixel_out   <= s_axis_tdata[DATA_WIDTH-1:0]; // take LSB byte
                pixel_valid <= 1'b1;
                frame_done  <= s_axis_tlast; // pulse on last pixel
            end else begin
                pixel_valid <= 1'b0;
                frame_done  <= 1'b0;
            end
        end
    end

endmodule
