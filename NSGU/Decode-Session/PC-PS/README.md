# NSGU GCS – Encoded vs Decoded Data Comparison (`enc_dec_compare.csv`)

**Result: 38 / 38 cases PASS** on all four bands (L1, L2, L5, S).
The standard acceptance suite T01–T11 was also run: **27 / 27 PASS** (`nsgu_test_report_sim.html`).

Platform: the GCS PC software with its **built-in NSGU simulator**, at time x40.
No ZC702 board, real CAN bus or NSGU board was used.

---

## 1. What we did

In simple words: **we told the NSGU what data to send, captured what it actually sent, decoded
it, and checked that we got back exactly what we told it to send.**

For each test case (one row of the sheet):

1. **Set the data.** We chose the NAV message fields (for example `msg_id`, `prn_id`, `toi`,
   `tlm`) and the encoder settings (BCH / LDPC selection for L1/L2, sync word for L5/S).
2. **Send it to the NSGU (STORE + APPLY).** The GCS packs the data into telecommands and sends
   them over the CAN protocol. The NSGU starts using the new data at the next frame boundary.
3. **Work out the expected frame.** The GCS golden model computes the exact frame that the NSGU
   should transmit for this data and these encoder settings.
4. **Capture what the NSGU actually sent.** We captured it in two ways:
   - **Capture one frame** (the despreader takes one frame), as in the GUI *Capture & verify* tab.
   - **PS stream** (continuous decoding on the Zynq PS), as in the GUI *Data Analyzer*.
5. **Compare.**
   - **Encoded check:** captured symbols vs expected symbols. They must be identical.
   - **Decoded check:** the decoded NAV fields vs the fields we set in step 1. They must be identical.

### Test cases covered

| Band | Cases (rows) |
|---|---|
| L1, L2 | default data; random data with each BCH selection 1–6; random data with each LDPC selection 1–3; all-zero data; all-ones data (12 rows per band) |
| L5, S | default data; 3 sets of random data; random data with a different sync word (0x1ACF); all-zero data; all-ones data (7 rows per band) |

The all-zero and all-ones rows check the edges of every field (first bit, last bit, and the
boundaries between telecommand words).

---

## 2. How to read the sheet (column by column)

| Column | Meaning in simple words | PASS value |
|---|---|---|
| `band` | Which signal: L1, L2, L5 or S | – |
| `case` | What was tested in this row | – |
| `result` | Overall verdict for this row | **PASS** |
| `enc` | Encoder settings used. Note: the numbers are 0-based, so `"bch": 3` means BCH_SEL 4 in the GUI. The `sync` value is in decimal, so `60304` = `0xEB90`. | – |
| `store_apply` | Did the NSGU accept the new data and switch to it? | OK |
| `exp_symbols` | How many symbols one frame should have (1800 for L1/L2, 2400 for L5/S) | 1800 / 2400 |
| `cap_symbols` | How many symbols we actually captured | same as `exp_symbols` |
| `cap_sym_diff` | **Symbols that differ between the captured and expected frame** | **0** |
| `cap_chip_err` | Chips that didn't match the PRN code during despreading | 0 |
| `pc_decode_ok` | Did the PC-side decoder decode the captured frame cleanly? | True |
| `pc_field_mismatch` | NAV fields decoded on the PC that differ from what we set | empty |
| `ps_frame` | Frame number in the PS stream that was checked | – |
| `ps_raw_sym_diff` | Symbols that differ between the PS stream and the expected frame | **0** |
| `ps_chip_err` | Chip errors in the PS stream | 0 |
| `ps_dropped` | Frames the stream skipped | 0 |
| `ps_decode_ok` | Did the PS decoder decode the frame cleanly? | True |
| `ps_checks` | The decoder's own error checks (explained below) | all good |
| `ps_field_mismatch` | **NAV fields decoded on the PS that differ from what we set** | **empty** |
| `error` | Any exception during the run | empty |

### The `ps_checks` column

- **L1 / L2:** `BCH True, LDPC syn 0/0, CRC True/True`
  - *BCH True*: subframe 1 (time of interval) arrived intact.
  - *LDPC syn 0/0*: subframes 2 and 3 are valid LDPC codewords, with zero parity-check failures.
  - *CRC True/True*: the CRC-24Q checksum is correct for subframes 2 and 3.
- **L5 / S:** `SF1 sync EB90 Vit 0 CRC True tail True` (and the same for SF2–SF4)
  - *sync EB90*: the start-of-subframe marker was found.
  - *Vit 0*: the Viterbi decoder found an exact match, with zero symbol mismatches.
  - *CRC True*: the CRC-24Q checksum is correct.
  - *tail True*: the 6 tail bits are zero, as they should be.

### Example row explained (L1, default)

> `cap_symbols 1800, cap_sym_diff 0, cap_chip_err 0, ps_raw_sym_diff 0,
> ps_checks "BCH True, LDPC syn 0/0, CRC True/True", ps_field_mismatch empty → PASS`

The NSGU sent all 1800 symbols exactly as expected, despreading had no errors, all decoder
checks passed, and every decoded NAV field equals the value we set.

---

## 3. How we know the comparison really works (negative test)

To show that "0 differences" is not just the script always saying PASS, we deliberately changed
**one bit** of `msg_id` in the expected data, without sending it to the NSGU:

| Band | Result |
|---|---|
| L1 | 150 symbol differences; field `msg_id` flagged; FAIL |
| L5 | 80 symbol differences; fields `SF3.msg_id` and `SF4.msg_id` flagged; FAIL |

A one-bit change is caught immediately, and the wrong field is named.
(Many symbols change because one data bit also changes the CRC and the LDPC / convolutional
parity bits.)

---

## 4. What this does NOT prove

| Limitation | Explanation |
|---|---|
| **No real hardware was used** | Everything ran on the built-in simulator. Nothing ran on the ZC702 board, a real CAN bus or the NSGU board. Hardware bring-up is still open. |
| **The simulator uses the same reference model on both sides** | The simulated NSGU builds its frame with the same golden model that gives the "expected" frame, and the simulator's "PS decoder" is a Python copy of the golden decoder, not the real firmware. So this sheet proves the **data path** (telecommand packing over CAN, STORE/APPLY, PRN code, despreading, stream protocol, field unpacking). It does **not** independently prove the encoder or decoder maths. |
| **The real firmware decoder is not in this sheet** | `nav_decode.c` (the C code that runs on the Zynq PS) was tested separately: 500 random frames with 0–6 injected symbol errors, all bit-exact against the golden model (`sw/test/run_nav_decode_test.py`). |
| **No noise or errors on the link** | The simulator gives a perfect signal, so chip errors are always 0 here. Error correction was only exercised in the separate firmware decoder test above. |
| **No real timing** | `decode_us` and the frame rates in the simulator are not real A9 / FPGA timings. Decode time per frame, the 200 MHz timing margin and CDC behaviour can only be checked on hardware. |
| **Not every encoder option was swept** | Covered: BCH 1–6, LDPC 1–3, sync word. Not covered: CONV_SEL and ILV_SEL slots B and C. |
| **Interface details are not proven** | The FMC pin mapping, voltage levels, CAN bit timing / termination and agreement of the CAN ICD with the NSGU team all still need the real board. |

**One-line summary:** On the simulator, the data we command is transmitted, captured and decoded
back **exactly**, on all bands and all tested encoder settings (38/38 cases). A one-bit mismatch is
detected. Hardware testing is the next step.

---

## Files

| File | Content |
|---|---|
| `enc_dec_compare.csv` | One row per test case (this sheet) |
| `nsgu_test_report_sim.html` | T01–T11 acceptance report from the same simulator run |
| `compare_enc_dec.py` | Script that produced the sheet: `python compare_enc_dec.py <gcs folder> <output folder> [speed]` |
