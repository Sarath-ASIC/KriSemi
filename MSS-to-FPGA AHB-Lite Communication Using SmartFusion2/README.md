# MSS-to-FPGA AHB-Lite Communication Using SmartFusion2

## Project Overview

This project demonstrates **memory-mapped communication between the Microcontroller Subsystem (MSS) and custom FPGA fabric logic** in a Microchip SmartFusion2 device.

The ARM Cortex-M3-based MSS accesses a custom RTL peripheral implemented in the FPGA fabric through the **FIC_0 AHB-Lite Master interface**. A **CoreAHBLite interconnect** is used between the MSS master interface and the custom AHB-Lite slave.

The project was developed and verified in:

- **Microchip Libero SoC 2026.1**
- **QuestaSim Microchip Edition 2025.3**
- **SmartFusion2 MSS**
- **Verilog RTL**
- **AHB-Lite protocol**

The final simulation successfully verified multiple single-word register accesses and a sequential BRAM-style block read/write test.

---

# 1. Objective

The objective of this project is to implement and verify the following communication path:

```text
ARM Cortex-M3 MSS
       │
       │ Memory-Mapped AHB Transactions
       ▼
MSS FIC_0 AHB Master
       │
       ▼
CoreAHBLite Interconnect
       │
       ▼
Custom AHB-Lite Slave
       │
       ▼
Custom FPGA Memory / Register Logic

```

# 2. System Architecture

![System Architecture](images/Firmware_design_flow.png)


