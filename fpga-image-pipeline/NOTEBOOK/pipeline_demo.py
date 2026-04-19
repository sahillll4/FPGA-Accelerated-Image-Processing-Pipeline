"""
FPGA Image Processing Pipeline — PYNQ Z2 Demo
==============================================
Run this notebook on your PYNQ Z2 board via Jupyter.

Requirements:
  - pipeline.bit and pipeline.hwh in the same folder as this notebook
  - A test image (test_image.jpg) or use the synthetic one generated below
  - pip install opencv-python (already on PYNQ image)
"""

# ============================================================
# Cell 1 — Imports and overlay load
# ============================================================
import numpy as np
import cv2
import time
import matplotlib.pyplot as plt
from pynq import Overlay, allocate
from pynq.lib import AxiGPIO

# Load the bitstream onto the FPGA
overlay = Overlay("pipeline.bit")
print("Bitstream loaded successfully")
print(overlay.ip_dict.keys())   # shows all IP blocks found

# ============================================================
# Cell 2 — Get handles to DMA and GPIO
# ============================================================
dma      = overlay.axi_dma_0          # AXI DMA handle
gpio_ip  = overlay.axi_gpio_0         # Threshold GPIO handle

# Configure thresholds via GPIO
# Lower 8 bits  = NMS threshold (suppress weak edges)
# Upper 8 bits  = Feature threshold (detect strong edges)
NMS_THRESHOLD     = 30    # adjust this for your image
FEATURE_THRESHOLD = 80    # adjust this for your image

threshold_val = (FEATURE_THRESHOLD << 8) | NMS_THRESHOLD
gpio_ip.channel1.write(threshold_val, 0xFFFF)
print(f"NMS threshold     : {NMS_THRESHOLD}")
print(f"Feature threshold : {FEATURE_THRESHOLD}")

# ============================================================
# Cell 3 — Load and prepare image
# ============================================================
IMG_W = 320
IMG_H = 240

# Option A: Use a real image
# img_bgr = cv2.imread("test_image.jpg")
# img_gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
# img_gray = cv2.resize(img_gray, (IMG_W, IMG_H))

# Option B: Synthetic test image (horizontal stripe — guaranteed edges)
img_gray = np.ones((IMG_H, IMG_W), dtype=np.uint8) * 20
img_gray[100:140, :] = 200   # bright horizontal stripe
print(f"Image shape: {img_gray.shape}, dtype: {img_gray.dtype}")

plt.figure(figsize=(6,4))
plt.imshow(img_gray, cmap='gray')
plt.title("Input image (greyscale)")
plt.axis('off')
plt.show()

# ============================================================
# Cell 4 — Allocate DMA buffers and run FPGA pipeline
# ============================================================
# Flatten image to 1D array of uint32 (AXI DMA transfers 32-bit words)
pixels_in  = img_gray.flatten().astype(np.uint32)
pixels_out = np.zeros(IMG_W * IMG_H, dtype=np.uint32)

# Allocate physically contiguous memory buffers
input_buffer  = allocate(shape=(IMG_W * IMG_H,), dtype=np.uint32)
output_buffer = allocate(shape=(IMG_W * IMG_H,), dtype=np.uint32)

# Copy image into DMA input buffer
input_buffer[:] = pixels_in

# --- Run FPGA pipeline and measure time ---
t_start = time.perf_counter()

dma.sendchannel.transfer(input_buffer)
dma.recvchannel.transfer(output_buffer)
dma.sendchannel.wait()
dma.recvchannel.wait()

t_fpga = (time.perf_counter() - t_start) * 1000  # ms

# Copy results out
pixels_out = np.array(output_buffer).astype(np.uint8)
edge_map   = pixels_out.reshape(IMG_H, IMG_W)

print(f"FPGA inference time : {t_fpga:.2f} ms")

# ============================================================
# Cell 5 — Run OpenCV on ARM CPU for comparison
# ============================================================
t_start = time.perf_counter()

# Equivalent software pipeline
img_blur   = cv2.GaussianBlur(img_gray, (3,3), 0)
edges_cv   = cv2.Canny(img_blur, NMS_THRESHOLD, FEATURE_THRESHOLD)

t_cpu = (time.perf_counter() - t_start) * 1000  # ms

print(f"CPU  inference time : {t_cpu:.2f} ms")
speedup = t_cpu / t_fpga if t_fpga > 0 else 0
print(f"FPGA speedup        : {speedup:.1f}x faster than ARM CPU")

# ============================================================
# Cell 6 — Display results side by side
# ============================================================
fig, axes = plt.subplots(1, 3, figsize=(15, 4))

axes[0].imshow(img_gray, cmap='gray')
axes[0].set_title("Original image")
axes[0].axis('off')

axes[1].imshow(edge_map, cmap='gray')
axes[1].set_title(f"FPGA edge output\n({t_fpga:.1f} ms)")
axes[1].axis('off')

axes[2].imshow(edges_cv, cmap='gray')
axes[2].set_title(f"OpenCV CPU reference\n({t_cpu:.1f} ms)")
axes[2].axis('off')

plt.suptitle(f"FPGA Speedup: {speedup:.1f}x  |  PYNQ Z2 @ 100MHz", fontsize=13)
plt.tight_layout()
plt.savefig("result.png", dpi=150, bbox_inches='tight')
plt.show()
print("Result saved to result.png")

# ============================================================
# Cell 7 — Feature point overlay
# ============================================================
# Detect feature points from the FPGA edge map
# (strong pixels above feature_threshold)
feature_mask = (edge_map >= FEATURE_THRESHOLD)
feature_coords = np.argwhere(feature_mask)  # returns [row, col] pairs
print(f"Feature points detected by FPGA : {len(feature_coords)}")

# Draw feature points on original image
img_overlay = cv2.cvtColor(img_gray, cv2.COLOR_GRAY2BGR)
for (row, col) in feature_coords:
    cv2.circle(img_overlay, (col, row), 2, (0, 255, 0), -1)

plt.figure(figsize=(7, 5))
plt.imshow(cv2.cvtColor(img_overlay, cv2.COLOR_BGR2RGB))
plt.title(f"Feature points detected: {len(feature_coords)}")
plt.axis('off')
plt.show()

# ============================================================
# Cell 8 — Clean up DMA buffers
# ============================================================
input_buffer.freebuffer()
output_buffer.freebuffer()
print("Buffers freed. Demo complete.")

# ============================================================
# Summary print
# ============================================================
print("\n========== RESULTS ==========")
print(f"Image size        : {IMG_W} x {IMG_H}")
print(f"FPGA time         : {t_fpga:.2f} ms")
print(f"CPU time          : {t_cpu:.2f} ms")
print(f"Speedup           : {speedup:.1f}x")
print(f"Feature points    : {len(feature_coords)}")
print("==============================")
