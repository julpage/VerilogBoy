`timescale 1ns / 1ps

module joypad(
    input clk,
    input rst,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_joyp,
    output reg intReq,
    input intAck,
    input [7:0] keys // down up left right st sel b a
);
    


    // ## $FF00    P1/JOYP    Joypad    Mixed    All
    // |     | 7   | 6   | 5              | 4            | 3            | 2           | 1        | 0         |
    // | --- | --- | --- | -------------- | ------------ | ------------ | ----------- | -------- | --------- |
    // | P1  |     |     | Select buttons | Select d-pad | Start / Down | Select / Up | B / Left | A / Right |
    // - bit5 = 0, 读Start Select B A
    // - bit4 = 0, 读Down Up Left Right
    // - 低4位只读，按下是0
    
    reg [1:0] btnSel;
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            btnSel <= 2'b11;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff00)) begin
                btnSel <= cpu_dout[5:4];
            end
        end
    end
    
    reg [3:0] keypad;
    always @(*) begin
        case (btnSel)
            2'b00: keypad = keys[7:4] & keys[3:0];
            2'b01: keypad = keys[3:0]; // st sl b a
            2'b10: keypad = keys[7:4]; // Down Up Left Right
            2'b11: keypad = 4'b1111;
        endcase
    end
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            intReq <= 1'b0;
        end
        else begin
            
            if (!intReq) begin
                intReq <= (keypad != 4'b1111);
            end
            
            if (intAck && intReq) begin
                intReq <= 1'd0;
            end
            
        end
    end
    
    assign reg_joyp = {2'b11, btnSel, keypad};
    
endmodule
