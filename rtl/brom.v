`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    21:10:17 02/09/2018
// Design Name:
// Module Name:    brom
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module brom(
    input clk,
    input rst,
    input [15:0] cpu_a,
    output [7:0] cpu_din,
    input cpu_wr,
    output brom_overwrite
);
    
    // 256 Bytes BROM array
    reg [7:0] brom_array [0:255];
    initial begin
        $readmemh("bootrom.mif", brom_array, 0, 255);
    end
    
    reg brom_disable = 1'b0;
    
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            brom_disable <= 1'd0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff50)) begin
                brom_disable <= 1'd1;
            end
        end
    end
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign brom_overwrite = ((!brom_disable) && (cpu_a <= 16'h00ff));
    assign cpu_din        = brom_array[cpu_a[7:0]];
    
    
    
endmodule
