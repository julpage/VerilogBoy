#!/usr/bin/env python3
import sys


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: bin2mif.py <input.bin> <output.mif> [size] [width] [offset] [skip]")
        return -1

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    size = 256 if len(sys.argv) == 3 else int(sys.argv[3])
    width = 8 if len(sys.argv) < 5 else int(sys.argv[4])
    offset = 0 if len(sys.argv) < 6 else int(sys.argv[5])
    skip = 0 if len(sys.argv) < 7 else int(sys.argv[6])

    with open(input_path, "rb") as in_file:
        raw_data = in_file.read()

    needed = offset + size * (skip + 1)
    if len(raw_data) < needed:
        raw_data += b"\x00" * (needed - len(raw_data))

    buffer = raw_data
    bytes_per_line = max(1, width // 8)

    with open(output_path, "w", encoding="ascii") as out_file:
        rd_ptr = offset
        for i in range(size):
            out_file.write(f"{buffer[rd_ptr]:02X}")
            rd_ptr += skip + 1
            if i % bytes_per_line == bytes_per_line - 1:
                out_file.write("\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
