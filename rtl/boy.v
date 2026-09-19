`timescale 1ns / 1ps
// `default_nettype wire
////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Wenting Zhang
//
// Create Date:    17:30:26 02/08/2018
// Module Name:    boy
// Project Name:   VerilogBoy
// Description:
//   VerilogBoy portable top level file. This is the file connect the CPU and
//   all the peripherals in the LR35902 together.
// Dependencies:
//   cpu
// Additional Comments:
//   Hardware specific code should be implemented outside of this file
//   So normally in an implementation, this will not be the top level.
////////////////////////////////////////////////////////////////////////////////

module boy(
    input wire rst,       // 异步复位输入
    input wire clk,       // 4.19MHz 时钟输入
    // 卡带接口
    output cart_phi,      // 1.05MHz 参考时钟输出
    output [15:0] cart_a, // 地址总线
    inout [7:0] cart_d,   // 数据总线
    output cart_d_oe,
    output cart_nWR,
    output cart_nRD,
    output cart_nCS,
    // 键盘输入 bit7-0: down up left right st sel b a
    input wire [7:0] key,
    // 联机口
    output sio_sc_oe,
    inout sio_sc,
    output sio_so,
    input sio_si,
    // LCD 输出
    output wire hs,          // 行同步输出
    output wire vs,          // 场同步输出
    output wire cpl,         // 像素数据锁存
    output wire [1:0] pixel, // 像素数据
    output wire valid,       // de
    // 声音输出
    output signed [15:0] left,
    output signed [15:0] right,
    // 调试接口
    output wire done,
    output wire fault
);
    
    
    // CPU
    wire        cpu_rd;            // CPU 读使能
    wire        cpu_wr;            // CPU 写使能
    reg  [7:0]  cpu_din;           // 送入 CPU 的数据总线
    wire [7:0]  cpu_dout;          // 来自 CPU 的数据总线
    wire [15:0] cpu_a;             // CPU 地址总线
    wire [4:0]  cpu_int_en;        // CPU 中断使能输入
    wire [4:0]  cpu_int_flags_in;  // CPU 中断标志输入
    wire [4:0]  cpu_int_flags_out; // CPU 中断标志输出
    wire [1:0]  cpu_ct;            // 一个 M 周期内的 T 周期编号 (0-3)
    wire [1:0]  bus_op;
    wire        cpu_stop;
    
    cpu u_cpu(
        .clk           (clk),
        .rst           (rst),
        .phi           (cart_phi),
        .ct            (cpu_ct),
        .bus_op        (bus_op),
        .a             (cpu_a),
        .dout          (cpu_dout),
        .din           (cpu_din),
        .rd            (cpu_rd),
        .wr            (cpu_wr),
        .int_en        (cpu_int_en),
        .int_flags_in  (cpu_int_flags_in),
        .int_flags_out (cpu_int_flags_out),
        .done          (done),
        .stop          (cpu_stop),
        .fault         (fault)
    );
    
    
    
    // High RAM
    wire [7:0]  high_ram_dout;
    
    hram u_hram(
        .clk      (clk),
        .rst      (rst),
        .cpu_a    (cpu_a),
        .cpu_dout (cpu_dout),
        .cpu_din  (high_ram_dout),
        .cpu_rd   (cpu_rd),
        .cpu_wr   (cpu_wr)
    );
    
    
    
    // DMA
    wire [15:0] dma_src_a;
    wire        dma_src_rd;
    reg  [7:0]  dma_src_din;
    wire [15:0] dma_dst_a;    // to oam only
    wire [7:0]  dma_dst_dout; // to oam only
    wire        dma_dst_wr;   // to oam only
    wire        dma_occupy;   // to oam only
    
    wire dma_occupy_cart = dma_occupy & (((16'h0000 <= dma_src_a) && (dma_src_a <= 16'h7fff)) || ((16'ha000 <= dma_src_a) && (dma_src_a <= 16'hbfff)));
    wire dma_occupy_wram = dma_occupy &  ((16'hc000 <= dma_src_a) && (dma_src_a <= 16'hfdff));
    wire dma_occupy_vram = dma_occupy &  ((16'h8000 <= dma_src_a) && (dma_src_a <= 16'h9fff));
    
    wire [7:0]  reg_dma;
    
    dma u_dma(
        .clk          (clk),
        .rst          (rst),
        .cpu_ct       (cpu_ct),
        .cpu_a        (cpu_a),
        .cpu_dout     (cpu_dout),
        .cpu_rd       (cpu_rd),
        .cpu_wr       (cpu_wr),
        .reg_dma      (reg_dma),
        .dma_src_a    (dma_src_a),
        .dma_src_din  (dma_src_din),
        .dma_src_rd   (dma_src_rd),
        .dma_dst_a    (dma_dst_a),
        .dma_dst_dout (dma_dst_dout),
        .dma_dst_wr   (dma_dst_wr),
        .dma_occupy   (dma_occupy)
    );
    
    
    
    // Work RAM
    wire [15:0] wram_addr = dma_occupy_wram ? dma_src_a : cpu_a;
    wire [7:0]  wram_dout;
    wire [7:0]  reg_svbk; // gbc only
    
    wram u_wram(
        .clk      (clk),
        .rst      (rst),
        .dmg_mode (1'b1),
        .cpu_rd   (cpu_rd),
        .cpu_a    (wram_addr),
        .cpu_wr   ((!dma_occupy_wram) & (cpu_wr)),
        .cpu_dout (cpu_dout),
        .cpu_din  (wram_dout),
        .reg_svbk (reg_svbk)
    );
    
    
    
    // interrupt
    wire intReq_joypad;
    wire intReq_serial;
    wire intReq_tim;
    wire intReq_lcdc;
    wire intReq_vblank;
    
    wire intAck_joypad;
    wire intAck_serial;
    wire intAck_tim;
    wire intAck_lcdc;
    wire intAck_vblank;
    
    wire [7:0] reg_if;
    wire [7:0] reg_ie;
    
    interrupt u_intr(
        .clk              (clk),
        .rst              (rst),
        .cpu_a            (cpu_a),
        .cpu_dout         (cpu_dout),
        .cpu_rd           (cpu_rd),
        .cpu_wr           (cpu_wr),
        .reg_if           (reg_if),
        .reg_ie           (reg_ie),
        .cpu_int_en       (cpu_int_en),
        .cpu_int_flag     (cpu_int_flags_in),
        .cpu_int_flag_out (cpu_int_flags_out),
        .req_vBlank       (intReq_vblank),
        .req_stat         (intReq_lcdc),
        .req_timer        (intReq_tim),
        .req_serial       (intReq_serial),
        .req_joypad       (intReq_joypad),
        .ack_vBlank       (intAck_vblank),
        .ack_stat         (intAck_lcdc),
        .ack_timer        (intAck_tim),
        .ack_serial       (intAck_serial),
        .ack_joypad       (intAck_joypad)
    );
    
    
    
    // Keypad
    wire [7:0] reg_joyp;
    
    joypad u_joypad(
        .clk      (clk),
        .rst      (rst),
        .cpu_a    (cpu_a),
        .cpu_rd   (cpu_rd),
        .cpu_wr   (cpu_wr),
        .cpu_dout (cpu_dout),
        .reg_joyp (reg_joyp),
        .intReq   (intReq_joypad),
        .intAck   (intAck_joypad),
        .keys     (key)
    );
    
    
    
    // Timer
    wire [7:0] reg_div;
    wire [7:0] reg_tima;
    wire [7:0] reg_tma;
    wire [7:0] reg_tac;
    
    timer u_timer(
        .clk      (clk),
        .rst      (rst),
        .cpu_stop (cpu_stop),
        .cpu_ct   (cpu_ct),
        .cpu_a    (cpu_a),
        .cpu_dout (cpu_dout),
        .cpu_rd   (cpu_rd),
        .cpu_wr   (cpu_wr),
        .reg_div  (reg_div),
        .reg_tima (reg_tima),
        .reg_tma  (reg_tma),
        .reg_tac  (reg_tac),
        .intReq   (intReq_tim),
        .intAck   (intAck_tim)
    );
    
    
    
    // Serial
    wire [7:0] reg_sc;
    wire [7:0] reg_sb;
    
    serial u_serial(
        .clk       (clk),
        .rst       (rst),
        .dmg_mode  (1'b1),
        .cpu_a     (cpu_a),
        .cpu_dout  (cpu_dout),
        .cpu_rd    (cpu_rd),
        .cpu_wr    (cpu_wr),
        .reg_sc    (reg_sc),
        .reg_sb    (reg_sb),
        .intReq    (intReq_serial),
        .intAck    (intAck_serial),
        .sio_sc_oe (sio_sc_oe),
        .sio_sc    (sio_sc),
        .sio_so    (sio_so),
        .sio_si    (sio_si)
    );
    
    
    
    // Sound
    wire [7:0] reg_nr10;
    wire [7:0] reg_nr11;
    wire [7:0] reg_nr12;
    wire [7:0] reg_nr13;
    wire [7:0] reg_nr14;
    wire [7:0] reg_nr21;
    wire [7:0] reg_nr22;
    wire [7:0] reg_nr23;
    wire [7:0] reg_nr24;
    wire [7:0] reg_nr30;
    wire [7:0] reg_nr31;
    wire [7:0] reg_nr32;
    wire [7:0] reg_nr33;
    wire [7:0] reg_nr34;
    wire [7:0] reg_nr41;
    wire [7:0] reg_nr42;
    wire [7:0] reg_nr43;
    wire [7:0] reg_nr44;
    wire [7:0] reg_nr50;
    wire [7:0] reg_nr51;
    wire [7:0] reg_nr52;
    wire [7:0] reg_pcm12;
    wire [7:0] reg_pcm34;
    wire [7:0] reg_waveRam;
    
    apu u_sound(
        .clk             (clk),
        .rst             (rst),
        .doubleSpeedMode (1'd0),
        .cpu_ct          (cpu_ct),
        .cpu_a           (cpu_a),
        .cpu_dout        (cpu_dout),
        .cpu_rd          (cpu_rd),
        .cpu_wr          (cpu_wr),
        .reg_div         (reg_div),
        .reg_nr10        (reg_nr10),
        .reg_nr11        (reg_nr11),
        .reg_nr12        (reg_nr12),
        .reg_nr13        (reg_nr13),
        .reg_nr14        (reg_nr14),
        .reg_nr21        (reg_nr21),
        .reg_nr22        (reg_nr22),
        .reg_nr23        (reg_nr23),
        .reg_nr24        (reg_nr24),
        .reg_nr30        (reg_nr30),
        .reg_nr31        (reg_nr31),
        .reg_nr32        (reg_nr32),
        .reg_nr33        (reg_nr33),
        .reg_nr34        (reg_nr34),
        .reg_nr41        (reg_nr41),
        .reg_nr42        (reg_nr42),
        .reg_nr43        (reg_nr43),
        .reg_nr44        (reg_nr44),
        .reg_nr50        (reg_nr50),
        .reg_nr51        (reg_nr51),
        .reg_nr52        (reg_nr52),
        .reg_pcm12       (reg_pcm12),
        .reg_pcm34       (reg_pcm34),
        .reg_waveRam     (reg_waveRam),
        .cart_vin        (4'sd0),
        .left            (left),
        .right           (right)
    );
    
    
    
    // PPU
    wire [7:0]  reg_ppu;
    wire [7:0]  vram_dout;
    wire [7:0]  oam_dout;
    
    wire [15:0] vram_a     = (dma_occupy_vram) ? dma_src_a : cpu_a;
    wire        range_vram = (16'h8000 <= cpu_a) && (cpu_a <= 16'h9fff);
    wire        range_oam  = (16'hfe00 <= cpu_a) && (cpu_a <= 16'hfe9f);
    
    wire        oam_wr  = (dma_occupy) ? (dma_dst_wr)   : (range_oam & cpu_wr);
    wire [15:0] oam_a   = (dma_occupy) ? (dma_dst_a)    : (cpu_a);
    wire [7:0]  oam_din = (dma_occupy) ? (dma_dst_dout) : (cpu_dout);
    
    ppu u_ppu(
        .clk            (clk),
        .rst            (rst),
        /* mmio bus is always accessable to CPU */
        .mmio_a         (cpu_a),
        .mmio_dout      (reg_ppu),
        .mmio_din       (cpu_dout),
        .mmio_rd        (cpu_rd),
        .mmio_wr        (cpu_wr),
        ///////////////////////////////////////////////////////////
        .vram_a         (vram_a),
        .vram_dout      (vram_dout),
        .vram_din       (cpu_dout),
        .vram_rd        (vram_rd),
        .vram_wr        (((!dma_occupy_vram) & range_vram & cpu_wr)),
        ///////////////////////////////////////////////////////////
        .oam_a          (oam_a),
        .oam_dout       (oam_dout),
        .oam_din        (oam_din),
        .oam_rd         (oam_rd),
        .oam_wr         (oam_wr),
        ///////////////////////////////////////////////////////////
        .int_vblank_req (intReq_vblank),
        .int_lcdc_req   (intReq_lcdc),
        .int_vblank_ack (intAck_vblank),
        .int_lcdc_ack   (intAck_lcdc),
        .cpl            (cpl),
        .pixel          (pixel),
        .valid          (valid),
        .hs             (hs),
        .vs             (vs),
        // Ignore the debugging interface
        /* verilator lint_off PINCONNECTEMPTY */
        .scx            (),
        .scy            (),
        .state          ()
        /* verilator lint_on PINCONNECTEMPTY */
    );
    
    
    
    // Boot ROM
    wire       brom_overwrite;
    wire [7:0] brom_dout;
    
    brom u_brom(
        .clk            (clk),
        .rst            (rst),
        .cpu_a          (cpu_a),
        .cpu_wr         (cpu_wr),
        .cpu_din        (brom_dout),
        .brom_overwrite (brom_overwrite)
    );
    
    
    // External Bus
    wire [15:0] ext_addr = (dma_occupy_cart) ? dma_src_a : cpu_a;
    
    cartridge u_cart(
        .clk        (clk),
        .rst        (rst),
        .cpu_a      (ext_addr), // gbc应该应该独立
        .cpu_dout   (cpu_dout),
        .cpu_ct     (cpu_ct),
        .bus_op     (bus_op),
        .dma_occupy (dma_occupy_cart),
        .cart_a     (cart_a),
        .cart_d     (cart_d),
        .cart_d_oe  (cart_d_oe),
        .cart_nCS   (cart_nCS),
        .cart_nWR   (cart_nWR),
        .cart_nRD   (cart_nRD)
    );
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // Bus Multiplexing, DMA
    always @(*) begin
        // vram
        if ((16'h8000 <= dma_src_a) && (dma_src_a <= 16'h9fff)) begin
            dma_src_din = vram_dout;
        end
        // WRAM
        else if ((16'hc000 <= dma_src_a) && (dma_src_a <= 16'hfdff)) begin
            dma_src_din = wram_dout;
        end
        else begin
            dma_src_din = cart_d;
        end
    end
    
    
    // Bus Multiplexing, CPU
    always @(*) begin
        //
        // ---------- 以下由 CPU 与 DMA 共享 ----------
        //
        // cart rom
        if ((16'h0000 <= cpu_a) && (cpu_a <= 16'h7fff)) begin
            cpu_din = (dma_occupy_cart) ? 8'hff : (brom_overwrite) ? brom_dout : cart_d;
        end
        // vram
        else if ((16'h8000 <= cpu_a) && (cpu_a <= 16'h9fff)) begin
            cpu_din = (dma_occupy_vram) ? 8'hff : vram_dout;
        end
        // cart ram
        else if ((16'ha000 <= cpu_a) && (cpu_a <= 16'hbfff)) begin
            cpu_din = (dma_occupy_cart) ? 8'hff : cart_d;
        end
        // WRAM
        else if ((16'hc000 <= cpu_a) && (cpu_a <= 16'hfdff)) begin
            cpu_din = (dma_occupy_wram) ? 8'hff : wram_dout;
        end
        // OAM
        else if ((16'hfe00 <= cpu_a) && (cpu_a <= 16'hfe9f)) begin
            cpu_din = (dma_occupy) ? 8'hff : oam_dout;
        end
        //
        // ---------- 以下仅由 CPU 专用 ----------
        //
        // $FF00    P1/JOYP
        else if (cpu_a == 16'hff00) begin
            cpu_din = reg_joyp;
        end
        // $FF01    SB
        else if (cpu_a == 16'hff01) begin
            cpu_din = reg_sb;
        end
        // $FF02    SC
        else if (cpu_a == 16'hff02) begin
            cpu_din = reg_sc;
        end
        // $FF04    DIV
        else if (cpu_a == 16'hff04) begin
            cpu_din = reg_div;
        end
        // $FF05    TIMA
        else if (cpu_a == 16'hff05) begin
            cpu_din = reg_tima;
        end
        // $FF06    TMA
        else if (cpu_a == 16'hff06) begin
            cpu_din = reg_tma;
        end
        // $FF07    TAC
        else if (cpu_a == 16'hff07) begin
            cpu_din = reg_tac;
        end
        // $FF0F    IF
        else if (cpu_a == 16'hff0f) begin
            cpu_din = reg_if;
        end
        /****************** Sound ******************/
        // $FF10: NR10   |  $FF11: NR11   |  $FF12: NR12   |  $FF13: NR13   |  $FF14: NR14
        else if (cpu_a == 16'hff10) begin
            cpu_din = reg_nr10;
        end
        else if (cpu_a == 16'hff11) begin
            cpu_din = reg_nr11;
        end
        else if (cpu_a == 16'hff12) begin
            cpu_din = reg_nr12;
        end
        else if (cpu_a == 16'hff13) begin
            cpu_din = reg_nr13;
        end
        else if (cpu_a == 16'hff14) begin
            cpu_din = reg_nr14;
        end
        // $FF15: [N/A]  |  $FF16: NR21   |  $FF17: NR22   |  $FF18: NR23   |  $FF19: NR24
        else if (cpu_a == 16'hff16) begin
            cpu_din = reg_nr21;
        end
        else if (cpu_a == 16'hff17) begin
            cpu_din = reg_nr22;
        end
        else if (cpu_a == 16'hff18) begin
            cpu_din = reg_nr23;
        end
        else if (cpu_a == 16'hff19) begin
            cpu_din = reg_nr24;
        end
        // $FF1A: NR30   |  $FF1B: NR31   |  $FF1C: NR32   |  $FF1D: NR33   |  $FF1E: NR34
        else if (cpu_a == 16'hff1a) begin
            cpu_din = reg_nr30;
        end
        else if (cpu_a == 16'hff1b) begin
            cpu_din = reg_nr31;
        end
        else if (cpu_a == 16'hff1c) begin
            cpu_din = reg_nr32;
        end
        else if (cpu_a == 16'hff1d) begin
            cpu_din = reg_nr33;
        end
        else if (cpu_a == 16'hff1e) begin
            cpu_din = reg_nr34;
        end
        // $FF1F: [N/A]  |  $FF20: NR41   |  $FF21: NR42   |  $FF22: NR43   |  $FF23: NR44
        else if (cpu_a == 16'hff20) begin
            cpu_din = reg_nr41;
        end
        else if (cpu_a == 16'hff21) begin
            cpu_din = reg_nr42;
        end
        else if (cpu_a == 16'hff22) begin
            cpu_din = reg_nr43;
        end
        else if (cpu_a == 16'hff23) begin
            cpu_din = reg_nr44;
        end
        // $FF24: NR50   |  $FF25: NR51   |  $FF26: NR52
        else if (cpu_a == 16'hff24) begin
            cpu_din = reg_nr50;
        end
        else if (cpu_a == 16'hff25) begin
            cpu_din = reg_nr51;
        end
        else if (cpu_a == 16'hff26) begin
            cpu_din = reg_nr52;
        end
        // $FF30-FF3F: Wave RAM
        else if ((16'hff30 <= cpu_a) && (cpu_a <= 16'hff3f)) begin
            cpu_din = reg_waveRam;
        end
        // $FF46    DMA
        else if (cpu_a == 16'hff46) begin
            cpu_din = reg_dma;
        end
        /****************** PPU ******************/
        // $FF40    LCDC   |  $FF41    STAT   |  $FF42    SCY   |  $FF43    SCX
        // $FF44    LY     |  $FF45    LYC    |  $ff46-$ff49    [N/A]
        // $FF4A    WY     |  $FF4B    WX
        else if (cpu_a >= 16'hff40 && cpu_a <= 16'hff4b) begin
            cpu_din = reg_ppu;
        end
        // $FF50    Boot ROM mapping control
        else if (cpu_a == 16'hff50) begin
            cpu_din = 8'hff;
        end
        // $FF70    SVBK/WBK    CGB
        else if (cpu_a == 16'hff07) begin
            cpu_din = reg_svbk;
        end
        // $FF76    PCM12    CGB
        else if (cpu_a == 16'hff76) begin
            cpu_din <= reg_pcm12;
        end
        // $FF77    PCM34    CGB
        else if (cpu_a == 16'hff77) begin
            cpu_din <= reg_pcm34;
        end
        // 0xFF80~0xfffe   High RAM
        else if ((16'hff80 <= cpu_a) && (cpu_a <= 16'hfffe)) begin
            cpu_din = high_ram_dout;
        end
        // $FFFF    IE
        else if (cpu_a == 16'hffff) begin
            cpu_din = reg_ie;
        end
        else begin
            cpu_din = 8'hff;
        end
    end
    
    
endmodule
