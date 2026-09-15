from intelhex import IntelHex

# Input and output file names
HEX_FILE = "simple_hex_gen.hex"   # Match your exact .hex file name
MEM_FILE = "Simple_Hex.mem"

ih = IntelHex(HEX_FILE)
start = ih.minaddr()
end = ih.maxaddr()

with open(MEM_FILE, "w") as f:
    # Step through 4 bytes at a time (32-bit words, Little-Endian)
    for addr in range(start, end + 1, 4):
        b0 = ih[addr]
        b1 = ih[addr + 1]
        b2 = ih[addr + 2]
        b3 = ih[addr + 3]
        word = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
        f.write(f"{word:08X}\n")

print(f"Success! Created {MEM_FILE} from {HEX_FILE}")
