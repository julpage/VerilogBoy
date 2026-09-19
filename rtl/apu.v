`timescale 1ns / 1ps

module apu(
    input clk,
    input rst,
    input doubleSpeedMode,
    input [1:0] cpu_ct,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    input [7:0] reg_div,
    output [7:0] reg_nr10,
    output [7:0] reg_nr11,
    output [7:0] reg_nr12,
    output [7:0] reg_nr13,
    output [7:0] reg_nr14,
    output [7:0] reg_nr21,
    output [7:0] reg_nr22,
    output [7:0] reg_nr23,
    output [7:0] reg_nr24,
    output [7:0] reg_nr30,
    output [7:0] reg_nr31,
    output [7:0] reg_nr32,
    output [7:0] reg_nr33,
    output [7:0] reg_nr34,
    output [7:0] reg_nr41,
    output [7:0] reg_nr42,
    output [7:0] reg_nr43,
    output [7:0] reg_nr44,
    output [7:0] reg_nr50,
    output [7:0] reg_nr51,
    output [7:0] reg_nr52,
    output [7:0] reg_pcm12,
    output [7:0] reg_pcm34,
    output [7:0] reg_waveRam,
    input signed [3:0] cart_vin,
    output signed [15:0] left,
    output signed [15:0] right
);
    
    // ## $FF26    NR52    Sound on/off    Mixed    All
    // |      | 7            | 6 5 4 | 3       | 2       | 1       | 0       |
    // | ---- | ------------ | ----- | ------- | ------- | ------- | ------- |
    // | NR52 | Audio on/off |       | CH4 on? | CH3 on? | CH2 on? | CH1 on? |
    //
    // - bit 7: (Read/Write) 音频总开关，会清空所有APU寄存器，并进入只读状态
    // - bit 3210: (Read only)各通道的激活状态，不代表dac状态
    reg apu_enable;
    
    always @(posedge clk) begin
        if (rst) begin
            apu_enable <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff26)) begin
                apu_enable <= cpu_dout[7];
            end
        end
    end
    
    // $FF25    NR51    Sound panning    R/W    All
    // |      | 7     | 6     | 5     | 4     | 3     | 2     | 1     | 0     |
    // | ---- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
    // | NR51 | CH4 L | CH3 L | CH2 L | CH1 L | CH4 R | CH3 R | CH2 R | CH1 R |
    //
    // - 通道路由，控制通道生成的音频去往左还是右，上电所有通道默认都是0
    reg mixIn_l_ch1, mixIn_l_ch2, mixIn_l_ch3, mixIn_l_ch4;
    reg mixIn_r_ch1, mixIn_r_ch2, mixIn_r_ch3, mixIn_r_ch4;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            {mixIn_l_ch1, mixIn_l_ch2, mixIn_l_ch3, mixIn_l_ch4} <= 4'd0;
            {mixIn_r_ch1, mixIn_r_ch2, mixIn_r_ch3, mixIn_r_ch4} <= 4'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff25)) begin
                {mixIn_l_ch4, mixIn_l_ch3, mixIn_l_ch2, mixIn_l_ch1} <= cpu_dout[7:4];
                {mixIn_r_ch4, mixIn_r_ch3, mixIn_r_ch2, mixIn_r_ch1} <= cpu_dout[3:0];
            end
        end
    end
    
    // $FF24    NR50    Master volume & VIN panning    R/W    All
    // |      | 7        | 6 5 4       | 3         | 2 1 0        |
    // | ---- | -------- | ----------- | --------- | ------------ |
    // | NR50 | VIN left | Left volume | VIN right | Right volume |
    //
    // - bit 7 6: 只是路由，不控制音量
    // - bit 654 210: 左右声道的总音量，写0视为1，写7视为8（最大声），永不静音
    reg       mixIn_l_vin, mixIn_r_vin;
    reg [2:0] vol_left;
    reg [2:0] vol_right;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            mixIn_l_vin <= 1'd0;
            mixIn_r_vin <= 1'd0;
            vol_left    <= 3'd0;
            vol_right   <= 3'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff24)) begin
                vol_left    <= cpu_dout[6:4];
                vol_right   <= cpu_dout[2:0];
                mixIn_l_vin <= cpu_dout[7];
                mixIn_r_vin <= cpu_dout[3];
            end
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // apu时基
    
    reg [12:0] clk_cnt;
    wire       pluse_512hz = (clk_cnt == 13'd8191);
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            clk_cnt <= 13'd0;
        end
        else begin
            // 4194304/8192=512
            if (pluse_512hz) begin
                clk_cnt <= 13'd0;
            end
            else begin
                clk_cnt <= clk_cnt + 13'd1;
            end
        end
    end
    
    
    // apu_state     0       1       2       3       4       5       6       7      *0*
    //               +-------+       +-------+       +-------+       +-------+       +
    // clk_256hz     |       |       |       |       |       |       |       |       |
    //         ------+       +-------+       +-------+       +-------+       +-------+
    //                               +---------------+               +---------------+
    // clk_128hz                     |               |               |               |
    //         ----------------------+               +---------------+               +
    //                                               +-------------------------------+
    // clk_64hz                                      |                               |
    //         --------------------------------------+                               +
    
    reg [2:0] apu_state;
    reg clk_256hz;
    reg clk_128hz;
    reg clk_64hz;
    
    always @(posedge clk) begin
        if (rst || !apu_enable) begin
            apu_state <= 3'd0;
            clk_256hz <= 1'd0;
            clk_128hz <= 1'd0;
            clk_64hz  <= 1'd0;
        end
        else begin
            if (pluse_512hz) begin
                
                apu_state <= apu_state + 3'd1;
                
                // 07-len sweep period sync.s test 2,"Length period is wrong"
                // 07-len sweep period sync.s test 4,"Sweep clock is synchronized with length"
                // 07-len sweep period sync.s test 5,"Powering up APU MODs next frame time with 8192"
                if (apu_state[0] == 1'd0) clk_256hz <= 1'd1;
                else                      clk_256hz <= 1'd0;
                
                // 07-len sweep period sync.s test 3,"Sweep period is wrong"
                // 07-len sweep period sync.s test 6,"Powering up APU resets 128 Hz sweep divider"
                if (apu_state[1:0] == 2'd2)       clk_128hz <= 1'd1;
                else if (apu_state[1:0] == 2'd0)  clk_128hz <= 1'd0;
                else                              clk_128hz <= clk_128hz;
                
                if (apu_state == 3'd4)      clk_64hz <= 1'd1;
                else if (apu_state == 3'd0) clk_64hz <= 1'd0;
                else                        clk_64hz <= clk_64hz;
                
            end
        end
    end
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    wire ch1_acitve;
    wire ch2_acitve;
    wire ch3_acitve;
    wire ch4_acitve;
    
    wire [3:0] level_ch1;
    wire [3:0] level_ch2;
    wire [3:0] level_ch3;
    wire [3:0] level_ch4;
    
    apu_ch12 #(
        .FEATURE_SWEEP (1), // 有扫频
        .MMIO_BASE_ADDR (16'hff10)
    ) u_channel1 (
        .clk        (clk),
        .rst        (rst),
        .clk_256hz  (clk_256hz),
        .clk_128hz  (clk_128hz),
        .clk_64hz   (clk_64hz),
        .cpu_a      (cpu_a),
        .cpu_dout   (cpu_dout),
        .cpu_rd     (cpu_rd),
        .cpu_wr     (cpu_wr),
        .reg_nrx0   (reg_nr10),
        .reg_nrx1   (reg_nr11),
        .reg_nrx2   (reg_nr12),
        .reg_nrx3   (reg_nr13),
        .reg_nrx4   (reg_nr14),
        .apu_enable (apu_enable),
        .level      (level_ch1),
        .active     (ch1_acitve)
    );
    
    apu_ch12 #(
        .FEATURE_SWEEP (0), // 无扫频
        .MMIO_BASE_ADDR (16'hff15)
    ) u_channel2 (
        .clk        (clk),
        .rst        (rst),
        .clk_256hz  (clk_256hz),
        .clk_128hz  (clk_128hz),
        .clk_64hz   (clk_64hz),
        .cpu_a      (cpu_a),
        .cpu_dout   (cpu_dout),
        .cpu_rd     (cpu_rd),
        .cpu_wr     (cpu_wr),
        .reg_nrx0   (),
        .reg_nrx1   (reg_nr21),
        .reg_nrx2   (reg_nr22),
        .reg_nrx3   (reg_nr23),
        .reg_nrx4   (reg_nr24),
        .apu_enable (apu_enable),
        .level      (level_ch2),
        .active     (ch2_acitve)
    );
    
    apu_ch3 u_channel3(
        .clk         (clk),
        .rst         (rst),
        .clk_256hz   (clk_256hz),
        .cpu_ct      (cpu_ct),
        .cpu_a       (cpu_a),
        .cpu_dout    (cpu_dout),
        .cpu_rd      (cpu_rd),
        .cpu_wr      (cpu_wr),
        .reg_nr30    (reg_nr30),
        .reg_nr31    (reg_nr31),
        .reg_nr32    (reg_nr32),
        .reg_nr33    (reg_nr33),
        .reg_nr34    (reg_nr34),
        .reg_waveRam (reg_waveRam),
        .apu_enable  (apu_enable),
        .level       (level_ch3),
        .active      (ch3_acitve)
    );
    
    apu_ch4 u_channel4(
        .clk        (clk),
        .rst        (rst),
        .clk_256hz  (clk_256hz),
        .clk_64hz   (clk_64hz),
        .cpu_a      (cpu_a),
        .cpu_dout   (cpu_dout),
        .cpu_rd     (cpu_rd),
        .cpu_wr     (cpu_wr),
        .reg_nr41   (reg_nr41),
        .reg_nr42   (reg_nr42),
        .reg_nr43   (reg_nr43),
        .reg_nr44   (reg_nr44),
        .apu_enable (apu_enable),
        .level      (level_ch4),
        .active     (ch4_acitve)
    );
    
    // 混音
    apu_mixer u_mixer(
        .clk          (clk),
        .rst          (rst || !apu_enable),
        .ch1_level    (level_ch1),
        .ch2_level    (level_ch2),
        .ch3_level    (level_ch3),
        .ch4_level    (level_ch4),
        .vin_voltage  (cart_vin),
        .mixIn_l_ch1  (mixIn_l_ch1),
        .mixIn_l_ch2  (mixIn_l_ch2),
        .mixIn_l_ch3  (mixIn_l_ch3),
        .mixIn_l_ch4  (mixIn_l_ch4),
        .mixIn_l_vin  (mixIn_l_vin),
        .mixIn_r_ch1  (mixIn_r_ch1),
        .mixIn_r_ch2  (mixIn_r_ch2),
        .mixIn_r_ch3  (mixIn_r_ch3),
        .mixIn_r_ch4  (mixIn_r_ch4),
        .mixIn_r_vin  (mixIn_r_vin),
        .volume_left  (vol_left),
        .volume_right (vol_right),
        .left_out     (left),
        .right_out    (right)
    );
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_nr50  = {mixIn_l_vin, vol_left, mixIn_r_vin, vol_right};
    assign reg_nr51  = {mixIn_l_ch4, mixIn_l_ch3, mixIn_l_ch2, mixIn_l_ch1, mixIn_r_ch4, mixIn_r_ch3, mixIn_r_ch2, mixIn_r_ch1};
    assign reg_nr52  = {apu_enable, 3'b111, ch4_acitve, ch3_acitve, ch2_acitve, ch1_acitve};
    assign reg_pcm12 = {level_ch2, level_ch1};
    assign reg_pcm34 = {level_ch4, level_ch3};
    
    
endmodule
