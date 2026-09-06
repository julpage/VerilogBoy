`timescale 1ns / 1ps

module interrupt(
    input clk,
    input rst,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_if,
    output [7:0] reg_ie,
    output [4:0] cpu_int_en,
    output [4:0] cpu_int_flag,
    input [4:0] cpu_int_flag_out,
    input req_vBlank,
    input req_stat,
    input req_timer,
    input req_serial,
    input req_joypad,
    output ack_vBlank,
    output ack_stat,
    output ack_timer,
    output ack_serial,
    output ack_joypad
);
    
    
    
    // ## $FFFF    IE    Interrupt enable    R/W    All
    //
    // |     | 7 6 5 | 4      | 3      | 2     | 1   | 0      |
    // | --- | ----- | ------ | ------ | ----- | --- | ------ |
    // | IE  |       | Joypad | Serial | Timer | LCD | VBlank |
    //
    // - 中断使能
    // - 0位(VBlank)优先级最高，4位(Joypad)优先级最低
    // - 在 DMG 模式中，Mode 2（OAM 搜索模式）的 STAT 中断在模式切换前约 1-3 个 T-cycle 就已经触发，而不是在模式切换的时刻触发
    
    reg [7:0] ie;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            ie <= 8'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hffff)) begin
                ie <= cpu_dout; // 根据unused_hwio-GS.s所记载，未使用位是可读写的
            end
        end
    end
    
    
    
    // ## $FF0F    IF    Interrupt flag    R/W    All
    //
    // |     | 7 6 5 | 4      | 3      | 2     | 1   | 0      |
    // | --- | ----- | ------ | ------ | ----- | --- | ------ |
    // | IF  |       | Joypad | Serial | Timer | LCD | VBlank |
    //
    // - 中断标志，对应事件发生会置 1
    // - CPU处理中断后会自动清 0
    // - 可以手动清 0，也可以手动写 1 去触发中断
    
    reg  [4:0] int_flags;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            int_flags <= 5'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff0f)) begin
                int_flags <= cpu_dout[4:0];
            end
            else begin
                int_flags <= cpu_int_flag_out;
            end
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    assign reg_if = {3'b111, int_flags};
    assign reg_ie = ie;

    wire [4:0] int_reqs = {req_joypad, req_serial, req_timer, req_stat, req_vBlank};
    
    assign cpu_int_en   = ie[4:0];
    assign cpu_int_flag = int_flags | int_reqs;
    
    assign ack_vBlank = int_reqs[0];
    assign ack_stat   = int_reqs[1];
    assign ack_timer  = int_reqs[2];
    assign ack_serial = int_reqs[3];
    assign ack_joypad = int_reqs[4];
    
endmodule
