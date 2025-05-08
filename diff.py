import subprocess
import sys
import re

def read_lines(file1, file2):
    while True:
        l1 = file1.readline()
        l2 = file2.readline()
        if not l1 or not l2:
            break
        yield l1.strip(), l2.strip()

def extract_hex(line):
    match = re.search(r'\[0x([0-9a-fA-F]+)\]', line)
    return match.group(1) if match else None

def disasm(hex_str):
    hex_str = hex_str.zfill(8)
    # Little-endian byte order
    byte_str = ''.join(reversed([hex_str[i:i+2] for i in range(0, 8, 2)]))
    with open("t", "wb") as f:
        f.write(bytes.fromhex(byte_str))

    result = subprocess.run([
        "riscv32-unknown-linux-gnu-objdump",
        "-D", "-b", "binary", "-M", "no-aliases", "-m", "riscv:rv32", "t"
    ], capture_output=True, text=True)

    # Extract disassembly line
    for line in result.stdout.splitlines():
        if re.match(r'^\s*[0-9a-f]+:\s+[0-9a-f]+\s+', line):
            return re.sub(r'^\s*[0-9a-f]+:\s+[0-9a-f]+\s+', '', line).strip()
    return "<no disasm>"

def parse_regs(line):
    # Remove bracketed hex (e.g., [0x...])
    clean = re.sub(r'\[[^]]*\]', '', line)
    regs = {}
    for pair in clean.split():
        if ':' in pair:
            key, val = pair.split(':', 1)
            regs[key] = val
    return regs

def compare_regs(r1, r2):
    for reg in r1:
        if reg in r2 and r1[reg] != r2[reg]:
            print(f"{reg} differs: {r1[reg]} vs {r2[reg]}")

def main():
    count = 0
    with open("dump1") as f1, open("dump2") as f2:
        for l1, l2 in read_lines(f1, f2):
            if l1 != l2:
                hex_code = extract_hex(l1)
                if hex_code:
                    insn = disasm(hex_code)
                    print(f"diverges at cycle {count} after [{insn}]")
                else:
                    print(f"diverges at cycle {count} (no instruction hex found)")
                print("------reference------")
                print(l1)
                print("------actual------")
                print(l2)
                compare_regs(parse_regs(l1), parse_regs(l2))
                sys.exit(1)
            count += 1

if __name__ == "__main__":
    main()
