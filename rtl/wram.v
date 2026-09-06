`timescale 1ns / 1ps

module wram(
    input clk,
    input rst,
    input dmg_mode,
    input [15:0]cpu_a,
    input [7:0] cpu_dout,
    output [7:0] cpu_din,
    input cpu_rd,
    input cpu_wr,
    output [7:0] reg_svbk
);
    
    
    
    // ## $FF70    SVBK/WBK    WRAM bank    R/W    CGB
    //
    // |      | 7 6 5 4 3 | 2 1 0     |
    // | ---- | --------- | --------- |
    // | SVBK |           | WRAM bank |
    //
    // - WRAM C000~DFFF 8KB
    // - CGB有32KB，C000-Cfff 4KB 固定为bank0，d000-dfff 4KB 为bank1-7
    // - 写0视为1
    
    reg [2:0] wramBank;
    always @(posedge rst or posedge clk) begin
        if (rst || dmg_mode) begin
            wramBank <= 3'b0;
        end
        else begin
            if ((cpu_wr) && (cpu_a == 16'hff70)) begin
                wramBank <= cpu_dout[2:0];
            end
        end
    end
    
    
    
    // 1100    C000~CFFF    (WRAM) 4 KiB Work RAM Bank 0
    // 1101    D000~DFFF    (WRAM) 4 KiB Work RAM Bank 1~7
    // 1110    E000~EFFF    Echo RAM (mirror of C000–CFFF)
    // 1111    F000~FDFF    Echo RAM (mirror of D000–DDFF)
    
    wire range_wram  = ((16'hc000 <= cpu_a) && (cpu_a <= 16'hfdff));
    wire range_bank0 = ~(cpu_a[12]);
    
    reg [14:0] wram_a;
    
    always @(*) begin
        if (dmg_mode) begin
            wram_a = {2'b0,cpu_a[12:0]};
        end
        else begin
            if (range_bank0) begin
                wram_a = {3'b0,cpu_a[11:0]};
            end
            else begin
                if (wramBank == 3'd0)
                    wram_a = {3'b1,    cpu_a[11:0]};
                else
                    wram_a = {wramBank,cpu_a[11:0]};
            end
        end
    end
    
    singleport_ram #(
        .WORDS(32768),
        .ABITS(15)
    ) br_wram (
        .clka  (clk),
        .wea   (cpu_wr & range_wram),
        .addra (wram_a),
        .dina  (cpu_dout),
        .douta (cpu_din)
    );
    
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    assign reg_svbk = dmg_mode ? 8'hff : {5'b11111, wramBank};
    
    
    
endmodule
