`timescale 1ns / 1ps

module hram(
    input clk,
    input rst,
    input [15:0] cpu_a,
    input [7:0] cpu_dout,
    output [7:0] cpu_din,
    input cpu_rd,
    input cpu_wr
);
    
    // FF80~FFFE    High RAM (HRAM)    CPU专用，不受外设阻塞，SP栈顶指向这末尾 126B
    wire range_hram = ((16'hff80 <= cpu_a) && (cpu_a <= 16'hfffe));
    
    wire [6:0] hram_a = cpu_a[6:0];
    
    singleport_ram #(
        .WORDS(128),
        .ABITS(7)
    ) br_wram (
        .clka  (clk),
        .wea   (cpu_wr & range_hram),
        .addra (hram_a),
        .dina  (cpu_dout),
        .douta (cpu_din)
    );
    
    
endmodule
