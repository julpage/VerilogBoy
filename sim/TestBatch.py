import os
import time


script_path = os.path.realpath(__file__)
script_dir = os.path.dirname(script_path)
os.chdir(script_dir)
print("chdir", script_dir)


rom_lists = [
    # "./cinema/gb/acid/cgb-acid2/test.gbc",  # [fail] 彩色ppu CGB Acid2 彩色 PPU 精确性测试
    # "./cinema/gb/acid/dmg-acid2/test.gb",   # [fail] 黑白ppu DMG Acid2 黑白 PPU 精确性测试

    # "./cinema/gb/blargg/cpu_instrs/01-special/test.gb",             # [pass] Blargg CPU 特殊指令测试
    # "./cinema/gb/blargg/cpu_instrs/02-interrupts/test.gb",          # [pass] Blargg CPU 中断相关测试
    # "./cinema/gb/blargg/cpu_instrs/03-op sp,hl/test.gb",            # [pass] Blargg CPU SP/HL 操作测试
    # "./cinema/gb/blargg/cpu_instrs/04-op r,imm/test.gb",            # [pass] Blargg CPU 寄存器与立即数测试
    # "./cinema/gb/blargg/cpu_instrs/05-op rp/test.gb",               # [pass] Blargg CPU 寄存器对操作测试
    # "./cinema/gb/blargg/cpu_instrs/06-ld r,r/test.gb",              # [pass] Blargg CPU 寄存器到寄存器加载测试
    # "./cinema/gb/blargg/cpu_instrs/07-jr,jp,call,ret,rst/test.gb",  # [pass] Blargg CPU 跳转/调用/返回/重启测试
    # "./cinema/gb/blargg/cpu_instrs/08-misc instrs/test.gb",         # [pass] Blargg CPU 杂项指令测试
    # "./cinema/gb/blargg/cpu_instrs/09-op r,r/test.gb",              # [pass] Blargg CPU 8 位算术逻辑测试
    # "./cinema/gb/blargg/cpu_instrs/10-bit ops/test.gb",             # [pass] Blargg CPU 位操作测试
    # "./cinema/gb/blargg/cpu_instrs/11-op a,(hl)/test.gb",           # [pass] Blargg CPU HL 间接寻址测试

    "./cinema/gb/blargg/cgb_sound/01-registers/test.gb",              # [pass] Blargg CGB 音频寄存器测试
    "./cinema/gb/blargg/cgb_sound/02-len ctr/test.gb",                # [pass] Blargg CGB 长度计数器测试
    "./cinema/gb/blargg/cgb_sound/03-trigger/test.gb",                # [pass] Blargg CGB 声道触发测试
    "./cinema/gb/blargg/cgb_sound/04-sweep/test.gb",                  # [pass] Blargg CGB 扫频测试
    "./cinema/gb/blargg/cgb_sound/05-sweep details/test.gb",          # [pass] Blargg CGB 扫频细节测试
    "./cinema/gb/blargg/cgb_sound/06-overflow on trigger/test.gb",    # [pass] Blargg CGB 触发时溢出行为测试
    "./cinema/gb/blargg/cgb_sound/07-len sweep period sync/test.gb",  # [pass] Blargg CGB 长度计数器与扫频同步测试
    "./cinema/gb/blargg/cgb_sound/08-len ctr during power/test.gb",   # [pass] Blargg CGB 上电期间长度计数器测试
    "./cinema/gb/blargg/cgb_sound/09-wave read while on/test.gb",     # [pass] Blargg CGB 波表开启时读取测试
    "./cinema/gb/blargg/cgb_sound/10-wave trigger while on/test.gb",  # [pass] Blargg CGB 波表开启时触发测试
    "./cinema/gb/blargg/cgb_sound/11-regs after power/test.gb",       # [pass] Blargg CGB 上电后寄存器状态测试
    "./cinema/gb/blargg/cgb_sound/12-wave/test.gb",                   # [pass] Blargg CGB 波表行为综合测试

    "./cinema/gb/blargg/dmg_sound/01-registers/test.gb",              # [pass] Blargg DMG 音频寄存器测试
    "./cinema/gb/blargg/dmg_sound/02-len ctr/test.gb",                # [pass] Blargg DMG 长度计数器测试
    "./cinema/gb/blargg/dmg_sound/03-trigger/test.gb",                # [pass] Blargg DMG 声道触发测试
    "./cinema/gb/blargg/dmg_sound/04-sweep/test.gb",                  # [pass] Blargg DMG 扫频测试
    "./cinema/gb/blargg/dmg_sound/05-sweep details/test.gb",          # [pass] Blargg DMG 扫频细节测试
    "./cinema/gb/blargg/dmg_sound/06-overflow on trigger/test.gb",    # [pass] Blargg DMG 触发时溢出行为测试
    "./cinema/gb/blargg/dmg_sound/07-len sweep period sync/test.gb",  # [pass] Blargg DMG 长度计数器与扫频同步测试
    "./cinema/gb/blargg/dmg_sound/08-len ctr during power/test.gb",   # [fail 失败是对的] Blargg DMG 上电期间长度计数器测试
    "./cinema/gb/blargg/dmg_sound/09-wave read while on/test.gb",     # [fail 失败是对的] Blargg DMG 波表开启时读取测试
    "./cinema/gb/blargg/dmg_sound/10-wave trigger while on/test.gb",  # [fail 失败是对的] Blargg DMG 波表开启时触发测试
    "./cinema/gb/blargg/dmg_sound/11-regs after power/test.gb",       # [fail 失败是对的] Blargg DMG 上电后寄存器状态测试
    "./cinema/gb/blargg/dmg_sound/12-wave write while on/test.gb",    # [fail 失败是对的] Blargg DMG 声道开启时写入波表测试

    # "./cinema/gb/blargg/halt_bug/test.gb",                     # [pass] HALT 指令遗留 bug 兼容性测试
    # "./cinema/gb/blargg/instr_timing/test.gb",                 # [pass] Blargg 指令周期精确性测试
    # "./cinema/gb/blargg/interrupt_time/test.gb",               # [fail] Blargg 中断响应时序测试 倍速模式串口中断耗时
    # "./cinema/gb/blargg/mem_timing/01-read_timing/test.gb",    # [pass] Blargg 内存读取时序测试
    # "./cinema/gb/blargg/mem_timing/02-write_timing/test.gb",   # [pass] Blargg 内存写入时序测试
    # "./cinema/gb/blargg/mem_timing/03-modify_timing/test.gb",  # [pass] Blargg 内存读改写时序测试

    # "./cinema/mts-20260714-0944-31510e1/acceptance/add_sp_e_timing.gb",      # [pass] ADD SP,r8 指令周期时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/bits/mem_oam.gb",         # [pass] OAM 内存位写入行为测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/bits/reg_f.gb",           # [pass] F 寄存器标志位行为测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/bits/unused_hwio-GS.gb",  # [fail] 未使用硬件 I/O 行为测试 [fail: CGB, AGB, AGS]
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_hwio-S.gb",          # [fail] SBF SGB 启动时硬件 I/O 状态测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_hwio-dmg0.gb",       # [fail] SBF DMG0 启动时硬件 I/O 状态测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_hwio-dmgABCmgb.gb",  # [fail] SBF DMG A/B/C 与 MGB 启动时硬件 I/O 状态测试

    # 这部分跟选择用哪个bios有关
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_regs-dmg0.gb",    # [fail] SBF DMG0 启动时寄存器值测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_regs-dmgABC.gb",  # [pass] DMG A/B/C 启动时寄存器值测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_regs-mgb.gb",     # [fail] SBF MGB 启动时寄存器值测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_regs-sgb.gb",     # [fail] SBF SGB 启动时寄存器值测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_regs-sgb2.gb",    # [fail] SBF SGB2 启动时寄存器值测试

    # 这部分好像没什么意义
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_div-S.gb",          # [fail] SBF SGB 启动时 DIV 状态测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_div-dmg0.gb",       # [fail] SBF DMG0 启动时 DIV 状态测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_div-dmgABCmgb.gb",  # [fail] SBF DMG A/B/C 与 MGB 启动时 DIV 状态测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/boot_div2-S.gb",         # [fail] SBF SGB 启动时 DIV 状态变体测试

    # "./cinema/mts-20260714-0944-31510e1/acceptance/call_cc_timing.gb",   # [pass] 条件调用时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/call_cc_timing2.gb",  # [pass] 条件调用时序变体测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/call_timing.gb",      # [pass] 无条件 CALL 时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/call_timing2.gb",     # [pass] CALL 时序变体测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/di_timing-GS.gb",     # [pass] DI 指令时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ei_sequence.gb",      # [pass] EI 延迟生效序列测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ei_timing.gb",        # [pass] EI 指令时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/halt_ime0_ei.gb",     # [pass] IME=0 HALT 唤醒中断测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/halt_ime0_nointr_timing.gb",  # [fail] IME=0 无中断 HALT 时序测试 vblank中断的锅
    # "./cinema/mts-20260714-0944-31510e1/acceptance/halt_ime1_timing.gb",         # [pass] IME=1 HALT 时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/halt_ime1_timing2-GS.gb",     # [pass] IME=1 HALT 变体时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/if_ie_registers.gb",     # [pass] IF/IE 寄存器测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/instr/daa.gb",           # [pass] DAA 指令测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/interrupts/ie_push.gb",  # [pass] 中断期间压栈 IE 测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/intr_timing.gb",         # [pass] 中断响应周期时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/jp_cc_timing.gb",        # [pass] 条件跳转时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/jp_timing.gb",           # [pass] 无条件跳转时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ld_hl_sp_e_timing.gb",   # [pass] LD HL,SP+r8 时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/oam_dma/basic.gb",       # [pass] OAM DMA 基本传输测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/oam_dma/reg_read.gb",    # [pass] OAM DMA 期间寄存器读取测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/oam_dma/sources-GS.gb",  # [pass] OAM DMA 不同源地址测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/oam_dma_restart.gb",     # [pass] OAM DMA 重启测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/oam_dma_start.gb",       # [pass] OAM DMA 启动时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/oam_dma_timing.gb",      # [pass] OAM DMA 周期精确时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/pop_timing.gb",          # [pass] POP 指令时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/hblank_ly_scx_timing-GS.gb",      # [fail] HBlank 修改 SCX/LY 时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/intr_1_2_timing-GS.gb",           # [fail] STAT 模式 1/2 中断时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/intr_2_0_timing.gb",              # [fail] STAT 模式 2→0 中断时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/intr_2_mode0_timing.gb",          # [fail] 模式 0 中断时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/intr_2_mode0_timing_sprites.gb",  # [fail] 有精灵的模式 0 中断时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/intr_2_mode3_timing.gb",          # [fail] 模式 3 中断时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/intr_2_oam_ok_timing.gb",         # [fail] OAM 就绪时模式 2 中断时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/lcdon_timing-GS.gb",              # [fail] LCD 开启时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/lcdon_write_timing-GS.gb",        # [fail] LCD 开启时寄存器写入时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/stat_irq_blocking.gb",            # [fail] STAT 中断阻塞测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/stat_lyc_onoff.gb",               # [fail] LYC 中断开关测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ppu/vblank_stat_intr-GS.gb",          # [fail] VBlank 期间 STAT 中断测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/push_timing.gb",       # [pass] PUSH 指令时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/rapid_di_ei.gb",       # [pass] 快速 DI/EI 切换测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ret_cc_timing.gb",     # [pass] 条件返回时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/ret_timing.gb",        # [pass] RET 返回时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/reti_intr_timing.gb",  # [pass] RETI 与中断交互时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/reti_timing.gb",       # [pass] RETI 时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/rst_timing.gb",        # [pass] RST 指令时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/serial/boot_sclk_align-dmgABCmgb.gb",  # [fail反正sameboy也失败了] SBF 串口启动时 SCLK 对齐测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/div_timing.gb",                  # [pass] DIV 时序测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/div_write.gb",             # [pass] DIV 寄存器写入覆盖中断测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/rapid_toggle.gb",          # [pass] 快速切换 TAC 时钟选择测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim00.gb",                 # [pass] TAC=00 4096 定时器测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim00_div_trigger.gb",     # [pass] TAC=00 4096 下 DIV 触发 TIMA 测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim01.gb",                 # [pass] TAC=01 262144 定时器测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim01_div_trigger.gb",     # [pass] TAC=01 262144 下 DIV 触发 TIMA 测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim10.gb",                 # [pass] TAC=10 65536 定时器测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim10_div_trigger.gb",     # [pass] TAC=10 65536 下 DIV 触发 TIMA 测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim11.gb",                 # [pass] TAC=11 16384 定时器测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tim11_div_trigger.gb",     # [pass] TAC=11 16384 下 DIV 触发 TIMA 测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tima_reload.gb",           # [pass] TIMA 重载测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tima_write_reloading.gb",  # [pass] TIMA 重载期间写入测试
    # "./cinema/mts-20260714-0944-31510e1/acceptance/timer/tma_write_reloading.gb",   # [pass] TMA 重载期间写入测试

    # # 极限测试
    # "./cinema/mts-20260714-0944-31510e1/madness/mgb_oam_dma_halt_sprites.gb",  # OAM DMA + HALT + 精灵极限时序测试
    # "./cinema/mts-20260714-0944-31510e1/manual-only/sprite_priority.gb",       # 精灵优先级人工验证测试
    # "./cinema/mts-20260714-0944-31510e1/misc/bits/unused_hwio-C.gb",           # [fail] SBF 未使用硬件 I/O 行为测试
    # "./cinema/mts-20260714-0944-31510e1/misc/boot_div-A.gb",                   # [fail] SBF AGB 机型启动时 DIV 状态测试
    # "./cinema/mts-20260714-0944-31510e1/misc/boot_div-cgb0.gb",                # [fail] SBF CGB 0 版启动时 DIV 状态测试
    # "./cinema/mts-20260714-0944-31510e1/misc/boot_div-cgbABCDE.gb",      # [fail] SBF CGB A-E 版启动时 DIV 状态测试
    # "./cinema/mts-20260714-0944-31510e1/misc/boot_hwio-C.gb",            # [fail] SBF CGB 启动时硬件 I/O 状态测试
    # "./cinema/mts-20260714-0944-31510e1/misc/boot_regs-A.gb",            # [fail] SBF AGB 机型启动时寄存器值测试
    # "./cinema/mts-20260714-0944-31510e1/misc/boot_regs-cgb.gb",          # [fail] SBF CGB 启动时寄存器值测试
    # "./cinema/mts-20260714-0944-31510e1/misc/ppu/vblank_stat_intr-C.gb"  # [fail] SBF PPU 杂项测试
]


for i, eachRom in enumerate(rom_lists):

    print("="*80)
    print("Test %d/%d: " % (i+1, len(rom_lists)), os.path.split(eachRom)[1], eachRom)

    os.system(
        f'./vb_sim "{eachRom}" --nostop'
        # f'./vb_sim "{eachRom}" --nostop --verbose'
    )

    # input()
    time.sleep(0.5)
