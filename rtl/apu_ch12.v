`timescale 1ns / 1ps

module apu_ch12(
    input clk,
    input rst,
    input clk_256hz, // 音长用
    input clk_128hz, // 扫频用
    input clk_64hz,  // 包络用
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_nrx0,
    output [7:0] reg_nrx1,
    output [7:0] reg_nrx2,
    output [7:0] reg_nrx3,
    output [7:0] reg_nrx4,
    input apu_enable,
    output [3:0] level,
    output active
);
    
    parameter  FEATURE_SWEEP  = 1;
    parameter  MMIO_BASE_ADDR = 16'hff10;
    
    localparam [15:0] ADDR_NRx0 = MMIO_BASE_ADDR+16'd0;
    localparam [15:0] ADDR_NRx1 = MMIO_BASE_ADDR+16'd1;
    localparam [15:0] ADDR_NRx2 = MMIO_BASE_ADDR+16'd2;
    localparam [15:0] ADDR_NRx3 = MMIO_BASE_ADDR+16'd3;
    localparam [15:0] ADDR_NRx4 = MMIO_BASE_ADDR+16'd4;
    
    
    // $FF10    NR10    Sound channel 1 sweep    R/W    All
    // |      | 7   | 6 5 4 | 3         | 2 1 0           |
    // | ---- | --- | ----- | --------- | --------------- |
    // | NR10 |     | Pace  | Direction | Individual step |
    // - bit 654: 扫频间隔 0不扫频 1-7对应 7.8ms ~ 54.7ms
    //     迭代结束、重新触发才会更新
    //     写0会立刻停止扫频，停止时写其它值会立刻恢复
    //     000: Sweep OFF
    //     001: ts=1/f128 (7.8ms)
    //     010: ts=2/f128 (15.6ms)
    //     011: ts=3/f128 (23.4ms)
    //     100: ts=4/f128 (31.3ms)
    //     101: ts=5/f128 (39.1ms)
    //     110: ts=6/f128 (46.9ms)
    //     111: ts=7/f128 (54.7ms)
    // - bit 3: 扫频方向 0频率递增 1频率递减
    // - bit 210: 每次扫频步长，X(t) = X(t-1) ± X(t-1) / 2^n
    //     X(t)是下一步频率 X(t-1)当前频率
    // - 递增加到11位溢出会立刻关闭通道
    // - 递减到0会保持不变，但不会关闭
    reg [2:0] sweep_interval;
    reg       sweep_dir;
    reg [2:0] sweep_step;
    
    always @(posedge clk) begin
        if ((!FEATURE_SWEEP) || (rst) || (!apu_enable)) begin
            sweep_interval <= 3'd0;
            sweep_dir      <= 1'd0;
            sweep_step     <= 3'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == ADDR_NRx0)) begin
                sweep_interval <= cpu_dout[6:4];
                sweep_dir      <= cpu_dout[3];
                sweep_step     <= cpu_dout[2:0];
            end
        end
    end
    
    // $FF11    NR11    Sound channel 1 length timer & duty cycle    Mixed    All
    // |      | 7 6       | 5 4 3 2 1 0          |
    // | ---- | --------- | -------------------- |
    // | NR11 | Wave duty | Initial length timer |
    // - bit 76: (Read/Write) 输出低电平的占空比(老任手册说是高电平)，00-11 表示 12.5% 25% 50% 75%，25和75听起来是一样的
    // - bit 543210: (Write-only) 声音长度，播放时间 = (64-n)*(1/256) 秒，如果NR14设置连续则无效
    reg [1:0] wave_duty;
    reg [5:0] wave_length;
    reg       renewLength;
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            wave_duty   <= 2'd0;
            wave_length <= 6'd0;
            renewLength <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == ADDR_NRx1)) begin
                wave_duty   <= cpu_dout[7:6];
                wave_length <= cpu_dout[5:0]; // apu关闭时 dmg可写 cgb不可写
                renewLength <= 1'd1;
            end
            else begin
                if (renewLength) begin
                    renewLength <= 1'd0;
                end
            end
        end
    end
    
    // $FF12    NR12    Sound channel 1 volume & envelope    R/W    All
    // |      | 7 6 5 4        | 3       | 2 1 0      |
    // | ---- | -------------- | ------- | ---------- |
    // | NR12 | Initial volume | Env dir | Sweep pace |
    // - bit 7654: 通道的初始音量 0静音，f最大声
    // - bit 3:    包络方向，0衰减，1递增
    // - bit 210:  包络时长，每步 N*(1/64) 秒，0不包络
    // - 包络到顶或到底后，维持最大最小值
    // if [NRx2] & $F8 != 0 则开启DAC，因为开关dac会pop，所以即使没声音也会写个0x08进来
    reg [3:0] initial_vol;
    reg       env_dir;
    reg [2:0] env_interval;
    
    wire dacOn = ({initial_vol, env_dir} != 5'd0);
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            initial_vol  <= 4'd0;
            env_dir      <= 1'd0;
            env_interval <= 3'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == ADDR_NRx2)) begin
                initial_vol  <= cpu_dout[7:4];
                env_dir      <= cpu_dout[3];
                env_interval <= cpu_dout[2:0];
            end
        end
    end
    
    // $FF13    NR13    Sound channel 1 period low    W    All
    // - 11位频率值 的低 8 位
    // - 最终频率计算公式 f = 4194304 / (4 * 8 * (2048 - period)) Hz，0:64Hz 2047:131.1kHz
    reg [7:0] period_l;
    reg       renewNR13;
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            period_l  <= 8'd0;
            renewNR13 <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == ADDR_NRx3)) begin
                period_l  <= cpu_dout[7:0];
                renewNR13 <= 1'd1;
            end
            else begin
                if (renewNR13) begin
                    renewNR13 <= 1'd0;
                end
            end
        end
    end
    
    // $FF14    NR14    Sound channel 1 period high & control    Mixed    All
    // |      | 7       | 6             | 5 4 3 | 2 1 0  |
    // | ---- | ------- | ------------- | ----- | ------ |
    // | NR14 | Trigger | Length enable |       | Period |
    // - bit 7: (Write-only) 开启或重启通道，应用上面寄存器的参数
    // - bit 6: 0：无限输出 1：由NR11决定输出时长
    // - bit 210: (Write-only) 11位频率值的高3位
    reg       trigger;
    reg       lenEn;
    reg [2:0] period_h;
    reg       renewNR14;
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            trigger   <= 1'd0;
            lenEn     <= 1'd0;
            period_h  <= 'd0;
            renewNR14 <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == ADDR_NRx4)) begin
                trigger   <= cpu_dout[7];
                lenEn     <= cpu_dout[6];
                period_h  <= cpu_dout[2:0];
                renewNR14 <= 1'd1;
            end
            else begin
                if (trigger) begin
                    trigger <= 1'b0;
                end
                if (renewNR14) begin
                    renewNR14 <= 1'd0;
                end
            end
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // 音长
    wire active_length; // 可发声
    
    apu_length_ctr #(
        .WIDTH (6)
    ) u_length (
        .clk         (clk),
        // .rst (rst || !apu_enable || !dacOn),
        .rst         (rst || !apu_enable),
        .dacOn       (dacOn),
        .clk_256hz   (clk_256hz),
        .renewLength (renewLength),
        .trigger     (trigger),
        .lenEn       (lenEn),
        .length      (wave_length),
        .active      (active_length)
    );
    
    
    // 扫频
    wire [10:0] initial_period = {period_h, period_l};
    wire [10:0] sweep_period;
    wire        active_sweep;
    
    apu_sweep_ctr u_sweep(
        .clk            (clk),
        .rst            (rst || !apu_enable),
        .clk_128hz      (clk_128hz),
        .renewNR13      (renewNR13),
        .renewNR14      (renewNR14),
        .trigger        (trigger),
        .dir            (sweep_dir),
        .interval       (sweep_interval),
        .step           (sweep_step),
        .initial_period (initial_period),
        .sweep_period   (sweep_period),
        .active         (active_sweep)
    );
    
    
    // 包络
    wire [3:0] env_volume;
    
    apu_vol_env u_envelope(
        .clk            (clk),
        .rst            (rst || !apu_enable),
        .clk_64hz       (clk_64hz),
        .trigger        (trigger),
        .initial_volume (initial_vol),
        .dir            (env_dir),
        .interval       (env_interval),
        .volume         (env_volume)
    );
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // 生成波形
    
    // 播放时基
    // 最终频率公式 f = 4194304 / (4 * 8 * (2048 - period)) Hz，0:64Hz 2047:131.1kHz
    //   f = 131072 / (2048-period)
    // 8xf = 1048576 / (2048-period)
    reg [1:0] cnt_clk;
    wire      clk_1m = cnt_clk[1]; // 4194304Hz / 4 = 1048576Hz
    wire      pluse_1m;
    
    always @(posedge clk) begin
        if (rst || !apu_enable)
            cnt_clk <= 2'd0;
        else
            cnt_clk <= cnt_clk + 2'd1;
    end
    
    edgedet u_ed1 (
        .clk (clk),
        .i   (clk_1m),
        .o   (pluse_1m)
    );
    
    // 波形选择
    reg [7:0] waveform;
    reg [2:0] wave_phase;
    wire      wave_level = waveform[wave_phase];
    
    always @(*) begin
        case(wave_duty)
            2'd0: waveform = 8'b01111111; // 12.5%
            2'd1: waveform = 8'b01111110; // 25%
            2'd2: waveform = 8'b00011110; // 50%
            2'd3: waveform = 8'b10000001; // 75%
        endcase
    end
    
    // 电平
    reg [10:0] cnt_waveGen;
    
    always @(posedge clk) begin
        if (rst || !active) begin
            cnt_waveGen <= 11'd0;
            wave_phase  <= 3'd0;
        end
        else begin
            if (trigger) begin
                cnt_waveGen <= (FEATURE_SWEEP) ? sweep_period : initial_period;
                wave_phase  <= 3'd0;
            end
            else begin
                if (pluse_1m) begin
                    if (cnt_waveGen != 11'd2047) begin
                        cnt_waveGen <= cnt_waveGen + 11'd1;
                    end
                    else begin
                        cnt_waveGen <= (FEATURE_SWEEP) ? sweep_period : initial_period;
                        wave_phase  <= wave_phase + 3'd1;
                    end
                end
            end
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_nrx0 = (FEATURE_SWEEP) ? {1'b1, sweep_interval, sweep_dir ,sweep_step}: 8'hff;
    assign reg_nrx1 = {wave_duty, 6'b111111};
    assign reg_nrx2 = {initial_vol, env_dir, env_interval};
    assign reg_nrx3 = 8'hff;
    assign reg_nrx4 = {1'b1, lenEn, 6'b111111};
    
    assign active = dacOn & active_length & (FEATURE_SWEEP ? active_sweep : 1'd1);
    assign level  = (active & wave_level) ? env_volume : 4'd0;
    
endmodule
