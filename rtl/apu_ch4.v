`timescale 1ns / 1ps

module apu_ch4(
    input clk,
    input rst,
    input clk_256hz, // 音长用
    input clk_64hz,  // 包络用
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_nr41,
    output [7:0] reg_nr42,
    output [7:0] reg_nr43,
    output [7:0] reg_nr44,
    input apu_enable,
    output [3:0] level,
    output active
);
    
    // $FF20    NR41    Sound channel 4 length timer    W    All
    // |      | 7 6 | 5 4 3 2 1 0          |
    // | ---- | --- | -------------------- |
    // | NR41 |     | Initial length timer |
    // - bit 543210: (Write-only) 声音长度，同NR11
    reg [5:0] wave_length;
    reg       renewLength;
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            wave_length <= 6'd0;
            renewLength <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff20)) begin
                wave_length <= cpu_dout[5:0];
                renewLength <= 1'd1;
            end
            else begin
                if (renewLength) begin
                    renewLength <= 1'd0;
                end
            end
        end
    end
    
    // $FF21    NR42    Sound channel 4 volume & envelope    R/W    All
    // - 同 NR12
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
            if ((cpu_wr) && (cpu_a == 16'hff21)) begin
                initial_vol  <= cpu_dout[7:4];
                env_dir      <= cpu_dout[3];
                env_interval <= cpu_dout[2:0];
            end
        end
    end
    
    // $FF22    NR43    Sound channel 4 frequency & randomness    R/W    All
    // |      | 7 6 5 4     | 3          | 2 1 0         |
    // | ---- | ----------- | ---------- | ------------- |
    // | NR43 | Clock shift | LFSR width | Clock divider |
    // - bit 7654: 对基础频率262144进行 2^n 移位，越大越低音
    // - bit 3: 步数 0:15 1:7 内部有个16位伪随机数生成器初始值7fff，异或非门以bit 0 1为输入，
    //          LFSR=1 结果塞到bit15，LSFR=0 结果塞到bit7，然后整体右移
    // - bit 210: 时钟分频，0:divider=0.5, 其它值正常
    
    reg [4:0] clockShift;
    reg       lfsrWidth;
    reg [2:0] clockDiv;
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            clockShift <= 5'd0;
            lfsrWidth  <= 1'd0;
            clockDiv   <= 3'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff22)) begin
                clockShift <= {1'd0, cpu_dout[7:4]};
                lfsrWidth  <= cpu_dout[3];
                clockDiv   <= cpu_dout[2:0];
            end
        end
    end
    
    // $FF23    NR44    Sound channel 4 control    Mixed    All
    // |      | 7       | 6             | 5 4 3 2 1 0 |
    // | ---- | ------- | ------------- | ----------- |
    // | NR44 | Trigger | Length enable |             |
    // - bit 7: (Write-only) 开启或重启通道，应用上面寄存器的参数
    // - bit 6: 0：无限输出 1：由NR41决定输出时长
    reg trigger;
    reg lenEn;
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            trigger <= 1'd0;
            lenEn   <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff23)) begin
                trigger <= cpu_dout[7];
                lenEn   <= cpu_dout[6];
            end
            else begin
                if (trigger) begin
                    trigger <= 1'b0;
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
    // Frequency = 262144 Hz / (2^(shift) * divider)
    // clk 4194304
    // cnt_clk[0]  = 2097152
    // cnt_clk[1]  = 1048576
    // cnt_clk[2]  = 524288 <<< shift=0 and divider=0
    // cnt_clk[3]  = 262144 <<< shift=0 and divider>0
    // cnt_clk[4]  = 131072
    // cnt_clk[5]  = 65536
    // cnt_clk[6]  = 32768
    // cnt_clk[7]  = 16384
    // cnt_clk[8]  = 8192
    // cnt_clk[9]  = 4096
    // cnt_clk[10] = 2048
    // cnt_clk[11] = 1024
    // cnt_clk[12] = 512
    // cnt_clk[13] = 256
    // cnt_clk[14] = 128
    // cnt_clk[15] = 64
    // cnt_clk[16] = 32
    // cnt_clk[17] = 16
    // cnt_clk[18] = 8      <<< shift=15
    
    reg [18:0] cnt_clk;
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            cnt_clk <= 19'd0;
        end
        else begin
            cnt_clk <= cnt_clk + 19'd1;
        end
    end
    
    wire      clk_lfsr_prescalex4 = cnt_clk[5'd1 + clockShift]; // 4倍主时钟移位预分频后时基
    reg       clk_lfsr;                                         // 再分频后lfsr移位时基
    
    reg [3:0] cnt_lfsr;
    always @(posedge clk_lfsr_prescalex4) begin
        if (rst || !apu_enable) begin
            clk_lfsr <= 1'd0;
            cnt_lfsr <= 4'd0;
        end
        else begin
            if (clockDiv == 3'd0) begin
                // divider=0.5
                // 此处自带2分频，但功能是倍频，所以输入时钟要4倍时基
                clk_lfsr <= ~clk_lfsr;
            end
            else begin
                // 因为是4倍时基，所以计数值翻倍
                if (cnt_lfsr < ({clockDiv,1'b0}-4'd1)) begin
                    cnt_lfsr <= cnt_lfsr+4'd1;
                end
                else begin
                    cnt_lfsr <= 4'd0;
                    clk_lfsr <= ~clk_lfsr;
                end
                
            end
        end
    end
    
    wire pluse_clk_lfsr;
    
    edgedet u_ed1 (
        .clk (clk),
        .i   (clk_lfsr),
        .o   (pluse_clk_lfsr)
    );
    
    // 电平选择
    reg [14:0] lfsr;
    wire       lfsr_xnor  = (lfsr[1] == lfsr[0]);
    wire       wave_level = lfsr[0];
    
    always @(posedge clk) begin
        if ((rst) || (!apu_enable)) begin
            lfsr <= 15'd0;
        end
        else begin
            if (trigger) begin
                lfsr <= 15'd0;
            end
            else begin
                if (pluse_clk_lfsr) begin
                    if (lfsrWidth) begin
                        lfsr <= {lfsr_xnor, lfsr[14:8], lfsr_xnor, lfsr[6:1]};
                    end
                    else begin
                        lfsr <= {lfsr_xnor, lfsr[14:1]};
                    end
                end
            end
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_nr41 = 8'hff;
    assign reg_nr42 = {initial_vol, env_dir, env_interval};
    assign reg_nr43 = {clockShift[3:0], lfsrWidth, clockDiv};
    assign reg_nr44 = {1'b1, lenEn, 6'b111111};
    
    assign active = active_length;
    assign level  = (active & wave_level) ? env_volume : 4'd0;
    
    
endmodule
