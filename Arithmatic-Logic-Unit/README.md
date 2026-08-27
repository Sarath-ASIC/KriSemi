# 4-Bit ALU — Pre-Synthesis Simulation and Verification

## 1. Overview

This project implements and verifies a **4-bit Arithmetic Logic Unit (ALU)** using Verilog. The ALU supports eight operations selected using a 3-bit control signal.

The design was simulated using **QuestaSim Pro Microchip Edition** through the **Microchip Libero SoC pre-synthesis simulation flow**.

The verification process included:

1. Initial compilation and simulation setup.
2. Resolution of the simulation top-module mismatch.
3. Resolution of a QuestaSim license/session conflict.
4. Manual waveform-based testing.
5. Development of a self-checking testbench.
6. Investigation of waveform visibility issues.
7. Final successful simulation with all eight operations visible.
8. Verification using automatic PASS/FAIL checking.

---

# 2. ALU Interface

The ALU uses the following signals:

| Signal | Width | Description |
|---|---:|---|
| `a` | 4 bits | First operand |
| `b` | 4 bits | Second operand |
| `sel` | 3 bits | Operation select |
| `alu_out` | 4 bits | ALU result |

The ALU instance is connected to the testbench as:

```verilog
alu dut_01 (
    .a(a),
    .b(b),
    .sel(sel),
    .alu_out(alu_out)
);
```

---

# 3. Supported Operations

The 3-bit `sel` signal selects one of eight ALU operations.

| `sel` | Operation | Test Input | Expected Result |
|---|---|---|---|
| `000` | Addition | `3 + 2` | `5` |
| `001` | Subtraction | `8 - 3` | `5` |
| `010` | Multiplication | `3 × 2` | `6` |
| `011` | Division | `8 ÷ 2` | `4` |
| `100` | XOR | `1010 XOR 1100` | `0110` |
| `101` | NOT | `NOT 1010` | `0101` |
| `110` | Shift Left | `0011 << 1` | `0110` |
| `111` | Shift Right | `1100 >> 1` | `0110` |

---

# 4. Simulation Environment

The project was simulated using:

- **Microchip Libero SoC 2026.1**
- **QuestaSim Pro Microchip Edition-64 2025.3**
- **Verilog HDL**
- **Pre-Synthesis Simulation**

The simulation flow was:

```text
Verilog RTL
    │
    ▼
Compile DUT
    │
    ▼
Compile Testbench
    │
    ▼
Load Simulation Top Module
    │
    ▼
Run Simulation
    │
    ├── Waveform Analysis
    │
    └── Automatic PASS/FAIL Verification
```

---

# 5. Initial Simulation Issue: Top-Level Module Mismatch

The first simulation failed with the error:

```text
Could not find presynth.testbench
```

The DUT and testbench had compiled successfully, but the testbench module was originally named:

```verilog
module alu_sim;
```

However, the Libero-generated simulation script attempted to simulate:

```text
presynth.testbench
```

Therefore, the simulation top-level name did not match the actual testbench module.

## Resolution

The testbench module was renamed to:

```verilog
module testbench;
```

After matching the expected simulation top-level module name, the simulation loaded successfully.

### Inference

A Verilog source file can have any valid filename, but the **module name used as the simulation top must match the top-level module specified in the simulator configuration**.

For example:

```text
File name: alu_tb.v
Module name: testbench
Simulation top: testbench
```

This configuration is valid.

---

# 6. QuestaSim License Issue

During simulation, QuestaSim displayed a license error indicating that only one session could use the available node-locked license.

The issue occurred because another QuestaSim instance was already using the available license.

## Resolution

The existing QuestaSim sessions were closed and any remaining simulator processes were cleared before launching the pre-synthesis simulation again.

### Inference

The Microchip Edition license configuration may restrict the number of simultaneous simulator sessions. Running QuestaSim manually while Libero attempts to launch another simulation instance can result in a license checkout failure.

---

# 7. Manual Testbench Verification

A simple manual testbench was created to isolate the source of the waveform issue.

Each ALU operation was applied for:

```verilog
#10;
```

This produced a clear waveform:

```text
0 ns       ADDITION
10 ns      SUBTRACTION
20 ns      MULTIPLICATION
30 ns      DIVISION
40 ns      XOR
50 ns      NOT
60 ns      SHIFT LEFT
70 ns      SHIFT RIGHT
80 ns      END
```

The waveform successfully displayed all input and output transitions.

## Important Result

This experiment confirmed that:

- The ALU RTL was functioning correctly.
- Libero was compiling the design correctly.
- QuestaSim was recording signal transitions correctly.
- The waveform viewer was functioning correctly.

Therefore, the earlier waveform problem was **not caused by the ALU, Libero, or QuestaSim itself**.

---

# 8. Self-Checking Testbench

A reusable task was used to calculate the expected output and compare it with the DUT output.

The reference model used:

```verilog
case (sel)

    3'b000: expected = a + b;
    3'b001: expected = a - b;
    3'b010: expected = a * b;
    3'b011: expected = a / b;
    3'b100: expected = a ^ b;
    3'b101: expected = ~a;
    3'b110: expected = a << b;
    3'b111: expected = a >> b;

    default: expected = 4'b0000;

endcase
```

The expected output was then compared with the actual ALU output:

```verilog
if (expected === alu_out)
```

The counters:

```verilog
pass_count
fail_count
```

were used to record the number of successful and failed tests.

---

# 9. Waveform Visibility Issue

The original self-checking testbench used only:

```verilog
#1;
```

inside the verification task.

This caused the operations to occur very quickly:

```text
0–1 ns      ADDITION
1–2 ns      SUBTRACTION
2–3 ns      MULTIPLICATION
3–4 ns      DIVISION
4–5 ns      XOR
5–6 ns      NOT
6–7 ns      SHIFT LEFT
7–8 ns      SHIFT RIGHT
```

Although the simulation was functionally correct, the transitions were compressed into a very small time interval.

This made the waveform difficult to inspect, especially when the simulation viewer displayed a larger time range.

## Resolution

The verification timing was modified to separate:

1. DUT settling and checking.
2. Waveform visibility.

The final timing structure used:

```verilog
#1;   // Allow DUT response and perform checking
#9;   // Hold values before the next operation
```

This produced approximately:

```text
0–10 ns      ADDITION
10–20 ns     SUBTRACTION
20–30 ns     MULTIPLICATION
30–40 ns     DIVISION
40–50 ns     XOR
50–60 ns     NOT
60–70 ns     SHIFT LEFT
70–80 ns     SHIFT RIGHT
```

The final waveform clearly displayed all eight operations.

---

# 10. Key Verification Inference

An important lesson from this experiment is:

> **Functional correctness and waveform readability are different aspects of simulation.**

The original self-checking testbench could correctly verify the ALU even when the waveform was difficult to inspect.

The problem was not necessarily that the operations were missing. Instead, they occurred within a very short simulation interval.

Adding a hold period improved waveform readability without changing the functional verification methodology.

The final verification structure was:

```text
Apply Inputs
     │
     ▼
Wait 1 ns
     │
     ▼
Calculate / Compare Result
     │
     ├── PASS
     │
     └── FAIL
     │
     ▼
Hold Inputs for 9 ns
     │
     ▼
Apply Next Test Vector
```

---

# 11. Final Simulation Results

The final QuestaSim simulation produced the following results:

```text
Loading sv_std.std

# Loading work.testbench(fast)

# Loading work.alu(fast)

# PASS : a=0011 b=0010 sel=000 Expected=0101 Got=0101

# PASS : a=1000 b=0011 sel=001 Expected=0101 Got=0101

# PASS : a=0011 b=0010 sel=010 Expected=0110 Got=0110

# PASS : a=1000 b=0010 sel=011 Expected=0100 Got=0100

# PASS : a=1010 b=1100 sel=100 Expected=0110 Got=0110

# PASS : a=1010 b=0000 sel=101 Expected=0101 Got=0101

# PASS : a=0011 b=0001 sel=110 Expected=0110 Got=0110

# PASS : a=1100 b=0001 sel=111 Expected=0110 Got=0110

# ==============================================

# FINAL REPORT

# PASS = 8

# FAIL = 0

# ==============================================

# ALL TESTS PASSED
```

---

# 12. Test Summary

| Test | Operation | Status |
|---|---|---|
| 1 | Addition | PASS |
| 2 | Subtraction | PASS |
| 3 | Multiplication | PASS |
| 4 | Division | PASS |
| 5 | XOR | PASS |
| 6 | NOT | PASS |
| 7 | Shift Left | PASS |
| 8 | Shift Right | PASS |

## Final Verification Result

```text
Total Tests  = 8
Passed Tests = 8
Failed Tests = 0
```

# ALL TESTS PASSED

---

# 13. Final Conclusions

The 4-bit ALU was successfully verified using a self-checking Verilog testbench in the **Libero SoC → QuestaSim pre-synthesis simulation flow**.

The debugging process established the following:

1. **The simulation top-level module name must match the module expected by the simulation configuration.**
2. **QuestaSim license restrictions can prevent multiple simultaneous simulator sessions.**
3. **A manual testbench is useful for isolating whether a problem originates from the DUT, testbench, simulator, or waveform viewer.**
4. **The original self-checking testbench was functionally valid.**
5. **The waveform visibility problem resulted from operations being compressed into a short simulation interval.**
6. **Adding a hold period between transactions improved waveform readability.**
7. **All eight ALU operations were successfully verified.**
8. **The final simulation achieved 8 PASS results and 0 FAIL results.**

The final waveform and simulation transcript confirm that the ALU behaves correctly for all tested operations.

---

## Final Status

```text
RTL Compilation       : SUCCESS
Testbench Compilation : SUCCESS
Pre-Synthesis Simulation : SUCCESS
Waveform Verification : SUCCESS
Automatic Verification: SUCCESS

PASS = 8
FAIL = 0

PROJECT STATUS: VERIFIED
```
