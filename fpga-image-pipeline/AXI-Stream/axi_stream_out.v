// ============================================================
//  axi_stream_out.v
//  AXI4-Stream master — sends edge map back to PYNQ DMA
//
//  Project : FPGA Image Processing Pipeline
//  Board   : PYNQ Z2 (Zynq XC7Z020)
//  Tool    : Vivado 2025.2
//
//  What it does:
//    Acts as an AXI4-Stream master. Packs the edge pixel output
//    from the pipeline into the AXI-Stream bus and sends it
//    back to the PYNQ DMA so Python can read the result.
//
//  AXI4-Stream signals:
//    m_axis_tvalid : we have data to send
//    m_axis_tready : DMA is ready to accept (backpressure)
//    m_axis_tdata  : edge pixel packed into 32-bit bus
//    m_axis_tlast  : signals end of frame to DMA
//
//  Pixel counter tracks position so tlast is asserted on the
//  very last pixel of each frame.
// ============================================================

module axi_stream_out #(
    parameter DATA_WIDTH   = 8,
    parameter AXIS_WIDTH   = 32,
    parameter IMAGE_WIDTH  = 320,
    parameter IMAGE_HEIGHT = 240
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // From pipeline
    input  wire [DATA_WIDTH-1:0]   edge_in,
    input  wire                    edge_valid,

    // AXI4-Stream master interface (to DMA)
    output reg                     m_axis_tvalid,
    input  wire                    m_axis_tready,
    output reg  [AXIS_WIDTH-1:0]   m_axis_tdata,
    output reg                     m_axis_tlast
);

    localparam TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT;
    localparam CNT_BITS     = $clog2(TOTAL_PIXELS);

    reg [CNT_BITS-1:0] pixel_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_axis_tvalid <= 0;
            m_axis_tdata  <= 0;
            m_axis_tlast  <= 0;
            pixel_cnt     <= 0;
        end else begin
            if (edge_valid) begin
                // Pack 8-bit pixel into 32-bit AXI word (zero-pad upper bits)
                m_axis_tdata  <= {{(AXIS_WIDTH-DATA_WIDTH){1'b0}}, edge_in};
                m_axis_tvalid <= 1'b1;

                // Assert tlast on the final pixel of the frame
                if (pixel_cnt == TOTAL_PIXELS - 1) begin
                    m_axis_tlast <= 1'b1;
                    pixel_cnt    <= 0;
                end else begin
                    m_axis_tlast <= 1'b0;
                    // Only advance counter when DMA is ready
                    if (m_axis_tready)
                        pixel_cnt <= pixel_cnt + 1;
                end
            end else begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end
        end
    end

endmodule
