`timescale 1ns / 1ps

module apu_mixer(
    input clk,
    input rst,
    // 五个通道的数字电平 (0-15)
    input [3:0] ch1_level,
    input [3:0] ch2_level,
    input [3:0] ch3_level,
    input [3:0] ch4_level,
    input signed [3:0] vin_voltage,
    // 左声道混音使能
    input mixIn_l_ch1,
    input mixIn_l_ch2,
    input mixIn_l_ch3,
    input mixIn_l_ch4,
    input mixIn_l_vin,
    // 右声道混音使能
    input mixIn_r_ch1,
    input mixIn_r_ch2,
    input mixIn_r_ch3,
    input mixIn_r_ch4,
    input mixIn_r_vin,
    // 主音量 (0-7, 0对应音量1, 7对应音量8)
    input [2:0] volume_left,
    input [2:0] volume_right,
    output reg signed [15:0] left_out,
    output reg signed [15:0] right_out
);
    
    // 内部通道输出数字值0～f,转为模拟值-1～1
    // CH1 DAC ─┐
    // CH2 DAC ─┤ → NR51 路由(L/R) → NR50 主音量(L/R) → 耳机
    // CH3 DAC ─┤
    // CH4 DAC ─┤
    // VIN ─────┘
    
    
    // ------------------------------------------------------------
    // 1. DAC 转换：4-bit → 有符号小整数（-8 ~ +7）
    //    映射：0 → -8, 8 → 0, 15 → +7
    // ------------------------------------------------------------
    function signed [3:0] dac_convert;
        input [3:0] level;
        begin
            dac_convert = level - 8;
        end
    endfunction
    
    // ------------------------------------------------------------
    // 2. 各通道电压（未激活由外部控制，此处仅做转换）
    // ------------------------------------------------------------
    wire signed [3:0] ch1_voltage = dac_convert(ch1_level);
    wire signed [3:0] ch2_voltage = dac_convert(ch2_level);
    wire signed [3:0] ch3_voltage = dac_convert(ch3_level);
    wire signed [3:0] ch4_voltage = dac_convert(ch4_level);
    
    // ------------------------------------------------------------
    // 3. 左右声道混音总和（位宽扩展防止溢出）
    //    5个通道（4内部 + VIN），各 ±8，总和范围 -40 ~ +40
    //    需要 7 位有符号数（-64 ~ +63 足够）
    // ------------------------------------------------------------
    wire signed [6:0] left_sum = 
    (mixIn_l_ch1 ? ch1_voltage : 7'sd0) +
    (mixIn_l_ch2 ? ch2_voltage : 7'sd0) +
    (mixIn_l_ch3 ? ch3_voltage : 7'sd0) +
    (mixIn_l_ch4 ? ch4_voltage : 7'sd0) +
    (mixIn_l_vin ? vin_voltage : 7'sd0);
    
    wire signed [6:0] right_sum = 
    (mixIn_r_ch1 ? ch1_voltage : 7'sd0) +
    (mixIn_r_ch2 ? ch2_voltage : 7'sd0) +
    (mixIn_r_ch3 ? ch3_voltage : 7'sd0) +
    (mixIn_r_ch4 ? ch4_voltage : 7'sd0) +
    (mixIn_r_vin ? vin_voltage : 7'sd0);
    
    // ------------------------------------------------------------
    // 4. 主音量控制（右移实现衰减）
    //    volume 值 0-7 → 实际音量 1-8
    //    右移位数 = 7 - volume，音量越大右移越少
    //    例如 volume=7 → shift=0（最大音量）
    //        volume=0 → shift=7（最小音量，1/128）
    // ------------------------------------------------------------
    wire signed [6:0] left_mix  = left_sum  >>> (7 - volume_left);
    wire signed [6:0] right_mix = right_sum >>> (7 - volume_right);
    
    // ------------------------------------------------------------
    // 5. 输出寄存器
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            left_out  <= 16'sd0;
            right_out <= 16'sd0;
        end else begin
            left_out  <= {left_mix, 9'b0};
            right_out <= {right_mix, 9'b0};
        end
    end
    
endmodule
