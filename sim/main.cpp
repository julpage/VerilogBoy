//
// VerilogBoy simulator
// Copyright 2022 Wenting Zhang
//
// main.cpp: VerilogBoy main simulation unit
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
#include <stdio.h>  // 标准输入输出库，提供 printf/fprintf/fopen 等函数
#include <stdlib.h> // 标准库，提供 exit、malloc/free 等函数
#include <stdint.h> // 提供固定宽度整数类型（uint64_t、uint32_t 等）
#include <assert.h> // 提供 assert 断言宏，用于检查运行时条件
#include <time.h>   // 时间库（本文件中未直接使用，为预留）
#include <vector>   // 标准向量容器（本文件中未直接使用，为预留）

#include <SDL.h> // SDL 库，用于窗口显示、键盘输入和计时

#include "verilated.h"       // Verilator 仿真顶层头文件
#include "verilated_vcd_c.h" // Verilator VCD 波形转储支持
#include "Vboy___024root.h"  // Verilator 生成的顶层根（root）模块头文件
#include "Vboy.h"            // Verilator 生成的仿真核心顶层模块

#include "memsim.h"   // 存储器仿真（映射内存读写）
#include "mbcsim.h"   // MBC（Memory Bank Controller，存储器组控制器）仿真
#include "dispsim.h"  // 显示仿真（连接 SDL 窗口，渲染像素）
#include "mmrprobe.h" // MMR（Memory Mapped Register）探针，监控 CPU 总线
#include "audiosim.h" // 音频仿真（捕获左右声道输出并保存为 WAV）

// 时钟周期，单位皮秒（ps）。10ns = 100MHz？此处定义为 250000ps = 250ns（4MHz）
#define CLK_PERIOD_PS 250000

// 仿真环境中 RAM 映射的基地址（用于让总线在高地址空间访问仿真内存）
#define RAM_BASE 0x80000000
#define RAM_SIZE 1 * 1024 * 1024 // RAM 大小：1MB

// 控制寄存器（CON）映射的基地址
#define CON_BASE 0x20000000

// Verilator related
Vboy *core;           // Verilator 仿真核心实例指针
VerilatedVcdC *trace; // VCD 波形追踪对象指针

// 宏：将两个参数拼接成一个标识符（用于构造内部信号的完整名字）
#define CONCAT(a, b) a##b
// 宏：构造对 Verilator 生成的核心内部信号的访问路径（boy__DOT__ 对应层次分隔）
#define SIGNAL(x) CONCAT(core->rootp->boy__DOT__, x)

// this only applies to quiet mode.
// 仅在静默（测试）模式下生效：仿真周期数上限，超过则停止
const uint64_t CYCLE_LIMIT = 32768;

// 以下为全局运行配置开关（由命令行参数设置）
static bool quiet = false;                 // 静默模式：不显示窗口，仅跑测试并输出结果
static bool verbose = false;               // 详细模式：启用 MMR 总线监控探针
static bool enable_trace = false;          // 是否生成 VCD 波形文件（trace.vcd）
static bool noboot = false;                // 是否跳过 Boot ROM（直接运行用户 ROM）
static bool nostop = false;                // 遇到 STOP/HALT 指令或时间上限时不停止
static bool itrace = false;                // 是否输出指令级追踪日志（itrace.txt）
static bool usembc = false;                // 是否启用 MBC（存储器组控制器）仿真
static bool enable_audio = false;          // 是否启用音频捕获
static unsigned short breakpoint = 0xff7f; // 断点 PC 地址，默认 0xff7f
static char result_file[127];              // 测试模式下的结果输出文件名

// Software simulated peripherals
// 软件仿真的外设对象指针（按需创建）
MEMSIM *cartrom;    // 卡带 ROM 存储器仿真
MEMSIM *cartram;    // 卡带 RAM 存储器仿真
MBCSIM *mbc;        // MBC 控制器仿真
DISPSIM *dispsim;   // 显示仿真
MMRPROBE *mmrprobe; // MMR 总线探针
AUDIOSIM *audiosim; // 音频仿真
FILE *it;           // 指令级追踪输出文件的句柄

// State
uint64_t tickcount; // 全局仿真周期（tick）计数器

// 返回当前仿真时间戳（单位皮秒），供 Verilator 的时间查询接口使用
double sc_time_stamp()
{
    // This is in pS. Currently we use a 10ns (100MHz) clock signal.
    // 时间戳 = 已执行的 tick 数 × 时钟周期（皮秒）
    return (double)tickcount * (double)CLK_PERIOD_PS;
}

// 模拟一个完整时钟周期：驱动外设总线、产生时钟上升沿/下降沿、可选转储波形和指令追踪
void tick()
{
    if (usembc)
    {
        // 使用 MBC 仿真：所有内存访问（ROM/RAM 切换、读写）由 MBC 统一处理
        mbc->apply(
            core->cart_d,   // CPU 写出的数据
            core->cart_a,   // CPU 地址总线
            core->cart_nWR, // 写使能信号
            core->cart_nRD, // 读使能信号
            core->cart_d);  // 读回给 CPU 的数据
    }
    else
    {
        // 不使用 MBC（ROM ONLY 模式）：ROM 与 RAM 分开访问
        cartrom->apply(
            core->cart_d,   // CPU 写出的数据
            core->cart_a,   // 地址总线
            1,              // 写使能恒为 0（ROM 只读）//core->cart_nWR
            core->cart_nRD, // 读使能信号
            core->cart_d);  // 读回数据
        cartram->apply(
            core->cart_d,   // CPU 写出的数据
            core->cart_a,   // 地址总线
            core->cart_nWR, // 写使能信号（RAM 可读写）
            core->cart_nRD, // 读使能信号
            core->cart_d);  // 读回数据
    }

    if (!quiet)
    {
        // 非静默模式下，把像素与行/帧同步信号送入显示仿真（刷新窗口画面）
        dispsim->apply(
            core->pixel,  // 当前像素数据
            core->hs,     // 行同步信号
            core->vs,     // 帧同步信号
            core->valid); // 像素是否有效
    }

    if (enable_audio)
    {
        // 启用音频时，把左右声道采样值送入音频仿真（缓冲为 WAV 数据）
        audiosim->apply(
            core->left,   // 左声道
            core->right); // 右声道
    }

    if (verbose)
    {
        // 详细模式下，把 CPU 内部总线信号送入探针，用于监控/调试记录
        mmrprobe->apply(
            SIGNAL(cpu_dout), // CPU 写数据总线
            SIGNAL(cpu_a),    // CPU 地址总线
            SIGNAL(cpu_wr),   // CPU 写使能
            SIGNAL(cpu_rd),   // CPU 读使能
            SIGNAL(cpu_din),  // CPU 读数据总线
            SIGNAL(u_cpu__DOT__pc),
            tickcount);
    }

    tickcount++; // 周期计数加一（用于时间戳计算）

    // 刷新模型状态：先保持 clk=0 求值，再拉高/拉低并分别求值
    core->eval();
    if (enable_trace)
        trace->dump(tickcount * CLK_PERIOD_PS - CLK_PERIOD_PS / 4); // 输出波形：下降沿后的采样点（时钟低电平期间）

    core->clk = 1; // 时钟拉高（上升沿）
    core->eval();  // 重新求值，推进组合/时序逻辑
    if (enable_trace)
        trace->dump(tickcount * CLK_PERIOD_PS); // 输出波形：上升沿采样点

    core->clk = 0; // 时钟拉低（下降沿）
    core->eval();  // 重新求值
    if (enable_trace)
        trace->dump(tickcount * CLK_PERIOD_PS + CLK_PERIOD_PS / 2); // 输出波形：下降沿后的采样点（时钟高电平期间）

    if (itrace)
    {
        // 指令级追踪：在一条指令刚执行完（取指状态=3 且下一状态=0）时打印寄存器现场
        if ((SIGNAL(u_cpu__DOT__ct_state == 3)) && (SIGNAL(u_cpu__DOT__next == 0)))
        {
            // Instruction just finished executing
            // 把当前 CPU 状态写入 itrace.txt，格式与旧追踪文件兼容
            fprintf(it, "Time %ld\nPC = %04x, F = %c%c%c%c, A = %02x, SP = %02x%02x\nB = %02x, C = %02x, D = %02x, E = %02x, H = %02x, L = %02x\n",
                    10 * (tickcount - 1),   // Make timing compatible with old traces // 时间乘 10 以兼容旧追踪格式
                    SIGNAL(u_cpu__DOT__pc), // 程序计数器
                    // 标志寄存器按位解析：bit3=Z、bit2=N、bit1=H、bit0=C
                    ((SIGNAL(u_cpu__DOT__flags)) & 0x8) ? 'Z' : '-', // 零标志 Z
                    ((SIGNAL(u_cpu__DOT__flags)) & 0x4) ? 'N' : '-', // 减法标志 N
                    ((SIGNAL(u_cpu__DOT__flags)) & 0x2) ? 'H' : '-', // 半进位标志 H
                    ((SIGNAL(u_cpu__DOT__flags)) & 0x1) ? 'C' : '-', // 进位标志 C
                    SIGNAL(u_cpu__DOT__acc__DOT__data),              // 累加器 A
                    // 寄存器组数组索引：6=SP 高字节、7=SP 低字节
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[6]),  // SP 高字节
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[7]),  // SP 低字节
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[0]),  // B
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[1]),  // C
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[2]),  // D
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[3]),  // E
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[4]),  // H
                    SIGNAL(u_cpu__DOT__regfile__DOT__regs[5])); // L
        }
    }
}

// 复位 CPU 核心：依次拉低/拉高/拉低复位信号，每个状态都跑一个 tick
void reset()
{
    core->rst = 0; // 先取消复位，运行一个周期
    tick();
    core->rst = 1; // 拉高复位信号，运行一个周期（使核心进入复位状态）
    core->key = 0xff;
    tick();
    core->rst = 0; // 释放复位，运行一个周期
    tick();
    if (noboot)
    {
        // 若指定跳过 Boot ROM，则置位 brom_disable 信号绕过引导程序
        SIGNAL(u_brom__DOT__brom_disable) = 1;
    }
}

// 主函数：解析参数、初始化外设、运行仿真主循环、输出结果并清理资源
int main(int argc, char *argv[])
{
    // Initialize testbench
    // 初始化 Verilator 仿真环境（同时把自定义参数透传给 Verilator）
    Verilated::commandArgs(argc, argv);

    core = new Vboy;              // 创建仿真核心实例
    Verilated::traceEverOn(true); // 允许开启波形追踪

    // 参数不足时打印用法说明并退出
    if (argc < 2)
    {
        puts("USAGE: vb_sim <rom.gb> [--testmode] [--verbose] [--trace] [--noboot] [--nintenboot]"
             "[--nostop] [--audio] [--itrace] [--mbc] (verilator paramters...)\n");
        exit(0);
    }

    // 遍历命令行参数，逐个解析仿真选项开关
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--testmode") == 0)
        {
            // 测试模式：进入静默运行，并把结果输出到 "<rom文件名>.actual"
            quiet = true;
            strcpy(result_file, argv[1]);                     // 先复制 ROM 文件路径
            char *location = strstr(result_file, ".");        // 找到扩展名的 "." 位置
            if (location == NULL)                             // 若没有扩展名
                location = result_file + strlen(result_file); // 则定位到字符串末尾
            strcpy(location, ".actual");                      // 把扩展名替换为 ".actual"
            noboot = true;                                    // 测试模式同时跳过 Boot ROM
        }
        // Skip boot ROM
        // 跳过 Boot ROM：直接运行用户程序
        if (strcmp(argv[i], "--noboot") == 0)
        {
            noboot = true;
        }
        // Enable MMR probe
        // 启用 MMR 探针（详细模式）：监控 CPU 内部总线
        if (strcmp(argv[i], "--verbose") == 0)
        {
            verbose = true;
        }
        // Enable waveform trace
        // 启用波形追踪：输出 VCD 波形文件
        if (strcmp(argv[i], "--trace") == 0)
        {
            enable_trace = true;
        }
        // Does not stop on STOP/HALT
        // 遇 STOP/HALT 或时间上限时继续运行而不停止
        if (strcmp(argv[i], "--nostop") == 0)
        {
            nostop = true;
        }
        // Enable instruction level trace
        // 启用指令级追踪日志
        if (strcmp(argv[i], "--itrace") == 0)
        {
            itrace = true;
        }
        // Enable MBC emulation
        // 启用 MBC（存储器组控制器）仿真
        if (strcmp(argv[i], "--mbc") == 0)
        {
            usembc = true;
        }
        // Enable audio capture
        // 启用音频捕获（保存为 WAV）
        if (strcmp(argv[i], "--audio") == 0)
        {
            enable_audio = true;
        }
    }

    // 若启用波形追踪：创建追踪对象、绑定到核心（深度 99）并打开 VCD 文件
    if (enable_trace)
    {
        trace = new VerilatedVcdC;
        core->trace(trace, 99);
        trace->open("trace.vcd");
    }

    // 根据是否使用 MBC，创建相应的存储器仿真对象
    if (usembc)
    {
        mbc = new MBCSIM(); // MBC 仿真：统一管理 ROM/RAM
    }
    else
    {
        cartrom = new MEMSIM(0x0000, 32768); // ROM 直接映射在 0x0000，大小 32KB
        cartram = new MEMSIM(0xa000, 8192);  // 卡带 RAM 映射在 0xa000，大小 8KB
    }

    if (!quiet)
    {
        dispsim = new DISPSIM(); // 非静默模式下创建显示仿真（打开 SDL 窗口）
    }
    if (verbose)
    {
        mmrprobe = new MMRPROBE(); // 详细模式下创建 MMR 探针
    }
    if (itrace)
    {
        // 打开指令追踪输出文件；失败则关闭追踪并提示错误
        it = fopen("itrace.txt", "w");
        if (!it)
        {
            itrace = false;
            fprintf(stderr, "Fail to open output file for itrace.\n");
        }
    }

    // 加载目标 ROM 文件：使用 MBC 时由 MBC 加载，否则由 ROM 仿真对象加载
    if (usembc)
        mbc->load(argv[1]);
    else
        cartrom->load(argv[1]);

    if (enable_audio)
    {
        audiosim = new AUDIOSIM(); // 启用音频时创建音频仿真对象
    }

    // Start simulation
    // 仿真开始提示（详细模式）
    if (verbose)
        printf("Simulation start.\n");

    reset(); // 执行复位流程

    uint32_t sim_tick = 0;             // 用于统计仿真速度的周期计数器
    uint32_t ms_tick = SDL_GetTicks(); // 记录上一次更新窗口标题的时间（毫秒）
    char window_title[63];             // 窗口标题缓冲区
    bool running = true;               // 主循环运行标志

    // 主仿真循环
    while (running)
    {
        tick();     // 执行一个时钟周期
        sim_tick++; // 速度统计计数加一

        // Check end condition
        // 检查结束条件
        if (SIGNAL(u_cpu__DOT__last_pc) == breakpoint)
        {
            // 到达断点地址，停止仿真
            printf("Hit breakpoint\n");
            running = false;
        }

        // 静默模式且未指定 --nostop 时，若周期数超过上限则停止
        if ((tickcount > CYCLE_LIMIT) && (quiet) && (!nostop))
        {
            printf("Time Limit Exceeded\n");
            running = false;
        }

        // 核心出现错误（fault）信号，停止仿真
        if (core->fault)
        {
            printf("Core fault condition\n");
            running = false;
        }

        // 核心执行完成（如 STOP/HALT）且未指定 --nostop 时停止
        if (core->done && !nostop)
        {
            printf("Core STOP/HALT/FAULT\n");
            running = false;
        }

        // Get the next event
        if (!quiet & (sim_tick % 1024 == 0))
        {
            SDL_Event event;
            if (SDL_PollEvent(&event))
            { // 轮询 SDL 事件队列
                if (event.type == SDL_QUIT)
                {
                    // Break out of the loop on quit
                    // 收到窗口关闭事件，退出主循环
                    running = false;
                }
                else if ((event.type == SDL_KEYDOWN) || (event.type == SDL_KEYUP))
                {
                    // 键盘按下/抬起事件：把按键映射为 Game Boy 按键位掩码
                    uint8_t keycode = 0;
                    switch (event.key.keysym.sym)
                    {
                    case SDLK_DOWN: // 下方向键 → 方向键下（bit7）
                        // puts("down");
                        keycode = 0x80;
                        break;
                    case SDLK_UP: // 上方向键 → 方向键上（bit6）
                        // puts("up");
                        keycode = 0x40;
                        break;
                    case SDLK_LEFT: // 左方向键 → 方向键左（bit5）
                        // puts("left");
                        keycode = 0x20;
                        break;
                    case SDLK_RIGHT: // 右方向键 → 方向键右（bit4）
                        // puts("right");
                        keycode = 0x10;
                        break;
                    case SDLK_x: // X 键 → A 键（bit2）
                        // puts("A");
                        keycode = 0x01;
                        break;
                    case SDLK_z: // Z 键 → B 键（bit3）
                        // puts("B");
                        keycode = 0x02;
                        break;
                    case SDLK_a: // A 键 → 选择键（bit1）
                        // puts("Sel");
                        keycode = 0x04;
                        break;
                    case SDLK_s: // S 键 → 开始键（bit0）
                        // puts("Start");
                        keycode = 0x08;
                        break;
                    case SDLK_q:
                        running = false;
                        break;
                    default: // 其他按键忽略
                        break;
                    }
                    if (event.type == SDL_KEYDOWN)
                        core->key &= ~keycode; // 按下：把对应位写 0
                    else
                        core->key |= keycode; // 抬起：把对应位写 1
                }
            }
        }

        // 每秒刷新一次窗口标题，避免频繁调用 SDL 和字符串格式化
        if (!quiet)
        {
            uint32_t now = SDL_GetTicks();
            uint32_t ms_delta = now - ms_tick;
            if (ms_delta >= 1000)
            {
                int sim_freq = sim_tick / ms_delta; // 仿真频率 = 周期数/毫秒（kHz）
                float runRate = sim_freq / (4194.304) * 100;
                sim_tick = 0;
                sprintf(window_title, "(%d kHz) %.1f%%", sim_freq, runRate);
                dispsim->set_title(window_title);
                ms_tick = now;
            }
        }
    }

    if (quiet)
    {
        // output result to file
        // 测试模式：把最终 CPU 寄存器状态写入结果文件（格式固定，供测试比对）
        FILE *result;
        result = fopen(result_file, "w+");
        assert(result); // 打开失败则断言终止
        fprintf(result, "AF %02x%02x\r\n",
                SIGNAL(u_cpu__DOT__acc__DOT__data), // A 累加器
                SIGNAL(u_cpu__DOT__flags) << 4);    // F 标志寄存器（左移 4 位对齐格式）
        fprintf(result, "BC %02x%02x\r\n",
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[0]),  // B
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[1])); // C
        fprintf(result, "DE %02x%02x\r\n",
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[2]),  // D
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[3])); // E
        fprintf(result, "HL %02x%02x\r\n",
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[4]),  // H
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[5])); // L
        fprintf(result, "SP %02x%02x\r\n",
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[6]),  // SP 高字节
                SIGNAL(u_cpu__DOT__regfile__DOT__regs[7])); // SP 低字节
        fprintf(result, "PC %04x\r\n",
                SIGNAL(u_cpu__DOT__pc)); // 程序计数器
        fclose(result);                  // 关闭结果文件

        printf("AF %02x%02x\n", SIGNAL(u_cpu__DOT__acc__DOT__data), SIGNAL(u_cpu__DOT__flags));
        printf("BC %02x%02x\n", SIGNAL(u_cpu__DOT__regfile__DOT__regs[0]), SIGNAL(u_cpu__DOT__regfile__DOT__regs[1]));
        printf("DE %02x%02x\n", SIGNAL(u_cpu__DOT__regfile__DOT__regs[2]), SIGNAL(u_cpu__DOT__regfile__DOT__regs[3]));
        printf("HL %02x%02x\n", SIGNAL(u_cpu__DOT__regfile__DOT__regs[4]), SIGNAL(u_cpu__DOT__regfile__DOT__regs[5]));
        printf("SP %02x%02x\n", SIGNAL(u_cpu__DOT__regfile__DOT__regs[6]), SIGNAL(u_cpu__DOT__regfile__DOT__regs[7]));
        printf("PC %04x\n", SIGNAL(u_cpu__DOT__pc));
    }
    // print on screen
    // 在屏幕上打印最终 CPU 寄存器状态（与 itrace 相同格式）
    printf("PC = %04x, F = %c%c%c%c, A = %02x, SP = %02x%02x\nB = %02x, C = %02x, D = %02x, E = %02x, H = %02x, L = %02x\n",
           SIGNAL(u_cpu__DOT__pc), // 程序计数器
           // 标志按位解析输出字符：Z/N/H/C 或 -
           ((SIGNAL(u_cpu__DOT__flags)) & 0x8) ? 'Z' : '-', // 零标志
           ((SIGNAL(u_cpu__DOT__flags)) & 0x4) ? 'N' : '-', // 减法标志
           ((SIGNAL(u_cpu__DOT__flags)) & 0x2) ? 'H' : '-', // 半进位标志
           ((SIGNAL(u_cpu__DOT__flags)) & 0x1) ? 'C' : '-', // 进位标志
           SIGNAL(u_cpu__DOT__acc__DOT__data),              // 累加器 A
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[6]),       // SP 高字节
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[7]),       // SP 低字节
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[0]),       // B
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[1]),       // C
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[2]),       // D
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[3]),       // E
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[4]),       // H
           SIGNAL(u_cpu__DOT__regfile__DOT__regs[5])        // L
    );

    if (enable_trace)
    {
        trace->close(); // 关闭 VCD 波形文件
    }

    // 释放所有动态分配的对象资源
    delete core; // 释放仿真核心
    if (!quiet)
    {
        delete dispsim; // 释放显示仿真
    }
    if (verbose)
    {
        delete mmrprobe; // 释放 MMR 探针
    }
    if (it)
    {
        fclose(it); // 关闭指令追踪文件
    }
    if (usembc)
    {
        delete mbc; // 释放 MBC 仿真
    }
    else
    {
        delete cartrom; // 释放 ROM 仿真
        delete cartram; // 释放 RAM 仿真
    }
    if (enable_audio)
    {
        audiosim->save("audio.wav"); // 退出时把内存中累积的音频一次性保存为 WAV
        delete audiosim;             // 释放音频仿真
    }

    return 0; // 正常退出
}