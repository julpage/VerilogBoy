`timescale 1ns / 1ps

`define BUS_OP_IDLE     2'b00
`define BUS_OP_IF       2'b01
`define BUS_OP_WRITE    2'b10
`define BUS_OP_READ     2'b11

module cartridge(
    input clk,
    input rst,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    input [1:0] cpu_ct,
    input [1:0] bus_op,
    input dma_occupy,
    // 卡带接口
    output [15:0] cart_a,
    inout [7:0] cart_d,
    output cart_d_oe,
    output cart_nCS,
    output reg cart_nWR,
    output reg cart_nRD
);
    
    
    wire   range_rom = ((16'h0000 <= cpu_a) && (cpu_a <= 16'h7fff));
    wire   range_ram = ((16'ha000 <= cpu_a) && (cpu_a <= 16'hfdff));
    
    
    
    // rd
    always @(*) begin
        if (dma_occupy) begin
            cart_nRD = 1'd0;
        end
        else begin
            if ((range_rom || range_ram) && (bus_op != `BUS_OP_WRITE)) begin
                cart_nRD = 1'd0;
            end
            else begin
                cart_nRD = 1'd1;
            end
        end
    end
    
    
    
    // wr dout
    reg [7:0] d_out;
    reg       d_oe;
    
    always @(posedge rst or negedge clk) begin
        if (rst) begin
            // cart_nRD   <= 1'd1;
            cart_nWR <= 1'd1;
            d_out    <= 8'd0;
            d_oe     <= 1'd0;
        end
        else begin
            
            if (dma_occupy) begin
                // cart_nRD  <= 1'd0;
                cart_nWR <= 1'd1;
                d_oe     <= 1'd0;
            end
            else begin
                
                case (cpu_ct)
                    2'd0: begin
                        cart_nWR <= 1'd1;
                    end
                    2'd1: begin
                        d_oe <= 1'd0;
                        if ((range_rom || range_ram) && (bus_op == `BUS_OP_WRITE)) begin
                            // cart_nRD <= 1'd1;
                        end
                        else begin
                            // cart_nRD <= 1'd0;
                        end
                    end
                    2'd2: begin
                        if ((range_rom || range_ram) && (bus_op == `BUS_OP_WRITE)) begin
                        // if ((bus_op == `BUS_OP_WRITE)) begin
                            d_out    <= cpu_dout;
                            d_oe     <= 1'd1;
                            cart_nWR <= 1'd0;
                        end
                    end
                    2'd3: begin
                        if ((range_rom || range_ram) && (bus_op == `BUS_OP_WRITE)) begin
                        // if ( (bus_op == `BUS_OP_WRITE)) begin
                            d_out    <= cpu_dout;
                            d_oe     <= 1'd1;
                            cart_nWR <= 1'd0;
                        end
                    end
                endcase
                
            end
            
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign cart_nCS  = (range_ram) ? 1'b0 : 1'b1;
    assign cart_a    = cpu_a;
    assign cart_d_oe = (d_oe & cart_nRD);
    assign cart_d    = (cart_d_oe) ? d_out : 8'hzz;
    
    
endmodule
