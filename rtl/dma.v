`timescale 1ns / 1ps

module dma(
    input clk,
    input rst,
    // cpu对dma的控制
    input [1:0] cpu_ct,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_dma,
    // 对总线的控制
    output reg [15:0] dma_src_a,
    input [7:0] dma_src_din,
    output reg dma_src_rd,
    output reg [15:0] dma_dst_a,
    output reg [7:0] dma_dst_dout,
    output reg dma_dst_wr,
    output reg dma_occupy
);
    
    
    // ## $FF46    DMA    OAM DMA source address & start    R/W    All
    //
    // - OAM DMA的源地址，只要写入就开始传输，搬到OAM(fe00~fe9f)
    // - 写入的值乘以 $100 就是源地址，比如写入XX($00~$df)，则将会搬运 $xx00~$xx9f 共160个字节
    // - 耗时160个MCycle
    // - 搬运时暴力抢夺总线，直到搬完，但CPU不停止运行，PPU和CPU都不能访问OAM
    // - DMG 卡带、WRAM、VRAM共用总线，CPU只能访问HRAM
    // - CGB 卡带总线和内部总线独立，在 WRAM->OAM 时，CPU可以访问卡带rom和ram; 在 cart->oam 时，CPU可以访问wram;
    reg [7:0] baseAddr_src;
    reg       flag_wrReg;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            flag_wrReg   <= 1'd0;
            baseAddr_src <= 8'd0;
        end
        else begin

            if ((cpu_wr) && (cpu_a == 16'hff46)) begin
                flag_wrReg <= 1'd1;
                baseAddr_src <= (cpu_dout >= 8'he0) ? (cpu_dout & 8'hdf) : cpu_dout;
            end
            else begin
                if (flag_wrReg) begin
                    flag_wrReg <= 1'd0;
                end
            end
            
        end
    end
    
    
    
    reg [7:0] trans_count = 8'd0;
    reg [1:0] dma_state   = 2'd0;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            dma_state    <= 2'd0;
            trans_count  <= 8'd0;
            dma_src_a    <= 16'd0;
            dma_src_rd   <= 1'd0;
            dma_dst_a    <= 16'd0;
            dma_dst_dout <= 8'd0;
            dma_dst_wr   <= 1'd0;
            dma_occupy   <= 1'd0;
        end
        else begin
            
            if (flag_wrReg) begin
                dma_state <= 2'd1;
            end
            else begin
                case (dma_state)
                    // 空闲
                    2'd0: begin
                        dma_occupy <= 1'd0;
                        dma_src_rd <= 1'd0;
                        dma_dst_wr <= 1'd0;
                    end
                    // 对齐 m-cycle
                    2'd1: begin
                        trans_count <= 8'd0;
                        dma_src_rd  <= 1'd0;
                        dma_dst_wr  <= 1'd0;
                        if (cpu_ct == 2'd3) begin
                            dma_state <= 2'd2;
                        end
                    end
                    // 开始搬数据
                    2'd2:begin
                        case (cpu_ct)
                            2'd0: begin
                                dma_dst_wr  <= 1'd0;
                                trans_count <= trans_count +8'd1;
                                if (trans_count < 8'd160) begin
                                    dma_occupy <= 1'd1;
                                    dma_src_a  <= {baseAddr_src, trans_count};
                                    dma_dst_a  <= {8'hfe,        trans_count};
                                    dma_src_rd <= 1'd1;
                                end
                                else begin
                                    dma_state  <= 2'd0;
                                    dma_occupy <= 1'd0;
                                    dma_src_rd <= 1'd0;
                                end
                            end
                            2'd1: begin
                            end
                            2'd2: begin
                                dma_dst_dout <= dma_src_din;
                                dma_src_rd   <= 1'd0;
                                dma_dst_wr   <= 1'd1;
                            end
                            2'd3: begin
                            end
                        endcase
                    end
                    default: begin
                        dma_state <= 2'd0;
                    end
                endcase
            end
        end
    end
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_dma = baseAddr_src;
    
endmodule

