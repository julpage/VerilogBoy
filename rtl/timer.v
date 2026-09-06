`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Wenting Zhang
//
// Create Date:    17:12:01 04/13/2018
// Module Name:    timer
// Project Name:   VerilogBoy
// Description:
//   GameBoy internal timer
// Dependencies:
//
// Additional Comments:
//   This should probably run at 1MHz domain, but currently at 4MHz.
//////////////////////////////////////////////////////////////////////////////////
module timer(
    input clk,
    input rst,
    input cpu_stop,
    input [1:0] cpu_ct,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_div,
    output [7:0] reg_tima,
    output [7:0] reg_tma,
    output [7:0] reg_tac,
    output reg intReq,
    input intAck
);
    
    reg       tim_en;
    reg [1:0] clk_sel;
    
    reg  [15:0] sys; // clk counter
    wire        clk_256khz = sys[3];
    wire        clk_64khz  = sys[5];
    wire        clk_16khz  = sys[7];
    wire        clk_4khz   = sys[9];
    
    reg clk_tim;
    always @(*) begin
        case (clk_sel)
            2'd0: clk_tim = tim_en & clk_4khz;
            2'd1: clk_tim = tim_en & clk_256khz;
            2'd2: clk_tim = tim_en & clk_64khz;
            2'd3: clk_tim = tim_en & clk_16khz;
        endcase
    end
    
    reg last_clk_tim;
    always @(posedge clk) begin
        last_clk_tim <= clk_tim;
    end
    
    wire clk_tim_neg = (last_clk_tim && !clk_tim);
    
    
    
    // $FF04    DIV    Divider register    R/W    All
    // - 永远运行的计数器，以 16,384Hz 向上计数，CGB双倍速下为 32,768Hz，即是 MCycle/64
    // - 写入任何值会重置
    // - 执行 STOP 会重置，退出 STOP 才重新运行
    always @(posedge rst or posedge clk) begin
        if (rst | cpu_stop) begin
            sys <= 16'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff04)) begin
                sys <= 16'd4; // 补偿
            end
            else begin
                sys <= sys + 16'd1;
            end
        end
    end
    
    
    
    // $FF07    TAC    Timer control       R/W    All
    // |     | 7   | 6   | 5   | 4   | 3   | 2      | 1   0        |
    // | --- | --- | --- | --- | --- | --- | ------ | ------------ |
    // | TAC |     |     |     |     |     | Enable | Clock select |
    //
    // | Clock select | Increment    | normal-speed mode | double-speed mode |
    // | ------------ | ------------ | ----------------- | ----------------- |
    // | 00           | 256 M-cycles | 4,096   Hz        | 8,192   Hz        |
    // | 01           | 4 M-cycles   | 262,144 Hz        | 524,288 Hz        |
    // | 10           | 16 M-cycles  | 65,536  Hz        | 131,072 Hz        |
    // | 11           | 64 M-cycles  | 16,384  Hz        | 32,768  Hz        |
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            tim_en  <= 1'd0;
            clk_sel <= 2'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff07)) begin
                tim_en  <= cpu_dout[2];
                clk_sel <= cpu_dout[1:0];
            end
        end
    end
    
    
    
    // $FF06    TMA    Timer reload        R/W    All
    reg [7:0] tim_reload; // Timer modulo
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            tim_reload <= 8'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff06)) begin
                tim_reload <= cpu_dout;
            end
        end
    end
    
    
    
    // $FF05    TIMA   Timer counter       R/W    All
    // - 定时器A 计数值，以 TAC 设定的频率向上计数
    // - 数值溢出(FF->00) 时，重置为TMA（$FF06）中指定的值，并请求中断
    
    // | M-cycle |     |     |     | A   | B   |     |     |
    // | ------- | --- | --- | --- | --- | --- | --- | --- |
    // | SYS     | 2B  | 2C  | 2D  | 2E  | 2F  | 30  | 31  |
    // | TIMA    | FE  | FF  | FF  | 00  | 23  | 23  | 23  |
    // | TMA     | 23  | 23  | 23  | 23  | 23  | 23  | 23  |
    // | IF      | E0  | E0  | E0  | E0  | E4  | E4  | E4  |
    // Here are some unexpected behaviors:
    // 1. Writing to TIMA during cycle A acts as if the overflow didn’t happen!
    //    TMA will not be copied to TIMA (the value written will therefore stay),
    //    and bit 2 of IF will not be set. Writing to DIV, TAC, or other registers
    //    won’t prevent the IF flag from being set or TIMA from being reloaded.
    // 2. Writing to TIMA during cycle B will be ignored; TIMA will be equal to
    //    TMA at the end of the cycle anyway.
    // 3. Writing to TMA during cycle B will have the same value copied to TIMA as well,
    //    on the same cycle.
    
    reg [7:0] tim_cnt;    // Timer counter
    reg       overflowed; // cycle A
    reg       reloading;  // cycle B
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            tim_cnt    <= 8'd0;
            overflowed <= 1'd0;
            reloading  <= 1'd0;
        end
        else begin
            
            if (reloading) begin
                // cycle B
                tim_cnt <= reg_tma;
                if ((cpu_ct == 2'd0)) begin
                    reloading <= 1'd0;
                end
            end
            else begin
                
                if ((cpu_wr) && (cpu_a == 16'hff05)) begin
                    // Writing to TIMA during cycle A acts as if the overflow didn’t happen
                    tim_cnt    <= cpu_dout;
                    overflowed <= 1'd0;
                end
                else begin
                    
                    if (clk_tim_neg) begin
                        
                        tim_cnt <= tim_cnt + 1'b1;
                        
                        // to cycle A
                        if (tim_cnt == 8'hff) begin
                            overflowed <= 1'd1;
                        end
                        
                    end
                    
                    // cycle A -> B
                    // TIMA is equal to $00 for the M-cycle after it overflows.
                    // Writing to TIMA during cycle A acts as if the overflow didn’t happen!
                    if (overflowed && (cpu_ct == 2'd0)) begin
                        overflowed <= 1'd0;
                        reloading  <= 1'd1;
                    end
                    
                end
            end
        end
    end
    
    
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            intReq <= 0;
        end
        else begin
            
            if (overflowed) begin
                intReq <= 1'b1;
            end
            else begin
                if (intReq && intAck) begin
                    intReq <= 1'b0;
                end
            end
            
        end
    end
    
    
    
    ///////////////////////////////////////////////////////////////////////
    assign reg_div  = sys[15:8];
    assign reg_tac  = {5'b11111, tim_en, clk_sel};
    assign reg_tima = tim_cnt;
    assign reg_tma  = tim_reload;
    
endmodule
