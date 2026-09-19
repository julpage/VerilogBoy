`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Wenting Zhang
//
// Create Date:    22:21:41 04/08/2018
// Module Name:    sound_vol_env
// Project Name:   VerilogBoy
// Description:
//   Sound volume envelope control for channel 1 2 4
// Dependencies:
//   none
// Additional Comments:
//   音量包络
//////////////////////////////////////////////////////////////////////////////////

module apu_vol_env(
    input clk,
    input rst,
    input clk_64hz,             // 64Hz 包络时钟脉冲，每次为高时触发一次包络扫描判断
    input trigger,              // 声道启动信号，用于重新加载初始音量和扫描计数器
    input [3:0] initial_volume, // 初始音量值（0-15） 0静音，f最大声
    input dir,                  // 包络方向：0递减，1递增
    input [2:0] interval,       // 包络步长，每次音量变化前需要等待的扫描周期数 N*(1/64) 秒，0无包络
    output reg [3:0] volume     // 当前音量值
);
    
    wire pluse_64hz;
    edgedet u_ed3 (
        .clk (clk),
        .i   (clk_64hz),
        .o   (pluse_64hz)
    );
    
    reg [2:0] cnt; // Number of cycles before next sweep
    wire      enve_enabled = (interval != 3'd0);
    
    // Volume Envelope
    always @(posedge rst or posedge clk) begin
        
        if (rst) begin
            volume <= 4'd0;
        end
        else begin
            
            if (trigger) begin
                volume <= initial_volume;
                cnt    <= interval;
            end
            else begin
                
                if ((pluse_64hz) && (enve_enabled)) begin
                    
                    if (cnt > 3'd1) begin
                        cnt <= cnt - 1'b1;
                    end
                    else begin
                        cnt <= interval;
                        
                        if ((dir) && (volume != 4'd15)) begin
                            volume <= volume + 1;
                        end
                        else if ((!dir) && (volume != 4'd0)) begin
                            volume <= volume - 1;
                        end
                    end
                    
                end
                
            end
        end
    end
    
    
endmodule
