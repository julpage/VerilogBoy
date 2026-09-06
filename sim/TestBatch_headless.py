import os

script_path = os.path.realpath(__file__)
script_dir = os.path.dirname(script_path)
os.chdir(script_dir)
print("chdir", script_dir)


rom_lists = [
    "./cinema/roms/jrz.gb",
    "./cinema/roms/addhl.gb",
    "./cinema/roms/ldhlsp.gb",
    "./cinema/roms/sra.gb",
    "./cinema/roms/rrca.gb",
    "./cinema/roms/ldhlsp2.gb",
    "./cinema/roms/addsp5.gb",
    "./cinema/roms/rlc.gb",
    "./cinema/roms/dec.gb",
    "./cinema/roms/sub.gb",
    "./cinema/roms/inc3.gb",
    "./cinema/roms/and.gb",
    "./cinema/roms/daa3.gb",
    "./cinema/roms/cp.gb",
    "./cinema/roms/or.gb",
    "./cinema/roms/spe.gb",
    "./cinema/roms/jp_hl.gb",
    "./cinema/roms/func_cond.gb",
    "./cinema/roms/addsp3.gb",
    "./cinema/roms/rlca.gb",
    "./cinema/roms/daa6.gb",
    "./cinema/roms/sbc.gb",
    "./cinema/roms/jr2.gb",
    "./cinema/roms/rrc.gb",
    "./cinema/roms/sla_func.gb",
    "./cinema/roms/addhl2.gb",
    "./cinema/roms/add2.gb",
    "./cinema/roms/rra.gb",
    "./cinema/roms/add_func.gb",
    "./cinema/roms/bootstrap_test1.gb",
    "./cinema/roms/high_mem.gb",
    "./cinema/roms/daa8.gb",
    "./cinema/roms/func_test.gb",
    "./cinema/roms/adc2.gb",
    "./cinema/roms/fib.gb",
    "./cinema/roms/addsp6.gb",
    "./cinema/roms/rst.gb",
    "./cinema/roms/bit2.gb",
    "./cinema/roms/bit1.gb",
    "./cinema/roms/daa2.gb",
    "./cinema/roms/func.gb",
    "./cinema/roms/inc1.gb",
    "./cinema/roms/addsp.gb",
    "./cinema/roms/daa5.gb",
    "./cinema/roms/array_test_write.gb",
    "./cinema/roms/rlca2.gb",
    "./cinema/roms/load3.gb",
    "./cinema/roms/srl.gb",
    "./cinema/roms/rla.gb",
    "./cinema/roms/load6.gb",
    "./cinema/roms/adc.gb",
    "./cinema/roms/rl.gb",
    "./cinema/roms/inc2.gb",
    "./cinema/roms/load1.gb",
    "./cinema/roms/cpl.gb",
    "./cinema/roms/int.gb",
    "./cinema/roms/sla.gb",
    "./cinema/roms/load5.gb",
    "./cinema/roms/rr.gb",
    "./cinema/roms/addsp4.gb",
    "./cinema/roms/load4.gb",
    "./cinema/roms/daa4.gb",
    "./cinema/roms/add1.gb",
    "./cinema/roms/simple.gb",
    "./cinema/roms/jr.gb",
    "./cinema/roms/load2.gb",
    "./cinema/roms/addsp2.gb",
    "./cinema/roms/jrnz.gb",
    "./cinema/roms/dec2.gb",
    "./cinema/roms/scf.gb",
    "./cinema/roms/swap.gb",
    "./cinema/roms/array_test_read.gb",
    "./cinema/roms/set.gb",
    "./cinema/roms/sub2.gb",
    "./cinema/roms/rst2.gb",
    "./cinema/roms/daa1.gb",
    "./cinema/roms/xor.gb",
    "./cinema/roms/daa7.gb"
]


rom_lists = sorted(rom_lists)

for i, eachRom in enumerate(rom_lists):
    print("")
    print("="*80)
    print("Test %d/%d: " % (i+1, len(rom_lists)), os.path.split(eachRom)[1])
    
    os.system(
        f'./vb_sim "{eachRom}" --testmode'
    )

    expectedFile = eachRom.replace(".gb", ".expected")
    with open(expectedFile) as f:
        expected = f.read()
    with open(".actual") as f:
        actual = f.read()

    expected = expected.split("\n")
    actual = actual.split("\n")

    print(eachRom, expectedFile)
    print(">>> Result:")
    print("    Expected  Actual")

    testPass = True
    if len(expected) != len(actual):
        print("Fail")
    else:
        for i in range(len(expected)):
            value_expected = expected[i]
            value_actual = actual[i]

            if value_actual == "":
                continue

            regName = value_expected.split(" ")[0]
            value_expected = value_expected.split(" ")[1]
            value_actual = value_actual.split(" ")[1]

            print(regName, " ", value_expected, "    ", value_actual, end="    ")
            if value_actual.lower() == value_expected.lower():
                print("Pass")
            else:
                print("✘")
                testPass = False

    if not testPass:
        input()
