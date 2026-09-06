`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Wenting Zhang
//
// Create Date:    13:13:04 04/13/2018
// Module Name:    serial
// Project Name:   VerilogBoy
// Description:
//   Dummy serial interface
// Dependencies:
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module serial(
    input clk,
    input rst,
    input dmg_mode,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_sc,
    output [7:0] reg_sb,
    output reg intReq,
    input intAck,
    output sio_sc_oe,
    inout sio_sc,
    output sio_so,
    input sio_si
);
    
    reg [3:0] bit_cnt = 4'd0;
    
    
    // ## $FF02    SC    Serial transfer control    R/W    Mixed
    //
    // |     | 7               | 6   | 5   | 4   | 3   | 2   | 1           | 0            |
    // | --- | --------------- | --- | --- | --- | --- | --- | ----------- | ------------ |
    // | SC  | Transfer enable |     |     |     |     |     | Clock speed | Clock select |
    //
    // - bit 7 (Read/Write):                 写1开始传输，结束自动清0
    // - bit 1 [CGB Mode only] (Read/Write): 0:低速(8192Hz=1KB/s) 1:高速(262144Hz=32KB/s)
    // - bit 0 (Read/Write):                 0:从机 1:主机
    //
    // 对于CGB，速度与双倍速有关
    // | Clock freq | Transfer speed | Conditions                  |
    // | ---------- | -------------- | --------------------------- |
    // | 8192 Hz    | 1 KB/s         | Bit 1 cleared  Normal       |
    // | 16384 Hz   | 2 KB/s         | Bit 1 cleared  Double-speed |
    // | 262144 Hz  | 32 KB/s        | Bit 1 set      Normal       |
    // | 524288 Hz  | 64 KB/s        | Bit 1 set      Double-speed |
    reg       trans_en;
    reg       highSpeed;
    reg       master;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            trans_en  <= 1'd0;
            highSpeed <= 1'd0;
            master    <= 1'd0;
            intReq    <= 1'd0;
        end
        else begin
            
            if (cpu_wr && (cpu_a == 16'hff02)) begin
                trans_en  <= cpu_dout[7];
                highSpeed <= cpu_dout[1];
                master    <= cpu_dout[0];
            end
            else begin
                
                if ((trans_en) && (bit_cnt > 4'd7)) begin
                    trans_en <= 1'd0;
                    intReq   <= intAck ? 1'd0 : 1'd1;
                end
                
                if (intReq && intAck) begin
                    intReq <= 1'd0;
                end
                
            end
            
        end
    end
    
    
    
    // ## $FF01    SB    Serial transfer data    R/W    All
    //
    // - 联机口收发的数据，MSB，上升沿锁存，下降沿进出寄存器
    // - 传输前，它会保留下一个将要发出的字节。
    // - 传输过程中，它会混合出字节和入字节。 每个周期，最左边的比特被移出（并越过导线），并且 输入位从另一侧移入：
    reg [7:0] txByte;
    reg       load_shiftReg;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            txByte        <= 8'd0;
            load_shiftReg <= 1'd0;
        end
        else begin
            
            if (cpu_wr && (cpu_a == 16'hff01)) begin
                txByte        <= cpu_dout;
                load_shiftReg <= 1'd1;
            end
            else begin
                if (load_shiftReg) begin
                    load_shiftReg <= 1'd0;
                end
            end
            
        end
    end
    
    
    
    // clk gen
    reg [8:0] clk_cnt;
    wire clk_256k   = clk_cnt[3]; // 512k in Double-speed
    wire clk_8k     = clk_cnt[8]; // 16k in Double-speed
    wire sio_sc_out = ((!dmg_mode) && (highSpeed)) ? clk_256k : clk_8k;
    
    always @(posedge clk) begin
        if (!trans_en) begin
            clk_cnt <= 9'h1ff;
        end
        else begin
            clk_cnt <= clk_cnt + 9'd1;
        end
    end
    
    
    
    // 8-bit Shift Register
    
    always @(negedge trans_en or posedge sio_sc) begin
        if (!trans_en) begin
            bit_cnt <= 4'd0;
        end
        else begin
            bit_cnt <= bit_cnt +4'd1;
        end
    end
    
    reg [7:0] shiftReg;
    always @(posedge load_shiftReg or posedge sio_sc) begin
        if (load_shiftReg) begin
            shiftReg <= txByte;
        end
        else begin
            if (trans_en && (bit_cnt < 4'd8)) begin
                shiftReg <= {shiftReg[6:0], sio_si};
            end
        end
    end
    
    reg sio_so_out = 1'd0;
    always @(negedge sio_sc) begin
        sio_so_out <= shiftReg[7];
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_sc    = dmg_mode ? {trans_en, 6'b111111, master} : {trans_en , 5'b11111, highSpeed, master} ;
    assign reg_sb    = shiftReg;
    assign sio_sc_oe = trans_en & master;
    assign sio_sc    = sio_sc_oe ? sio_sc_out : 1'bz;
    assign sio_so    = sio_so_out;
    
    
    
endmodule
