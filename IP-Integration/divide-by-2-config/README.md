# Libero SoC — IP-Based Clock Divider

## 1. Project Overview

This project implements a **100 MHz to 50 MHz clock divider using the SmartFusion2 Clock Conditioning Circuit (CCC) IP** in Microchip Libero SoC.

The main objective is not simply to produce a divided clock, but to demonstrate the correct **FPGA IP-integration flow**:

```text
CCC IP
  ↓
SmartDesign
  ↓
Generated SmartDesign Component
  ↓
Verilog Design Wrapper / Top
  ↓
Verilog Testbench
  ↓
Pre-Synthesis Simulation
```

The design uses the FPGA's dedicated clock-management resources rather than implementing clock division with ordinary RTL logic.

---

## 2. Target Platform and Tools

| Item | Specification |
|---|---|
| FPGA Family | Microchip SmartFusion2 |
| Device | M2S005-1FG484 |
| Package | 484 FBGA |
| Core Voltage | 1.2 V |
| FPGA Tool | Microchip Libero SoC 2026.1 |
| HDL | Verilog |
| Clock IP | Clock Conditioning Circuit (CCC) |
| CCC Version | 2.0.201 |
| Simulation | Questa/ModelSim-compatible flow |

---

# 3. Design Specification

## 3.1 Functional Requirement

The design shall accept a **100 MHz reference clock** and generate a **50 MHz output clock** using the SmartFusion2 CCC.

### Clock specification

```text
Input Clock  : 100 MHz
Input Period : 10 ns

Output Clock : 50 MHz
Output Period: 20 ns

Frequency Division:
                  100 MHz
                  ------- = 2
                   50 MHz
```

The CCC `GL0` output is configured for an **exact 50 MHz target**, and Libero reports an actual output frequency of **50.00 MHz**.

The design also exposes the CCC `LOCK` indication as `locked`.

---

# 4. Why Use the CCC IP?

A clock divider can be written using ordinary RTL logic, for example by toggling a register every input-clock edge. That approach is useful for understanding digital logic, but it is not the preferred architecture when the requirement is to generate a clock for use as an FPGA clock.

This project therefore uses the **dedicated Clock Conditioning Circuit (CCC)**.

## 4.1 Reason for the Architecture

The important distinction is:

```text
RTL Clock Divider
-----------------

100 MHz
   │
   ▼
counter / flip-flop
   │
   ▼
divided signal
```

versus:

```text
CCC-Based Clock Generation
--------------------------

100 MHz
   │
   ▼
Dedicated FPGA Clock Resource
   │
   ▼
50 MHz Clock
```

The CCC-based implementation is preferred because the generated signal is intended to function as a **clock**, not merely as a divided data/control signal.

Using the dedicated clock-management resource allows the FPGA architecture to handle clock generation and distribution using resources specifically designed for that purpose.

### Design principle

> **Do not treat a generated clock as an ordinary data signal when the FPGA provides dedicated clock-management resources for generating it.**

This is the primary reason for using the CCC IP in this project.

---

# 5. CCC Configuration

The instantiated IP is:

```text
Clock & Management
└── Clock Conditioning Circuit (CCC)
```

The CCC is configured as follows:

```text
Reference Clock
    = 100 MHz

GL0
    = Enabled

GL0 Target Frequency
    = 50 MHz

Actual GL0 Frequency
    = 50.00 MHz

GL1
    = Disabled

GL2
    = Disabled

GL3
    = Disabled
```

Only `GL0` is required because the design needs a single generated clock.

The other global-clock outputs are therefore left unused.

---

# 6. Interface Specification

The final design exposes three top-level ports.

| Port | Direction | Description |
|---|---|---|
| `clk_in` | Input | 100 MHz reference clock |
| `clk_out` | Output | 50 MHz generated clock |
| `locked` | Output | CCC lock indication |

Conceptually:

```text
                 ┌─────────────────────┐
                 │                     │
clk_in ─────────►│     CCC / SCLK_0    │──────► clk_out
 100 MHz          │                     │         50 MHz
                 │                     │
                 │                     │──────► locked
                 └─────────────────────┘
```

---

# 7. Design Hierarchy

The project intentionally separates the **IP**, **design wrapper**, and **testbench**.

```text
clock_div_tb
     │
     ▼
clock_div
     │
     ▼
SCLK_0
     │
     ▼
SCLK / CCC IP
```

## 7.1 CCC IP

The actual clock-generation function is implemented by the SmartFusion2 CCC.

```text
SCLK_0
└── SCLK / CCC
```

The CCC is responsible for producing the configured 50 MHz clock.

## 7.2 Design Top / Wrapper

The generated SmartDesign component is represented by:

```text
clock_div
```

The Verilog wrapper has the following interface:

```verilog
module clock_div (
    input  wire clk_in,
    output wire clk_out,
    output wire locked
);
```

The CCC instance is connected as:

```verilog
SCLK SCLK_0 (
    .CLK0_PAD (clk_in),
    .GL0      (clk_out),
    .LOCK     (locked)
);
```

Thus, the wrapper provides a clean RTL interface around the Libero-generated clock IP.

---

# 8. Why Use a Wrapper?

The wrapper provides a useful abstraction boundary.

Instead of making the rest of the project depend directly on the internal CCC implementation:

```text
Application Logic
       │
       ▼
     SCLK
```

the design exposes a simple interface:

```text
Application Logic
       │
       ▼
   clock_div
       │
       ▼
      CCC
```

This makes the IP easier to integrate into larger RTL designs and keeps the FPGA-specific implementation contained inside the wrapper.

It also creates a clean boundary if the clock-generation implementation needs to be changed later.

---

# 9. Testbench Architecture

The testbench is kept outside the design hierarchy.

```text
Simulation Root
└── clock_div_tb
      │
      ▼
   clock_div
      │
      ▼
    SCLK_0
      │
      ▼
     CCC
```

The testbench generates the 100 MHz reference clock:

```text
Clock period = 10 ns
Half period  = 5 ns
```

Example clock generation:

```verilog
initial begin
    clk_in = 1'b0;

    forever begin
        #5 clk_in = ~clk_in;
    end
end
```

The testbench instantiates the design top rather than directly instantiating the CCC.

This is intentional:

```text
Correct:

clock_div_tb
     │
     ▼
clock_div
     │
     ▼
CCC


Avoid:

clock_div_tb
     │
     ▼
CCC
```

The first structure verifies the actual design hierarchy that will be used by the implementation flow.

---

# 10. Expected Functional Behavior

After applying a 100 MHz reference clock:

```text
clk_in

__|‾|__|‾|__|‾|__|‾|__|‾|__
  10 ns period
```

the CCC should produce:

```text
clk_out

____|‾‾‾|____|‾‾‾|____|‾‾‾|
       20 ns period
```

Therefore:

```text
Tclk_in  = 10 ns
Tclk_out = 20 ns

Fclk_in  = 100 MHz
Fclk_out = 50 MHz
```

The `locked` signal indicates that the CCC has achieved its required lock condition.

The testbench should allow sufficient simulation time for the CCC model to establish lock before evaluating steady-state clock behavior.

---

# 11. Verification Objectives

The simulation should verify at least the following:

### 11.1 Input clock

Confirm that:

```text
clk_in = 100 MHz
```

### 11.2 Output clock

Confirm that:

```text
clk_out = 50 MHz
```

### 11.3 Frequency relationship

Confirm:

```text
Fout = Fin / 2
```

### 11.4 Lock indication

Observe that:

```text
locked
```

transitions to the active lock state after the CCC has stabilized.

### 11.5 Hierarchy

Verify that the simulation follows:

```text
clock_div_tb
    ↓
clock_div
    ↓
SCLK_0 / CCC
```

---

# 12. Design Decisions

## Decision 1 — Use CCC instead of an RTL counter

**Reason:** The output is intended to be a clock. Dedicated FPGA clock-management resources are more appropriate than creating a fabric-generated clock using ordinary flip-flops.

## Decision 2 — Use only GL0

**Reason:** The design requires only one generated clock.

## Decision 3 — Configure an exact 50 MHz output

**Reason:** The requirement is a clean divide-by-two relationship from the 100 MHz reference.

## Decision 4 — Expose LOCK

**Reason:** Downstream logic may need an indication that the generated clock-management circuit has reached its valid operating condition.

## Decision 5 — Keep the testbench outside the design

**Reason:** The design should remain synthesizable and independent of simulation stimulus.

---

# 13. Project Structure

A logical project organization is:

```text
project/
│
├── README.md
│
├── rtl/
│   └── clock_div.v
│
├── tb/
│   └── clock_div_tb.v
│
└── Libero/
    └── clock_div SmartDesign / generated IP files
```

The exact generated-file locations are controlled by Libero SoC.

---

# 14. Important FPGA Design Note

This project demonstrates an important difference between **functional RTL clock division** and **FPGA clock generation**.

An RTL implementation such as:

```verilog
always @(posedge clk_in)
    clk_out <= ~clk_out;
```

can mathematically produce a divide-by-two waveform, but that does not automatically make it the best clock source for other synchronous FPGA logic.

For FPGA designs, clock generation should generally use the device's dedicated clock resources whenever available.

Therefore, this project is intentionally built around:

```text
100 MHz reference
       │
       ▼
Dedicated CCC
       │
       ▼
50 MHz global clock
```

rather than:

```text
100 MHz
   │
   ▼
RTL flip-flop
   │
   ▼
fabric-generated clock
```

---

# 15. Project Outcome

The completed project demonstrates:

- SmartFusion2 project creation in Libero SoC
- IP Catalog usage
- CCC IP instantiation
- Clock-frequency configuration
- SmartDesign integration
- Top-level port promotion and naming
- SmartDesign component generation
- Verilog wrapper integration
- Design hierarchy construction
- Simulation/testbench hierarchy construction
- IP-based clock generation methodology

The resulting architecture provides a **100 MHz → 50 MHz clock-generation path using the SmartFusion2 CCC**.

---

## 16. Summary

```text
                   SMARTFUSION2
              ┌─────────────────────┐
              │                     │
100 MHz ─────►│       CCC IP        │
              │      SCLK_0         │
              │                     │
              │   GL0 = 50 MHz     ├────► clk_out
              │                     │
              │   LOCK             ├────► locked
              └─────────────────────┘
```

The key architectural choice is the use of the **dedicated CCC clock resource** rather than implementing the clock divider as ordinary RTL logic. This makes the project representative of a practical FPGA clock-management flow rather than only a digital divide-by-two exercise.
