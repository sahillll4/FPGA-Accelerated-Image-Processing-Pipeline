# FPGA-Accelerated Image Processing Pipeline

> Real-time 5-stage image processing pipeline implemented on the **Xilinx PYNQ-Z2** (Zynq XC7Z020) using Verilog and AXI4-Stream, with Python/Jupyter control via PYNQ framework.

---

## Overview

This project implements a fully hardware-accelerated image processing pipeline on the PYNQ-Z2 FPGA board. The pipeline chains five processing stages connected via AXI4-Stream interfaces, enabling real-time pixel-level operations directly in programmable logic (PL), with results accessible from the ARM Processing System (PS) through the PYNQ Python framework.

**Board:** Xilinx PYNQ-Z2 (Zynq XC7Z020-1CLG400C)  
**Toolchain:** Xilinx Vivado 2025.2 + PYNQ Framework  
**Interface:** AXI4-Stream (inter-stage) · AXI4-Lite (control/status)  
**Language:** Verilog (RTL) · Python (host control)

---

## Pipeline Architecture

```
Input Image (PS)
      │
      ▼
┌─────────────────┐
│  Stage 1        │  Gaussian Filter (5×5 kernel)
│  Noise Reduction│  Line-buffer based convolution
└────────┬────────┘
         │ AXI4-Stream
         ▼
┌─────────────────┐
│  Stage 2        │  Sobel Edge Detection (Gx, Gy)
│  Edge Detection │  Gradient magnitude & direction
└────────┬────────┘
         │ AXI4-Stream
         ▼
┌─────────────────┐
│  Stage 3        │  Non-Maximum Suppression
│  Edge Thinning  │  Direction-aware local maxima
└────────┬────────┘
         │ AXI4-Stream
         ▼
┌─────────────────┐
│  Stage 4        │  Feature Extraction
│  Corner/Blob    │  Harris / intensity thresholding
└────────┬────────┘
         │ AXI4-Stream
         ▼
Output Buffer (PS) → Jupyter Notebook Display
```

---

## Repository Structure

```
fpga-image-pipeline/
├── rtl/                        # Verilog RTL source files
│   ├── gaussian_filter.v       # Stage 1 – 5×5 Gaussian blur
│   ├── sobel_edge.v            # Stage 2 – Sobel gradient computation
│   ├── non_max_suppression.v   # Stage 3 – Edge thinning
│   ├── feature_extract.v       # Stage 4 – Feature/corner detection
│   ├── axis_wrapper.v          # AXI4-Stream wrapper (per stage)
│   └── top_pipeline.v          # Top-level integration module
│
├── tb/                         # XSim testbenches
│   ├── tb_gaussian.v
│   ├── tb_sobel.v
│   ├── tb_nms.v
│   ├── tb_feature.v
│   └── tb_top_pipeline.v
│
├── vivado/                     # Vivado project files
│   ├── constraints/
│   │   └── pynq_z2.xdc         # PYNQ-Z2 pin/timing constraints
│   ├── bd/                     # Block Design exports (.tcl)
│   │   └── pipeline_bd.tcl     # Recreatable block design script
│   └── scripts/
│       └── build.tcl           # Automated build script
│
├── sim/                        # Simulation waveforms & logs
│   ├── waveforms/
│   └── logs/
│
├── notebooks/                  # PYNQ Jupyter notebooks
│   └── pipeline_demo.ipynb     # Host-side control & visualization
│
├── reports/                    # Synthesis & implementation reports
│   ├── timing_summary.rpt
│   ├── utilization_summary.rpt
│   └── drc_report.rpt
│
├── docs/                       # Documentation
│   └── pipeline_design.md      # Architecture & design notes
│
└── README.md
```

---

## Key Design Decisions

| Design Choice | Rationale |
|---|---|
| AXI4-Stream inter-stage | Enables modular, back-pressure-aware streaming between stages |
| Line-buffer convolution | Minimizes BRAM usage vs. full-frame buffering |
| Fixed-point arithmetic | Avoids floating-point overhead on FPGA fabric |
| Parameterized modules | Single RTL source scales across resolutions |

---

## Resource Utilization (Post-Implementation)

> Targeting Zynq XC7Z020-1CLG400C (PYNQ-Z2)

| Resource | Used | Available | Utilization |
|---|---|---|---|
| LUT | TBD | 53,200 | – |
| FF | TBD | 106,400 | – |
| BRAM | TBD | 140 | – |
| DSP48E1 | TBD | 220 | – |

*To be updated after final implementation.*

---

## Getting Started

### Prerequisites

- Vivado 2025.2 (with Zynq device support)
- PYNQ-Z2 board with PYNQ v3.x image
- Python 3.10+ with `pynq`, `numpy`, `Pillow`, `matplotlib`

### 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/fpga-image-pipeline.git
cd fpga-image-pipeline
```

### 2. Recreate the Vivado Project

```bash
cd vivado
vivado -mode batch -source scripts/build.tcl
```

Or open Vivado GUI → Tools → Run Tcl Script → `vivado/bd/pipeline_bd.tcl`

### 3. Run Simulation

Open the project in Vivado, set the desired testbench as top, and run XSim:

```bash
# Example: simulate Gaussian filter stage
xvlog rtl/gaussian_filter.v tb/tb_gaussian.v
xelab tb_gaussian -debug all
xsim tb_gaussian -gui
```

### 4. Program the Board & Run Demo

Transfer `notebooks/pipeline_demo.ipynb` to the PYNQ-Z2 and open it in the board's Jupyter server:

```
http://<pynq-ip>:9090
```

---

## Simulation Results

Line-buffer simulation was validated in XSim with correct pixel windowing behavior confirmed from the waveform output. Full pipeline testbench results to be added post-integration.

---

## Author

**Sahil Lahane**  
B.Tech Electronics & Communication Engineering (3rd Year)  
MIT World Peace University, Pune  
📧 sahillahane4@gmail.com | 📍 Pune, India  

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
