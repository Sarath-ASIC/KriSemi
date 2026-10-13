# AXI-Based Hardware Accelerator on Xilinx Zynq-7000 (xc7z020clg484-1)

**Project:** Build AXI Accelerator
**Platform:** Xilinx Zynq-7000 ZC702 Evaluation Board
**FPGA Device:** XC7Z020
**Development Tool:** AMD Xilinx Vivado
**Design Domain:** RTL Design, AXI4-Lite, FPGA-Based Acceleration
**Verification:** Verilog Testbench and Vivado XSim

---

## 1. Project Overview

This project implements a custom hardware accelerator connected to the ARM-based processing system of a Xilinx Zynq-7000 SoC through an AXI4-Lite interface.

The accelerator performs signed 2 × 2 matrix multiplication. Instead of executing every multiplication and addition as software instructions on the processor, the processor configures the accelerator through memory-mapped registers, starts the computation, and reads the results after completion.

The project explores the integration of custom RTL hardware into a processor-based FPGA system, covering AXI4-Lite slave design, register-mapped control, sequential arithmetic hardware, functional verification, and the FPGA implementation flow.

### Project status

- **RTL simulation:** Passed the documented positive and signed-negative matrix multiplication tests.
- **Register verification:** Operand register readback and reset behavior tested.
- **Block design:** Created and structurally validated.
- **Synthesis and implementation:** Further checks required, including resolution of outstanding I/O constraint warnings.
- **FPGA hardware demonstration:** Pending confirmation.
- **Processor firmware and GUI integration:** Planned extensions.

> Simulation results establish the behavior of the tested RTL under the tested conditions. They do not, by themselves, establish successful FPGA programming or physical hardware operation.

---

## 2. Project Objectives

The main objectives are:

1. Design a custom AXI4-Lite slave using synthesizable Verilog.
2. Implement memory-mapped control and data registers.
3. Develop a sequential matrix multiplication engine.
4. Support signed 16-bit operands and 32-bit results.
5. Separate processor-side control from accelerator-side computation.
6. Verify AXI read/write transactions and arithmetic behavior using a testbench.
7. Integrate the accelerator into a Zynq-7000 Vivado block design.
8. Understand the transition from RTL simulation to synthesis, implementation, and FPGA programming.
9. Establish a foundation for future processor firmware and graphical-interface control.

---

## 3. System Architecture

The intended system consists of a Zynq Processing System (PS), an AXI interconnect, reset and clock infrastructure, and a custom hardware accelerator in the Programmable Logic (PL).

```text
              Host PC / GUI
                   |
          UART / Future Interface
                   |
          ARM Cortex-A9 Processor
             Zynq Processing System
                   |
              AXI Master
                   |
          AXI Interconnect
          / SmartConnect
                   |
              AXI4-Lite
                   |
        +------------------------+
        | AXI Accelerator Slave  |
        |                        |
        | Control Registers      |
        | Operand Registers      |
        | Matrix Multiply Engine |
        | Result Registers       |
        | Status Registers       |
        +------------------------+
                   |
             Computation
                   |
          Results in Registers
```

The host-PC/GUI path represents the planned software interface; it should not be considered a completed integration until firmware and communication have been tested.

### 3.1 Processing System (PS)

The Zynq Processing System contains the ARM Cortex-A9 processing subsystem and provides the processor-side interface to the programmable logic.

Its intended responsibilities are:

- Configure operand registers.
- Start accelerator operations.
- Poll completion status.
- Read computation results.
- Eventually communicate with a host PC or GUI through a supported interface.

### 3.2 AXI interconnect / SmartConnect

The interconnect connects the processor's AXI master interface to the accelerator's AXI4-Lite slave interface.

It routes memory-mapped transactions to the appropriate peripheral address range.

### 3.3 Processor System Reset

The `proc_sys_reset_0` block provides reset signals for the integrated design. Its reset connections must be consistent with the selected PS clock and reset configuration.

### 3.4 Custom AXI4-Lite accelerator

The custom RTL module, `axi_accelerator_slave`, provides the memory-mapped interface and the matrix multiplication datapath.

Its responsibilities include:

- Accepting AXI write-address and write-data transactions.
- Updating operand and control registers.
- Returning AXI write responses.
- Accepting read-address transactions.
- Returning operand, status, and result values.
- Executing the matrix multiplication operation.
- Indicating when computation is busy or complete.

### 3.5 Clocking

The block design uses the Zynq PS fabric clock, `FCLK_CLK0`, as the source for the accelerator clock.

The configured clock frequency must be confirmed against the final block design and timing constraints. The testbench clock is a simulation clock and does not establish the maximum operating frequency of the synthesized hardware.

---

## 4. Matrix Multiplication Algorithm

The accelerator calculates the product of two 2 × 2 matrices:

[
A =
\begin{bmatrix}
A_0 & A_1 \\
A_2 & A_3
\end{bmatrix}
\qquad
B =
\begin{bmatrix}
B_0 & B_1 \\
B_2 & B_3
\end{bmatrix}
]

The output matrix is:

[
C = A \times B
]

The four results are calculated as follows:

[
C_0 = A_0B_0 + A_1B_2
]

[
C_1 = A_0B_1 + A_1B_3
]

[
C_2 = A_2B_0 + A_3B_2
]

[
C_3 = A_2B_1 + A_3B_3
]

### 4.1 Arithmetic implementation

The documented RTL implementation uses a shared signed 16 × 16 multiplier across sequential computation states.

The accelerator performs the required multiplications and accumulations over multiple clock cycles rather than calculating all eight products in parallel.

This architecture provides an opportunity to study the trade-off between hardware resource sharing, execution latency, and control complexity.

### 4.2 Operand and result widths

| Property                  |               Width |
| ------------------------- | ------------------: |
| Input operands            |       16-bit signed |
| Individual multiplication | Up to 32-bit signed |
| Accumulated result        |     32-bit register |
| AXI data bus              |             32 bits |

The 16-bit operands are interpreted as signed two's-complement values. Results are exposed as 32-bit values.

**Arithmetic limitation:** The mathematical sum of two signed 16 × 16 products can exceed the signed 32-bit range for extreme input values. The current result width does not guarantee overflow-free arithmetic for every possible operand combination. Wider accumulation or explicit overflow handling would be needed if full-range mathematical correctness is required.

---

## 5. Memory-Mapped Register Map

The accelerator is controlled through an AXI4-Lite register interface.

The configured Vivado Address Editor assignment is:

- **Base address:** `0x40000000`
- **Address range:** `0x40000000`–`0x40000FFF`
- **Mapped region size:** 4 KB

The local RTL register decoder uses the following byte offsets.

| Offset | Register  | Access     | Description                |
| ------ | --------- | ---------- | -------------------------- |
| `0x00` | `A0`      | Read/Write | Matrix A, row 0, column 0  |
| `0x04` | `A1`      | Read/Write | Matrix A, row 0, column 1  |
| `0x08` | `A2`      | Read/Write | Matrix A, row 1, column 0  |
| `0x0C` | `A3`      | Read/Write | Matrix A, row 1, column 1  |
| `0x10` | `B0`      | Read/Write | Matrix B, row 0, column 0  |
| `0x14` | `B1`      | Read/Write | Matrix B, row 0, column 1  |
| `0x18` | `B2`      | Read/Write | Matrix B, row 1, column 0  |
| `0x1C` | `B3`      | Read/Write | Matrix B, row 1, column 1  |
| `0x20` | `CONTROL` | Write      | Bit 0 starts a computation |
| `0x24` | `STATUS`  | Read       | Bit 0 = DONE; bit 1 = BUSY |
| `0x28` | `C0`      | Read       | Result matrix element C0   |
| `0x2C` | `C1`      | Read       | Result matrix element C1   |
| `0x30` | `C2`      | Read       | Result matrix element C2   |
| `0x34` | `C3`      | Read       | Result matrix element C3   |

All offsets are byte addresses relative to the peripheral base address.

### 5.1 Register access examples

The effective address is:

[
\text{Address} = \text{Base Address} + \text{Register Offset}
]

For example:

| Operation         | Address      |
| ----------------- | ------------ |
| Write `A0`        | `0x40000000` |
| Write `B0`        | `0x40000010` |
| Start computation | `0x40000020` |
| Read status       | `0x40000024` |
| Read `C0`         | `0x40000028` |

These addresses apply to the documented Address Editor assignment. Recheck the final Vivado address map before using them in firmware.

### 5.2 Control register

Writing bit 0 as `1` to `CONTROL` requests a new matrix multiplication operation.

The operation is initiated through the RTL control logic. Software should not assume that writing the start bit means the result is immediately available.

### 5.3 Status register

| Bit | Name   | Meaning                               |
| --- | ------ | ------------------------------------- |
| 0   | `DONE` | Computation has completed             |
| 1   | `BUSY` | Accelerator is executing an operation |

Software can poll the status register until `DONE` becomes `1` and `BUSY` becomes `0`.

The exact clearing and restart behavior should be checked against the RTL before software relies on repeated-operation semantics.

---

## 6. RTL Implementation

### 6.1 AXI4-Lite slave interface

The interface contains the standard AXI4-Lite channels:

- **Write address:** `AWADDR`, `AWVALID`, `AWREADY`
- **Write data:** `WDATA`, `WSTRB`, `WVALID`, `WREADY`
- **Write response:** `BRESP`, `BVALID`, `BREADY`
- **Read address:** `ARADDR`, `ARVALID`, `ARREADY`
- **Read data and response:** `RDATA`, `RRESP`, `RVALID`, `RREADY`

The RTL handles write-address and write-data capture independently. It applies byte strobes when updating operand registers and generates write responses after processing transactions.

The read path returns values from the mapped registers.

### 6.2 Sequential computation engine

The arithmetic engine uses sequential states to perform the required multiplications and additions using a shared multiplier.

The control logic tracks the current operation and updates the result registers. The `BUSY` and `DONE` signals provide operation-status feedback.

### 6.3 Reset behavior

The documented testbench checks that reset clears operand registers.

Reset behavior for all state, status, and result registers should be kept consistent with the intended hardware specification and verified as the RTL evolves.

---

## 7. Verification and Simulation

The accelerator was tested using a Verilog testbench in Vivado XSim.

The testbench contains AXI write and read tasks to exercise the memory-mapped interface and verify computation results.

### 7.1 Verification summary

| Test                           | Purpose                                               | Recorded result |
| ------------------------------ | ----------------------------------------------------- | --------------- |
| Operand register access        | Write and read operands                               | PASS            |
| Reset behavior                 | Confirm operand registers clear after reset           | PASS            |
| Positive matrix multiplication | Verify standard matrix product                        | PASS            |
| Signed negative multiplication | Verify negative operands and two's-complement results | PASS            |
| Completion status              | Verify `DONE=1` and `BUSY=0` at completion            | PASS            |

These results reflect the recorded simulation run. They do not represent exhaustive verification of every AXI protocol corner case or every arithmetic input combination.

### 7.2 Positive test case

Input matrices:

[
A =
\begin{bmatrix}
1 & 2 \\
3 & 4
\end{bmatrix}
\qquad
B =
\begin{bmatrix}
5 & 6 \\
7 & 8
\end{bmatrix}
]

Expected result:

[
C =
\begin{bmatrix}
19 & 22 \\
43 & 50
\end{bmatrix}
]

Recorded output:

| Result | Expected | Recorded |
| ------ | -------: | -------: |
| `C0`   |       19 |       19 |
| `C1`   |       22 |       22 |
| `C2`   |       43 |       43 |
| `C3`   |       50 |       50 |

**Result: PASS**

### 7.3 Signed negative test case

Input matrices:

[
A =
\begin{bmatrix}
-1 & -2 \\
-3 & -4
\end{bmatrix}
\qquad
B =
\begin{bmatrix}
5 & 6 \\
7 & 8
\end{bmatrix}
]

Expected result:

[
C =
\begin{bmatrix}
-19 & -22 \\
-43 & -50
\end{bmatrix}
]

The corresponding 32-bit two's-complement hexadecimal values are:

| Result | Decimal | 32-bit hexadecimal |
| ------ | ------: | ------------------ |
| `C0`   |     -19 | `0xFFFFFFED`       |
| `C1`   |     -22 | `0xFFFFFFEA`       |
| `C2`   |     -43 | `0xFFFFFFD5`       |
| `C3`   |     -50 | `0xFFFFFFCE`       |

**Result: PASS**

### 7.4 Additional verification recommended

The current testbench can be extended with:

- Independent AW and W channel timing.
- Randomized AXI backpressure.
- Byte-strobe verification.
- Invalid or unmapped address behavior.
- Reset during an active computation.
- Back-to-back operations.
- Boundary-value and overflow testing.
- Assertions for AXI protocol properties.
- Functional coverage for registers, transactions, and arithmetic cases.

---

## 8. Vivado Block Design

The block design is named `axi_accl_bd`.

The documented design contains:

| Component                 | Purpose                        |
| ------------------------- | ------------------------------ |
| `processing_system7_0`    | Zynq processing system         |
| `smartconnect_0`          | AXI interconnect               |
| `proc_sys_reset_0`        | Clock and reset infrastructure |
| `axi_accelerator_slave_0` | Custom AXI accelerator         |

The custom accelerator is added as an RTL module within the block design.

### 8.1 Integration checks

Before proceeding to implementation, confirm that:

- The PS AXI master is connected to the interconnect.
- The interconnect master connects to the accelerator's AXI slave interface.
- The clock is connected consistently to all required interfaces.
- Reset polarity matches the connected IP and RTL.
- The address map includes the accelerator.
- The generated HDL wrapper is selected as the synthesis top-level design.
- The block design passes validation.

### 8.2 Address assignment

The recorded address assignment is `0x40000000` with a 4 KB address range.

The peripheral's local register decoder only uses the documented offsets through `0x34`; the full 4 KB region is the assigned address window, not the number of implemented registers.

---

## 9. Build and Implementation Workflow

The intended development flow is:

1. Create and review the accelerator RTL.
2. Create the Verilog testbench.
3. Run behavioral simulation.
4. Confirm expected results and status behavior.
5. Create the Zynq block design.
6. Add the accelerator RTL module.
7. Connect clock, reset, and AXI interfaces.
8. Assign the peripheral address range.
9. Validate the block design.
10. Create the HDL wrapper and select it as the design top.
11. Run synthesis and review warnings.
12. Apply appropriate board-level constraints.
13. Run implementation.
14. Review timing and design-rule reports.
15. Generate the bitstream.
16. Develop processor firmware.
17. Test the accelerator on the ZC702 hardware.
18. Add host-PC/GUI control if required.

Steps involving final implementation, bitstream generation, and hardware testing should be marked complete only after successful execution and evidence collection.

---

## 10. Synthesized Netlist and Hardware Reports

After successful synthesis, Vivado can produce a synthesized netlist for inspection.

A Verilog netlist can be exported from the Tcl Console after opening the synthesized design:

```tcl
write_verilog -force C:/Users/YourName/Desktop/axi_accelerator_netlist.v
```

Replace the path with a valid destination on the development laptop.

Other useful reports include:

- Synthesis utilization.
- Timing summary.
- Critical path report.
- Clock utilization.
- Implementation design-rule checks.

A synthesized netlist is not the same as a bitstream. The netlist represents synthesized hardware logic; the bitstream configures the FPGA.

---

## 11. Repository Structure

A suggested repository layout is:

```text
axi-based-hardware-accelerator/
├── README.md
├── rtl/
│   └── axi_accelerator_slave.v
├── sim/
│   └── tb_axi_accelerator_slave.v
├── constraints/
│   └── zc702_constraints.xdc
├── vivado/
│   └── axi_accel_bd/
├── firmware/
│   └── README.md
├── gui/
│   └── README.md
├── reports/
│   ├── synthesis/
│   └── timing/
└── docs/
    └── architecture.md
```

This is a recommended organization, not a claim about the current on-disk directory structure. Update the paths to match the actual repository.

Generated files should be committed selectively. Preserve the source RTL, testbench, constraints, and reproducibility information. Avoid committing large temporary build directories unless there is a specific reason.

---

## 12. Future Improvements

Potential next steps include:

1. Complete the ZC702 board-level implementation.
2. Resolve all relevant design-rule and timing issues.
3. Add processor firmware to configure and control the accelerator.
4. Create a host-PC interface for entering matrices and displaying results.
5. Add a reliable processor-to-GUI communication protocol.
6. Add error and timeout handling in the software driver.
7. Expand testbench coverage and add protocol assertions.
8. Measure accelerator latency and compare it with a software implementation.
9. Inspect FPGA resource utilization and timing.
10. Evaluate wider accumulators, pipelining, and alternative multiplier architectures.

---

# Appendix A — Important Engineering Notes

This appendix records details that must be checked before treating the design as a completed FPGA demonstration.

## A.1 Vivado I/O constraint warnings

The recorded Vivado design-rule report contained two critical warnings:

- `NSTD-1`: 92 logical ports used the default `IOSTANDARD`.
- `UCIO-1`: 92 logical ports had no explicit `LOC` assignment.

These warnings indicate missing I/O constraints on top-level ports. They are not, by themselves, proof of an error in the matrix multiplication logic.

**Required action:**

1. Verify that the block-design HDL wrapper is the synthesis top.
2. Inspect the actual top-level ports.
3. Determine which ports are intended to connect to physical board pins.
4. Apply the correct ZC702 pin assignments and electrical standards where necessary.
5. Rerun the relevant design-rule checks.

Do not suppress these warnings merely to force bitstream generation.

## A.2 ZC702 pin assignments

Pin locations and electrical standards must come from the correct ZC702 board documentation and the actual interface being implemented.

Do not assign arbitrary FPGA pins or apply a blanket `LVCMOS33` setting to every port. Incorrect constraints can cause electrical incompatibility and may damage connected hardware.

AXI signals between the PS interconnect and the custom accelerator should normally remain internal to the FPGA design rather than become external board pins.

## A.3 HDL wrapper and synthesis top

A Block Design (`.bd`) is not selected as the top-level HDL source in the same way as a regular Verilog module.

Generate the HDL wrapper for `axi_accl_bd` and select the generated wrapper as the top-level module when required by the Vivado project flow.

Confirm the actual hierarchy before rerunning synthesis.

## A.4 Base address

The recorded address assignment is:

```text
Base address : 0x40000000
Address range: 0x40000000–0x40000FFF
```

Use the base address plus the register offset when accessing the peripheral from processor software.

Do not assume the address remains unchanged after editing the block design. Always recheck the Address Editor.

## A.5 Simulation is not hardware validation

Passing behavioral simulation does not prove that:

- The complete block design synthesizes correctly.
- The final implementation meets timing.
- The FPGA bitstream is generated successfully.
- The processor can access the accelerator on the board.
- UART or GUI communication works.
- The hardware operates correctly under all possible conditions.

Each stage needs its own validation.

## A.6 Arithmetic range

The operands are signed 16-bit values, and the results are stored in 32-bit registers.

The sum of two products may overflow a signed 32-bit result for extreme inputs. If full-range correctness is required, use wider intermediate accumulation and define how results are represented or how overflow is reported.

## A.7 AXI protocol coverage

The existing tests cover basic reads and writes and the documented arithmetic scenarios. They do not establish complete AXI4-Lite protocol compliance.

Additional tests should cover independent address/data arrival, response backpressure, repeated requests, reset interactions, and byte strobes.

## A.8 Clock and timing constraints

The PS fabric clock configuration and the testbench clock are different concepts.

The final clock period must be based on the intended operating frequency and supported by implementation timing reports. Do not infer a maximum safe clock frequency from behavioral simulation alone.

## A.9 Firmware and GUI status

Processor firmware and a host-PC GUI are planned extensions. Their implementation, communication path, and successful operation should be documented only after they are developed and tested.

## A.10 Reproducibility

Record the Vivado version, target FPGA part, board revision where relevant, clock configuration, address map, constraint files, simulation commands, and final implementation reports.

Keep source files and testbenches under version control so that the design can be recreated and reviewed.

---

## Appendix B — Final Completion Checklist

- [ ] RTL reviewed and version-controlled.
- [ ] Behavioral simulation passes.
- [ ] AXI protocol corner cases tested.
- [ ] Block design validated.
- [ ] HDL wrapper generated.
- [ ] Correct synthesis top selected.
- [ ] I/O constraint warnings investigated and resolved as applicable.
- [ ] Synthesis completed successfully.
- [ ] Resource utilization reviewed.
- [ ] Implementation completed successfully.
- [ ] Timing requirements met.
- [ ] Bitstream generated.
- [ ] ZC702 hardware programming verified.
- [ ] Processor firmware implemented and tested.
- [ ] Host-PC/GUI communication verified, if included.
- [ ] Final reports and test evidence archived.

---

## Conclusion

This project provides a foundation for integrating custom RTL computation hardware with a processor-based FPGA system. It combines memory-mapped control, AXI4-Lite transactions, sequential arithmetic, functional simulation, and a practical FPGA implementation workflow.

The documented simulation results demonstrate correct behavior for the tested matrix multiplication cases. Completing the remaining implementation, constraint, firmware, and hardware-validation stages will turn the design into a fully demonstrated Zynq-based hardware accelerator.
