# MATLAB/Simulink Modelling and Verification of a Convolutional Encoder

## 1. Overview

This project explores the operation of a convolutional encoder using MATLAB and Simulink. The encoder was configured, simulated with different binary input sequences, and verified against MATLAB's built-in `convenc()` reference function.

The objective is to establish a verified reference model before implementing equivalent functionality in RTL (Verilog) and C.

### Objectives

- Understand the fundamental operation of a convolutional encoder.
- Configure and simulate a convolutional encoder in Simulink.
- Generate binary input sequences using MATLAB.
- Compare Simulink outputs against MATLAB reference outputs.
- Perform automated testing with random input sequences.
- Test predefined input patterns and different input lengths.
- Prepare for subsequent RTL and C implementations.

---

## 2. Encoder Configuration

The Simulink Convolutional Encoder block was configured with the following parameters.

| Parameter | Value |
|---|---|
| Constraint length | 7 |
| Generator polynomials | `[171 133]` (octal) |
| Coding rate | 1/2 |
| Input bits per symbol | 1 |
| Output bits per symbol | 2 |
| Operation mode | Continuous |
| Puncturing | Disabled |
| Output final state | Unchecked |

The encoder trellis was defined in MATLAB using:

```matlab
trellis = poly2trellis(7, [171 133]);
```

The constraint length of 7 corresponds to six memory bits. The encoder uses the current input and its stored state to generate two output bits per input bit.

For an input sequence of 10 bits, the expected output length is 20 bits, assuming no termination bits are appended.

---

## 3. Simulink Model Architecture

The model consists of three connected blocks:

```text
+----------------+    +----------------------+    +---------------+
| From Workspace|--->| Convolutional Encoder |--->| To Workspace  |
+----------------+    +----------------------+    +---------------+
```

### 3.1 From Workspace

The input binary sequence is supplied through a MATLAB timeseries object.

Example:

```matlab
input_bits = [1; 0; 1; 1; 0; 0; 1; 0; 1; 1];

input_signal = timeseries(input_bits, (0:9)');
```

The From Workspace block uses `input_signal` as its input data source.

### 3.2 Convolutional Encoder

The encoder processes the input sequence using the configured trellis and generates two encoded bits per input bit.

### 3.3 To Workspace

The To Workspace block stores the encoder output in the variable:

```matlab
encoded_output
```

The simulation output is accessed through:

```matlab
out.encoded_output
```

For a 10-bit input, the output array has dimensions of 10 × 2. Each row contains the two encoded output bits associated with an input sample.

To convert the output array into a serial bitstream:

```matlab
simulink_bits = reshape(out.encoded_output.', [], 1);
```

The resulting column vector can be compared directly with the MATLAB reference bitstream.

---

## 4. MATLAB Reference Model

MATLAB's `convenc()` function was used as the reference implementation for verifying the Simulink model.

### Define the trellis

```matlab
trellis = poly2trellis(7, [171 133]);
```

### Generate the reference output

```matlab
reference_bits = convenc(input_bits, trellis);
```

### Compare the outputs

```matlab
simulink_bits = reshape(out.encoded_output.', [], 1);

match = isequal(simulink_bits, reference_bits(:));

disp(match);
```

A result of `1` indicates that the two bitstreams match exactly. A result of `0` indicates a mismatch.

**Note:** Both implementations must use the same input sequence, initial state, trellis configuration, and output ordering for the comparison to be valid.

---

## 5. Initial Functional Verification

During the initial comparison, the Simulink model and MATLAB reference model were using different input sequences.

The mismatch was identified by inspecting the input data used by each implementation.

The Simulink input was updated to use the first generated test sequence:

```matlab
input_bits = test_inputs(:,1);

input_signal = timeseries(input_bits, (0:9)');
```

The simulation was rerun, and the Simulink output was compared against the corresponding MATLAB reference output.

**Result: PASS**

The output sequences matched after the input mismatch was corrected.

This established the initial functional agreement between the Simulink encoder and the MATLAB reference for that test case.

---

## 6. Automated Random Testing

To test the encoder across multiple inputs, 50 random binary sequences were generated.

### 6.1 Generate test inputs

```matlab
rng(42);

num_tests = 50;
input_length = 10;

test_inputs = randi([0 1], input_length, num_tests);
```

Each column represents a separate 10-bit input sequence.

The random seed makes the test dataset reproducible.

### 6.2 Generate reference outputs

```matlab
trellis = poly2trellis(7, [171 133]);

reference_outputs = cell(1, num_tests);

for k = 1:num_tests
    input_bits_k = test_inputs(:, k);

    reference_outputs{k} = convenc(input_bits_k, trellis);
end
```

The reference output for each test case is stored in `reference_outputs`.

### 6.3 Run automated Simulink verification

Each input sequence was applied to the Simulink model. The resulting output was compared against its corresponding MATLAB reference sequence.

The verification condition was:

```matlab
isequal(simulink_bits, reference_bits)
```

A test case passed when both sequences matched bit-for-bit.

### 6.4 Random testing results

| Metric | Result |
|---|---:|
| Total test cases | 50 |
| Input length per test | 10 bits |
| Expected output length per test | 20 bits |
| Passed | 50 |
| Failed | 0 |
| Pass rate | 100% |

The results were summarized using:

```matlab
fprintf('Passed: %d/%d\n', sum(pass), num_tests);
fprintf('Failed: %d/%d\n', sum(~pass), num_tests);
```

**Result: PASS — 50 out of 50 random test cases matched the MATLAB reference outputs.**

---

## 7. Predefined Input Pattern Testing

In addition to random testing, five predefined input patterns were used to investigate the encoder's behaviour under different input conditions.

### Test patterns

```matlab
test_patterns = {
    zeros(10,1)
    ones(10,1)
    repmat([1;0],5,1)
    [1; zeros(9,1)]
    [1;0;1;1;0;1;0]
};
```

| Test case | Input pattern | Input length | Purpose |
|---|---|---:|---|
| 1 | All zeros | 10 bits | Observe zero-input behaviour |
| 2 | All ones | 10 bits | Observe continuous one-input behaviour |
| 3 | Alternating zeros and ones | 10 bits | Examine regular input transitions |
| 4 | Single one followed by zeros | 10 bits | Observe the effect of an isolated input one |
| 5 | Mixed binary sequence | 7 bits | Test mixed transitions and a different input length |

For each pattern, the expected output was generated using `convenc()`. The Simulink output was then compared against the corresponding reference output.

### Expected output lengths

For a rate-1/2 encoder without appended termination bits:

| Input length | Expected output length |
|---:|---:|
| 10 bits | 20 bits |
| 7 bits | 14 bits |

The five-pattern test procedure was completed. The individual PASS/FAIL counts should be taken from the MATLAB results table when reporting the detailed results.

---

## 8. Results and Observations

The completed MATLAB/Simulink activity established the following:

1. A convolutional encoder was configured using constraint length 7 and generator polynomials 171 and 133 (octal).
2. The Simulink model accepted binary input sequences and generated two output bits per input bit.
3. MATLAB's `convenc()` function was used as an independent reference.
4. An initial comparison mismatch was traced to different input sequences being used by the two implementations.
5. After aligning the inputs, the Simulink and MATLAB outputs matched.
6. Automated regression testing produced 50 successful comparisons out of 50 random test cases.
7. Five predefined input patterns were used to investigate encoder behaviour, including a shorter 7-bit input sequence.

### Verification summary

| Verification activity | Outcome |
|---|---|
| Initial comparison | Mismatch caused by different inputs |
| Corrected comparison | PASS |
| Random regression | 50/50 passed |
| Predefined input patterns | Test procedure completed |
| RTL implementation | Planned |
| C implementation | Planned |

The random regression results demonstrate agreement between the Simulink implementation and MATLAB's reference function for the 50 tested input sequences. They do not, by themselves, prove correctness for every possible input sequence or encoder configuration.

---

## 9. Conclusion

The convolutional encoder was modelled and explored using MATLAB and Simulink.

A reference model was developed using MATLAB's `convenc()` function, and the Simulink output was compared against this reference. Following correction of an initial input-sequence mismatch, the implementations produced matching outputs.

The automated regression suite achieved a 100% pass rate across 50 random 10-bit input sequences. Additional predefined patterns were also used to examine the encoder's behaviour with different input conditions and sequence lengths.

This activity establishes a reference model and a reusable verification approach for the next stage of development: implementing the same encoder in RTL and C and comparing their outputs against the MATLAB reference.

---

## 10. Future Work

The next development activities are:

1. Study the trellis structure, state transitions, and output generation.
2. Derive the XOR equations corresponding to the configured generator polynomials.
3. Implement a synthesizable convolutional encoder in Verilog.
4. Develop an RTL testbench using the same MATLAB-generated input vectors.
5. Compare the RTL outputs against the MATLAB reference outputs.
6. Implement an equivalent encoder in C.
7. Verify consistency across MATLAB, Simulink, RTL, and C.

The RTL and C implementations must preserve the reference model's initial state, polynomial interpretation, bit ordering, and output ordering.

---

## 11. Tools and Functions Used

| Tool or function | Purpose |
|---|---|
| MATLAB | Input generation, reference encoding, and result comparison |
| Simulink | Encoder modelling and simulation |
| `poly2trellis()` | Defines the convolutional encoder trellis |
| `convenc()` | Generates reference encoded sequences |
| `timeseries()` | Supplies time-indexed input data to Simulink |
| `randi()` | Generates random binary test inputs |
| `isequal()` | Performs bit-for-bit output comparison |
| `reshape()` | Converts the Simulink output array into a serial bitstream |

---

**Project status:** MATLAB/Simulink modelling and initial functional verification completed. RTL and C implementation remain the next stages.
