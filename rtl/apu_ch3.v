`timescale 1ns / 1ps

module apu_ch3(
    input clk,
    input rst,
    input clk_256hz, // 音长用
    input [1:0] cpu_ct,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_nr30,
    output [7:0] reg_nr31,
    output [7:0] reg_nr32,
    output [7:0] reg_nr33,
    output [7:0] reg_nr34,
    output [7:0] reg_waveRam,
    input apu_enable,
    output [3:0] level,
    output active
);
    
    
    // $FF1A    NR30    Sound channel 3 DAC enable    R/W    All
    // |      | 7          | 6 5 4 3 2 1 0 |
    // | ---- | ---------- | ------------- |
    // | NR30 | DAC on/off |               |
    // - dac开关，与其它通道不同
    reg dacOn;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            dacOn <= 1'b0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hFF1A)) begin
                dacOn <= cpu_dout[7];
            end
        end
    end
    
    
    // $FF1B    NR31    Sound channel 3 length timer    W    All
    // - 播放时长 = (256-n)*(1/256) 秒，比通道12多2位
    reg [7:0] wave_length;
    reg       renewLength;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            wave_length <= 8'd0;
            renewLength <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hFF1B)) begin
                wave_length <= cpu_dout[7:0];
                renewLength <= 1'd1;
            end
            else begin
                if (renewLength) begin
                    renewLength <= 1'd0;
                end
            end
        end
    end
    
    
    // $FF1C    NR32    Sound channel 3 output level    R/W    All
    // |      | 7   | 6 5          | 4 3 2 1 0 |
    // | ---- | --- | ------------ | --------- |
    // | NR32 |     | Output level |           |
    // - 音量，只有2位
    //     00: Mute
    //     01: sample >> 0.
    //     10: sample >> 1 (1/2).
    //     11: sample >> 2 (1/4).
    reg [1:0] wave_volume;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            wave_volume <= 2'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hFF1C)) begin
                wave_volume <= cpu_dout[6:5];
            end
        end
    end
    
    
    // $FF1D    NR33    Sound channel 3 period low    W    All
    // - 同 NR13，以此频率循环播放32个采样
    reg [7:0] period_l;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            period_l <= 8'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hFF1D)) begin
                period_l <= cpu_dout[7:0];
            end
        end
    end
    
    
    // $FF1E    NR34    Sound channel 3 period high & control    Mixed    All
    // |      | 7       | 6             | 5 4 3 | 2 1 0  |
    // | ---- | ------- | ------------- | ----- | ------ |
    // | NR34 | Trigger | Length enable |       | Period |
    reg       trigger;
    reg       lenEn;
    reg [2:0] period_h;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            trigger  <= 1'd0;
            lenEn    <= 1'd0;
            period_h <= 'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hFF1E)) begin
                trigger  <= cpu_dout[7];
                lenEn    <= cpu_dout[6];
                period_h <= cpu_dout[2:0];
            end
            else begin
                // 对齐一个m-cycle
                if (trigger && (cpu_ct == 2'd3)) begin
                    trigger <= 1'b0;
                end
            end
        end
    end
    
    
    // $FF30-FF3F    Wave RAM    Storage for one of the sound channels’ waveform    R/W    All
    // - 16字节，4bit 32个采样，先高4位后低4位，FF30(高4位 -> 低4位) ---> FF3F(低4位)
    // - 但是通道触发时先播放索引1，即ff30低4位，非高4位
    // - 通道激活时，AGB读ff写无效
    //              DMG仅当ch3访问时一瞬间可读写，否则返回ff
    //              CGB读写都会“重映射”到通道当前正在读取的那个字节
    // - 通道未激活时可读写，即使apu关闭
    wire       range_waveRam = ((16'hff30 <= cpu_a) && (cpu_a <= 16'hff3f));
    
    reg  [4:0] sampIndex; // bit0 0:高4位 1:低4位
    wire [3:0] waveRam_a = active ? sampIndex[4:1] : cpu_a[3:0];
    wire [7:0] waveRam_dout;
    
    singleport_ram #(
        .WORDS (16),
        .ABITS (4)
    ) wave_ram (
        .clka  (clk),
        .wea   ((cpu_wr) & (range_waveRam)),
        .addra (waveRam_a),
        .dina  (cpu_dout),
        .douta (waveRam_dout)
    );
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // 音长
    wire active_length; // 可发声
    
    apu_length_ctr #(
        .WIDTH (8)
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
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // 生成波形
    
    // 播放时基
    reg  clk_2m = 1'd1;
    always @(posedge clk) begin
        if (rst || !apu_enable)
            clk_2m <= 1'd1;
        else
            clk_2m <= ~clk_2m; // 4194304Hz / 2 = 2097152Hz
    end
    
    // 波形选择
    // 最终频率公式 f = 2097152 / (2048 - X) Hz
    wire [10:0] period = {period_h, period_l};
    reg  [10:0] cnt_waveGen;
    
    always @(posedge clk) begin
        if (rst) begin
            cnt_waveGen <= 11'd0;
            sampIndex   <= 5'd0;
        end
        else if (trigger) begin
            cnt_waveGen <= period;
            sampIndex   <= 5'd0;
        end
        else begin
            if (clk_2m) begin
                if (cnt_waveGen != 11'd2047) begin
                    cnt_waveGen <= cnt_waveGen + 11'd1;
                end
                else begin
                    cnt_waveGen <= period;
                    sampIndex   <= sampIndex + 5'd1;
                end
            end
        end
    end
    
    // 音量
    //                                         后低4位              先高4位
    wire [3:0] waveform = (sampIndex[0]) ? waveRam_dout[3:0] : waveRam_dout[7:4];
    reg  [3:0] level_out;
    
    always @(*) begin
        case(wave_volume)
            2'b00: level_out = 4'd0;
            2'b01: level_out = waveform;
            2'b10: level_out = {1'd0, waveform[3:1]};
            2'b11: level_out = {2'd0, waveform[3:2]};
        endcase
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_nr30    = {dacOn, 7'b1111111};
    assign reg_nr31    = 8'hff;
    assign reg_nr32    = {1'b1, wave_volume, 5'b11111};
    assign reg_nr33    = 8'hff;
    assign reg_nr34    = {1'b1, lenEn, 6'b111111};
    assign reg_waveRam = waveRam_dout;
    assign active      = active_length;
    assign level       = (active) ? level_out : 4'd0;
    
    
endmodule
